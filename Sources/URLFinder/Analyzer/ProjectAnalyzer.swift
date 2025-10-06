import Foundation
import IndexStoreDB
import SwiftSyntax
import SwiftParser

actor IndexStoreAnalyzer {
    let indexStorePath: URL
    let verbose: Bool
    
    private var indexStoreDB: IndexStoreDB!
    private var urlDeclarations: [String: URLDeclaration] = [:]
    private var allReferences: [EndpointReference] = []
    private var symbolToURL: [String: String] = [:]  // Maps symbol USR to URL variable name
    private var analyzedFilePaths: Set<String> = []  // Track all files we analyze
    
    init(indexStorePath: URL, verbose: Bool = false) throws {
        self.indexStorePath = indexStorePath
        self.verbose = verbose
    }
    
    /// Main analysis entry point
    func analyzeProject() async throws {
        if verbose {
            print(" Loading index store from: \(indexStorePath.path)")
        }
        
        // Initialize IndexStoreDB
        let libPath = indexStorePath.appendingPathComponent("../..").standardized
        
        indexStoreDB = try IndexStoreDB(
            storePath: indexStorePath.path,
            databasePath: NSTemporaryDirectory() + "/endpoint-finder-index.db",
            library: IndexStoreLibrary(dylibPath: libPath.path)
        )
        
        // Poll for initialization
        try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for indexstore to load
        
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
    private func findURLSymbols() async throws {
        if verbose {
            print("🔍 Searching for URL symbols...")
        }
        
        // Get all Swift files from the index store
        let swiftFiles = getSwiftFilesFromIndex()
        var symbols: [Symbol] = []
        
        for filePath in swiftFiles {
            analyzedFilePaths.insert(filePath)
            let fileSymbols = indexStoreDB.symbols(inFilePath: filePath)
            symbols.append(contentsOf: fileSymbols)
        }
        
        if verbose {
            print("  Scanning \(swiftFiles.count) Swift files from index...")
        }
        
        for symbol in symbols {
            let symbolName = symbol.name
            
            // Check if this looks like a URL property
            if isURLSymbol(name: symbolName, kind: symbol.kind) {
                if verbose {
                    print("  Found URL symbol: \(symbolName)")
                }
                
                // Get the definition location using occurrences
                let occurrences = indexStoreDB.occurrences(ofUSR: symbol.usr, roles: .definition)
                
                if let defnOccurrence = occurrences.first {
                    // Create a URL declaration entry
                    let declaration = URLDeclaration(
                        name: symbolName,
                        file: defnOccurrence.location.path,
                        line: defnOccurrence.location.line,
                        column: defnOccurrence.location.utf8Column,
                        baseURL: nil
                    )
                    
                    urlDeclarations[symbolName] = declaration
                    symbolToURL[symbol.usr] = symbolName
                    analyzedFilePaths.insert(defnOccurrence.location.path)
                }
            }
        }
        
        if verbose {
            print("  Found \(urlDeclarations.count) URL symbols")
        }
    }
    
    /// Get all Swift files from the index store
    /// IndexStoreDB doesn't provide a direct file listing, but we can query symbols
    /// from known locations or use the index store's internal structure
    private func getSwiftFilesFromIndex() -> [String] {
        var foundFiles = Set<String>()
        
        // Strategy: Query for all symbols by iterating through canonical symbol names
        // This is a workaround since IndexStoreDB doesn't expose a file listing API
        // We'll query common symbol types that appear in most Swift files
        
        // Use forEachCanonicalSymbolOccurrence with wildcard matching
        indexStoreDB.forEachCanonicalSymbolOccurrence(byName: "") { occurrence in
            let path = occurrence.location.path
            if path.hasSuffix(".swift") && !shouldSkipFile(path) {
                foundFiles.insert(path)
            }
            return true  // Continue iteration
        }
        
        // If no files found via the above, fall back to inferring from index store path
        if foundFiles.isEmpty {
            // The index store path structure is: <path>/.build/<config>/<target>/index/store
            // We can go up to the project root and scan
            let projectRoot = inferProjectRootFromIndexStore()
            if let root = projectRoot {
                foundFiles = Set(scanSwiftFiles(in: root))
            }
        }
        
        return Array(foundFiles).sorted()
    }
    
    /// Infer project root from index store path
    private func inferProjectRootFromIndexStore() -> URL? {
        // Index store is typically at: <project>/.build/<config>/<target>/index/store
        let components = indexStorePath.pathComponents
        
        // Find .build in the path and go up one level
        if let buildIndex = components.lastIndex(of: ".build") {
            let projectComponents = Array(components[..<buildIndex])
            if !projectComponents.isEmpty {
                let path = projectComponents.joined(separator: "/")
                return URL(fileURLWithPath: path.hasPrefix("/") ? path : "/\(path)")
            }
        }
        
        return nil
    }
    
    /// Scan filesystem for Swift files (fallback method)
    private func scanSwiftFiles(in directory: URL) -> [String] {
        let fileManager = FileManager.default
        var swiftFiles: [String] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                let path = fileURL.path
                if !shouldSkipFile(path) {
                    swiftFiles.append(path)
                }
            }
        }
        
        return swiftFiles
    }
    
    /// Check if a file should be skipped (build artifacts, dependencies, etc.)
    private func shouldSkipFile(_ path: String) -> Bool {
        return path.contains("/.build/") ||
               path.contains("/DerivedData/") ||
               path.contains("/Pods/") ||
               path.contains("/Carthage/") ||
               path.contains("/Packages/checkouts/")
    }
    
    /// Check if a symbol is URL-related
    private func isURLSymbol(name: String, kind: IndexSymbolKind) -> Bool {
        // Check for properties and variables (using the actual enum cases from IndexStoreDB)
        guard kind == .instanceProperty || kind == .classProperty || kind == .staticProperty || kind == .variable else {
            return false
        }
        
        let lowerName = name.lowercased()
        return lowerName.contains("url") || 
               lowerName.contains("endpoint") ||
               lowerName.hasSuffix("url")
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
        
        // Use SwiftSyntax to parse the URL construction
        let visitor = URLConstructionVisitor(
            targetSymbol: symbolName,
            filePath: declaration.file
        )
        visitor.walk(sourceFile)
        
        // Update the declaration with discovered information
        if var updatedDeclaration = urlDeclarations[symbolName] {
            updatedDeclaration.pathComponents = visitor.pathComponents
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
