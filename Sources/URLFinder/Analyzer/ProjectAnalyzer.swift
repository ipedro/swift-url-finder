import Foundation
import IndexStore
import SwiftSyntax
import SwiftParser

actor IndexStoreAnalyzer {
    let projectPath: URL
    let indexStorePath: URL?  // Optional override
    let verbose: Bool
    
    private var indexStore: IndexStore!
    private var urlDeclarations: [String: URLDeclaration] = [:]
    private var allReferences: [EndpointReference] = []
    private var symbolToURL: [String: String] = [:]  // Maps symbol USR to URL variable name
    private var analyzedFilePaths: Set<String> = []  // Track all files we analyze
    
    init(projectPath: URL, indexStorePath: URL? = nil, verbose: Bool = false) throws {
        self.projectPath = projectPath
        self.indexStorePath = indexStorePath
        self.verbose = verbose
    }
    
    /// Main analysis entry point
    func analyzeProject() async throws {
        if verbose {
            print("� Analyzing project at: \(projectPath.path)")
        }
        
        // Initialize IndexStore with configuration
        // The library will automatically resolve libIndexStore path and index store location
        let configuration: IndexStore.Configuration
        
        if let customIndexStore = indexStorePath {
            // User provided custom index store path
            if verbose {
                print("📇 Using custom index store: \(customIndexStore.path)")
            }
            configuration = try IndexStore.Configuration(
                projectDirectory: projectPath.path,
                indexStorePath: customIndexStore.path,
                indexDatabasePath: NSTemporaryDirectory() + "/endpoint-finder-index.db"
            )
        } else {
            // Let IndexStore auto-discover the index store from project directory
            if verbose {
                print("📇 Auto-discovering index store...")
            }
            configuration = try IndexStore.Configuration(
                projectDirectory: projectPath.path
            )
        }
        
        indexStore = IndexStore(configuration: configuration)
        
        if verbose {
            print("✅ Index store loaded")
        }
        
        // Step 1: Find all URL-related symbols in the project
        try await findURLSymbols()
        
        // Step 2: For each URL symbol, trace its construction and usage
        try await traceURLConstructions()
        
        if verbose {
            print("✅ Analysis complete: \(urlDeclarations.count) URL declarations found")
        }
    }
    
    /// Find all symbols that are URLs or URL-related
    /// Uses IndexStore's clean API to query for URL-related symbols
    private func findURLSymbols() async throws {
        if verbose {
            print("🔍 Searching for URL symbols in index...")
        }
        
        var foundSymbols = Set<String>()  // Track unique symbol USRs
        
        // Search for symbols containing "url" or "endpoint" in their name
        // Using IndexStore's clean query API
        let searchPatterns = ["url", "endpoint"]
        let propertyKinds: [SourceKind] = [.instanceProperty, .classProperty, .staticProperty, .variable]
        
        for pattern in searchPatterns {
            let query = IndexStoreQuery(query: pattern)
                .withKinds(propertyKinds)
                .withAnchorStart(false)
                .withAnchorEnd(false)
                .withIncludeSubsequences(true)
                .withIgnoringCase(true)
                .withRoles([.definition])
            
            let symbols = indexStore.querySymbols(query)
            
            for symbol in symbols {
                let symbolName = symbol.name
                
                // Only process Swift files
                guard symbol.location.path.hasSuffix(".swift"),
                      !self.shouldSkipFile(symbol.location.path) else {
                    continue
                }
                
                // Skip mock artifacts (generated test doubles)
                guard !self.isMockArtifact(symbolName) else {
                    continue
                }
                
                // Skip if we've already processed this symbol
                guard !foundSymbols.contains(symbol.usr) else {
                    continue
                }
                foundSymbols.insert(symbol.usr)
                
                if self.verbose {
                    print("  Found URL symbol: \(symbolName) in \(symbol.location.path)")
                }
                
                // Create a URL declaration entry
                let declaration = URLDeclaration(
                    name: symbolName,
                    file: symbol.location.path,
                    line: symbol.location.line,
                    column: symbol.location.column,
                    baseURL: nil
                )
                
                self.urlDeclarations[symbolName] = declaration
                self.symbolToURL[symbol.usr] = symbolName
                self.analyzedFilePaths.insert(symbol.location.path)
            }
        }
        
        if verbose {
            print("  Found \(urlDeclarations.count) URL symbols")
        }
    }
    
    /// Check if a file should be skipped (build artifacts, dependencies, generated mocks, etc.)
    private func shouldSkipFile(_ path: String) -> Bool {
        return path.contains("/.build/") ||
               path.contains("/DerivedData/") ||
               path.contains("/Pods/") ||
               path.contains("/Carthage/") ||
               path.contains("/Packages/checkouts/") ||
               path.contains(".generated.swift") ||  // Skip generated mock files
               path.contains("Mock.swift") ||         // Skip manual mocks
               path.hasSuffix("Mock.generated.swift") // Skip Sourcery mocks
    }
    
    /// Check if a symbol name is likely a mock artifact (not a real URL)
    private func isMockArtifact(_ symbolName: String) -> Bool {
        // Common patterns in generated mocks that are not real URLs
        let mockPatterns = [
            "CallsCount",
            "Called",
            "Closure",
            "ReturnValue",
            "ReceivedArguments",
            "ReceivedInvocations",
            "ReceivedArgument",
            "Invocations"
        ]
        
        return mockPatterns.contains(where: { symbolName.contains($0) })
    }
    

    
    /// Trace how URLs are constructed by following references
    private func traceURLConstructions() async throws {
        if verbose {
            print("🔗 Tracing URL constructions...")
        }
        
        for (symbolName, declaration) in urlDeclarations {
            // Parse the source file to extract URL construction details
            try await analyzeURLConstruction(
                symbolName: symbolName,
                declaration: declaration
            )
        }
    }
    
    /// Analyze how a specific URL is constructed
    private func analyzeURLConstruction(
        symbolName: String,
        declaration: URLDeclaration
    ) async throws {
        let fileURL = URL(fileURLWithPath: declaration.file)
        
        guard let sourceCode = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        
        // Use SwiftSyntax to parse the URL construction with two-pass analysis
        let visitor = URLConstructionVisitor(
            targetSymbol: symbolName,
            filePath: declaration.file
        )
        visitor.walkTwoPass(sourceFile)
        
        // Collect all path components (local + resolved cross-object)
        var allPathComponents = visitor.pathComponents
        
        // If there are unresolved cross-object references, resolve them
        if !visitor.unresolvedReferences.isEmpty {
            let resolver = CrossObjectResolver(indexStore: indexStore, verbose: verbose)
            
            for unresolved in visitor.unresolvedReferences {
                if verbose {
                    print("  Resolving cross-object reference: \(unresolved.objectName).\(unresolved.propertyName)")
                }
                
                do {
                    let resolved = try resolver.resolveProperty(
                        objectName: unresolved.objectName,
                        propertyName: unresolved.propertyName,
                        fromFile: declaration.file
                    )
                    // Prepend resolved components (they come before current components)
                    allPathComponents = resolved + allPathComponents
                } catch {
                    if verbose {
                        print("  ⚠️  Failed to resolve \(unresolved.objectName).\(unresolved.propertyName): \(error)")
                    }
                }
            }
        }
        
        // Update the declaration with discovered information
        if var updatedDeclaration = urlDeclarations[symbolName] {
            updatedDeclaration.pathComponents = allPathComponents
            updatedDeclaration.httpMethod = visitor.httpMethod
            updatedDeclaration.isURLRequest = visitor.isURLRequest
            urlDeclarations[symbolName] = updatedDeclaration
            
            // Create an endpoint reference
            let reference = EndpointReference(
                file: declaration.file,
                line: declaration.line,
                column: declaration.column,
                symbolName: symbolName,
                baseURL: visitor.baseURL,
                pathComponents: visitor.pathComponents.map { $0.value },
                fullPath: visitor.pathComponents.map { $0.value }.joined(separator: "/"),
                httpMethod: visitor.httpMethod,
                isURLRequest: visitor.isURLRequest
            )
            
            allReferences.append(reference)
        }
    }
    
    /// Find all references to a specific endpoint
    func findEndpointReferences(endpoint: String) -> [EndpointReference] {
        let normalizedEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        return allReferences.filter { reference in
            let normalizedPath = reference.fullPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return normalizedPath.contains(normalizedEndpoint)
        }.sorted { $0.file < $1.file || ($0.file == $1.file && $0.line < $1.line) }
    }
    
    /// Generate a comprehensive report
    func generateReport() -> EndpointReport {
        let groupedEndpoints = Dictionary(grouping: allReferences) { $0.fullPath }
        
        let endpointInfos = groupedEndpoints.map { path, references in
            let first = references[0]
            return EndpointInfo(
                fullPath: path,
                baseURL: first.baseURL,
                pathComponents: first.pathComponents,
                references: references,
                declarationFile: first.file,
                declarationLine: first.line
            )
        }.sorted { $0.fullPath < $1.fullPath }
        
        // Infer project root from analyzed files
        let projectRoot = inferProjectRoot(from: Array(analyzedFilePaths))
        
        return EndpointReport(
            projectPath: projectRoot,
            analyzedFiles: urlDeclarations.count,
            totalEndpoints: endpointInfos.count,
            endpoints: endpointInfos,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    /// Infer the project root directory from a collection of file paths
    private func inferProjectRoot(from paths: [String]) -> String {
        guard !paths.isEmpty else {
            return "Unknown"
        }
        
        // Find the common prefix of all paths
        let sortedPaths = paths.sorted()
        guard let first = sortedPaths.first,
              let last = sortedPaths.last else {
            return "Unknown"
        }
        
        let firstComponents = first.split(separator: "/")
        let lastComponents = last.split(separator: "/")
        
        var commonComponents: [String] = []
        for (f, l) in zip(firstComponents, lastComponents) {
            if f == l {
                commonComponents.append(String(f))
            } else {
                break
            }
        }
        
        // Go up to find a reasonable project root (look for common indicators)
        let commonPath = "/" + commonComponents.joined(separator: "/")
        
        // Try to find a reasonable stopping point (Sources/, Tests/, etc.)
        if let sourcesIndex = commonComponents.lastIndex(where: { $0 == "Sources" || $0 == "Tests" || $0 == "src" }) {
            let projectComponents = Array(commonComponents[..<sourcesIndex])
            return "/" + projectComponents.joined(separator: "/")
        }
        
        return commonPath
    }
}
