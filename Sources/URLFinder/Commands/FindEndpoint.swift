import ArgumentParser
import Foundation

struct FindEndpoint: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "find",
        abstract: "Find all references to a specific endpoint URL in the project"
    )
    
    @Option(name: .shortAndLong, help: "Path to the Xcode project or workspace")
    var project: String
    
    @Option(name: .shortAndLong, help: "Path to the index store (if not provided, will prompt with available options)")
    var indexStore: String?
    
    @Option(name: .shortAndLong, help: "The endpoint path to search for (e.g., 'resources/enable')")
    var endpoint: String
    
    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false
    
    func run() async throws {
        print("🔍 Searching for endpoint: \(endpoint)")
        print("📁 Project: \(project)")
        
        // Resolve index store path
        let resolvedIndexStore: String
        if let providedIndexStore = indexStore {
            resolvedIndexStore = providedIndexStore
            print("📇 Index Store: \(resolvedIndexStore)")
        } else {
            // Discover and prompt for index store
            let discovery = IndexStoreDiscovery()
            let stores = try discovery.discoverIndexStores()
            
            if stores.isEmpty {
                print("\n❌ No index stores found in DerivedData.")
                print("   Build your project in Xcode first to generate the index.")
                throw ExitCode.failure
            }
            
            let selectedStore = try IndexStoreDiscovery.promptForIndexStore(stores: stores)
            resolvedIndexStore = selectedStore.indexStorePath.path
            print("\n✅ Selected: \(selectedStore.projectName)")
        }
        
        print()
        
        let projectURL = URL(fileURLWithPath: project)
        let indexStoreURL = URL(fileURLWithPath: resolvedIndexStore)
        
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
