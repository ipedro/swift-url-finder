import Foundation
import IndexStoreDB
import SwiftSyntax
import SwiftParser

actor IndexStoreAnalyzer {
    let projectPath: URL
    let indexStorePath: URL
    let verbose: Bool
    
    private var indexStoreDB: IndexStoreDB!
    private var urlDeclarations: [String: URLDeclaration] = [:]
    private var allReferences: [EndpointReference] = []
    private var symbolToURL: [String: String] = [:]  // Maps symbol USR to URL variable name
    
    init(projectPath: URL, indexStorePath: URL, verbose: Bool = false) throws {
        self.projectPath = projectPath
        self.indexStorePath = indexStorePath
        self.verbose = verbose
    }
    
    /// Main analysis entry point
    func analyzeProject() async throws {
        if verbose {
            print("🔎 Analyzing project at: \(projectPath.path)")
            print("📇 Loading index store from: \(indexStorePath.path)")
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
        
        // Query for property declarations that contain "URL" or "url" in the name
        // We'll look for properties and variables
        // Note: We need to iterate through source files in the project
        let swiftFiles = try findSwiftFiles(in: projectPath)
        var symbols: [Symbol] = []
        
        for filePath in swiftFiles {
            let fileSymbols = indexStoreDB.symbols(inFilePath: filePath.path)
            symbols.append(contentsOf: fileSymbols)
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
                }
            }
        }
        
        if verbose {
            print("  Found \(urlDeclarations.count) URL symbols")
        }
    }
    
    /// Find all Swift files in the project
    private func findSwiftFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var swiftFiles: [URL] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw NSError(domain: "IndexStoreAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot enumerate directory"])
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                // Skip build artifacts and dependencies
                let path = fileURL.path
                if !path.contains("/.build/") &&
                   !path.contains("/DerivedData/") &&
                   !path.contains("/Pods/") &&
                   !path.contains("/Carthage/") {
                    swiftFiles.append(fileURL)
                }
            }
        }
        
        return swiftFiles
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
            urlDeclarations[symbolName] = updatedDeclaration
            
            // Create an endpoint reference
            let reference = EndpointReference(
                file: declaration.file,
                line: declaration.line,
                column: declaration.column,
                symbolName: symbolName,
                baseURL: visitor.baseURL,
                pathComponents: visitor.pathComponents.map { $0.value },
                fullPath: visitor.pathComponents.map { $0.value }.joined(separator: "/")
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
        
        return EndpointReport(
            projectPath: projectPath.path,
            analyzedFiles: urlDeclarations.count,
            totalEndpoints: endpointInfos.count,
            endpoints: endpointInfos,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
}
