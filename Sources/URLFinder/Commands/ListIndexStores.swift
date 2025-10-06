import ArgumentParser
import Foundation

struct ListIndexStores: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all available index stores in Xcode's DerivedData"
    )
    
    @Flag(name: .long, help: "Show detailed information")
    var verbose: Bool = false
    
    func run() throws {
        let discovery = IndexStoreDiscovery()
        
        print("🔍 Scanning for index stores in DerivedData...\n")
        
        let stores = try discovery.discoverIndexStores()
        
        if stores.isEmpty {
            print("❌ No index stores found.")
            print("\nTo generate an index store:")
            print("  1. Open your project in Xcode")
            print("  2. Build the project (⌘B)")
            print("  3. Wait for indexing to complete")
            print("  4. Run this command again\n")
            return
        }
        
        print("📇 Found \(stores.count) index store(s):\n")
        
        for (index, store) in stores.enumerated() {
            print("[\(index + 1)] \(store.projectName)")
            
            if let lastModified = store.lastModified {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                print("    Last built: \(formatter.string(from: lastModified))")
                
                let relativeFormatter = RelativeDateTimeFormatter()
                relativeFormatter.unitsStyle = .full
                let relativeTime = relativeFormatter.localizedString(for: lastModified, relativeTo: Date())
                print("    (\(relativeTime))")
            }
            
            print("    Index files: \(store.indexFileCount)")
            
            if verbose {
                print("    Index store: \(store.indexStorePath.path)")
                print("    DerivedData: \(store.derivedDataPath.path)")
            }
            
            print()
        }
        
        if !verbose {
            print("💡 Tip: Use --verbose to see full paths")
        }
    }
}
