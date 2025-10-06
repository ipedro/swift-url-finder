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
    /// Directly queries the index for URL-type symbols instead of iterating files
    private func findURLSymbols() async throws {
        if verbose {
            print("🔍 Searching for URL symbols in index...")
        }
        
        var foundSymbols = Set<String>()  // Track unique symbol USRs
        
        // Strategy: Iterate through all canonical symbol occurrences
        // and filter for URL-related properties/variables
        // This is more efficient than getting all files first
        indexStoreDB.forEachCanonicalSymbolOccurrence(byName: "") { occurrence in
            let symbol = occurrence.symbol
            let symbolName = symbol.name
            
            // Only process Swift files
            guard occurrence.location.path.hasSuffix(".swift"),
                  !self.shouldSkipFile(occurrence.location.path) else {
                return true
            }
            
            // Check if this is a URL-related symbol
            guard self.isURLSymbol(name: symbolName, kind: symbol.kind) else {
                return true
            }
            
            // Skip if we've already processed this symbol
            guard !foundSymbols.contains(symbol.usr) else {
                return true
            }
            foundSymbols.insert(symbol.usr)
            
            // Only interested in definitions
            guard occurrence.roles.contains(.definition) else {
                return true
            }
            
            if self.verbose {
                print("  Found URL symbol: \(symbolName) in \(occurrence.location.path)")
            }
            
            // Create a URL declaration entry
            let declaration = URLDeclaration(
                name: symbolName,
                file: occurrence.location.path,
                line: occurrence.location.line,
                column: occurrence.location.utf8Column,
                baseURL: nil
            )
            
            self.urlDeclarations[symbolName] = declaration
            self.symbolToURL[symbol.usr] = symbolName
            self.analyzedFilePaths.insert(occurrence.location.path)
            
            return true  // Continue iteration
        }
        
        if verbose {
            print("  Found \(urlDeclarations.count) URL symbols")
        }
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
