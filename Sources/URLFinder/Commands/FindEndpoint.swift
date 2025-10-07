import ArgumentParser
import Foundation

struct FindEndpoint: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "find",
        abstract: "Find all references to a specific endpoint URL in the project"
    )
    
    @Option(name: .shortAndLong, help: "Path to the Xcode project or workspace directory")
    var project: String?
    
    @Option(name: .shortAndLong, help: "Path to the index store (optional override, auto-discovered if not provided)")
    var indexStore: String?
    
    @Option(name: .shortAndLong, help: "The endpoint path to search for (e.g., 'resources/enable')")
    var endpoint: String
    
    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false
    
    func run() async throws {
        print("🔍 Searching for endpoint: \(endpoint)")
        
        // Resolve project path and index store
        let resolvedProject: String
        let resolvedIndexStore: URL?
        
        if let providedProject = project {
            resolvedProject = providedProject
            resolvedIndexStore = indexStore.map { URL(fileURLWithPath: $0) }
            print("� Project: \(resolvedProject)")
        } else {
            // Interactive: discover and prompt for project
            let discovery = IndexStoreDiscovery()
            let stores = try discovery.discoverIndexStores()
            
            if stores.isEmpty {
                print("\n❌ No index stores found in DerivedData.")
                print("   Build your project in Xcode first to generate the index.")
                throw ExitCode.failure
            }
            
            let selectedStore = try IndexStoreDiscovery.promptForIndexStore(stores: stores)
            print("\n✅ Selected: \(selectedStore.projectName)")
            
            // Prompt for project path
            print("\n📁 Enter the path to the \(selectedStore.projectName) project:")
            print("   > ", terminator: "")
            
            guard let projectPath = readLine()?.trimmingCharacters(in: .whitespaces), !projectPath.isEmpty else {
                print("\n❌ Project path is required")
                throw ExitCode.failure
            }
            
            let expandedPath = NSString(string: projectPath).expandingTildeInPath
            resolvedProject = expandedPath
            resolvedIndexStore = selectedStore.indexStorePath
            print("📁 Project: \(resolvedProject)")
        }
        
        print()
        
        let projectURL = URL(fileURLWithPath: resolvedProject)
        let indexStoreURL = resolvedIndexStore
        
        let analyzer = try IndexStoreAnalyzer(
            projectPath: projectURL,
            indexStorePath: indexStoreURL,
            verbose: verbose
        )
        
        try await analyzer.analyzeProject()
        
        let references = await analyzer.findEndpointReferences(endpoint: endpoint)
        
        if references.isEmpty {
            print("❌ No references found for endpoint: \(endpoint)")
            return
        }
        
        print("✅ Found \(references.count) reference(s):")
        print()
        
        for reference in references {
            print("\(reference.file):\(reference.line)")
            if verbose {
                print("  Base URL: \(reference.baseURL ?? "N/A")")
                print("  Full Path: \(reference.fullPath)")
                print("  Symbol: \(reference.symbolName)")
                print("  Transformations: \(reference.pathComponents.count)")
                print()
            }
        }
    }
}
