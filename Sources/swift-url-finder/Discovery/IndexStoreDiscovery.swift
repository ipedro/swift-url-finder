import Foundation

/// Discovers and manages IndexStore paths from Xcode's DerivedData
struct IndexStoreDiscovery {
    let derivedDataPath: URL
    
    init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        self.derivedDataPath = homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Developer")
            .appendingPathComponent("Xcode")
            .appendingPathComponent("DerivedData")
    }
    
    init(customPath: URL) {
        self.derivedDataPath = customPath
    }
    
    /// Discover all available index stores
    func discoverIndexStores() throws -> [IndexStoreInfo] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: derivedDataPath.path) else {
            throw DiscoveryError.derivedDataNotFound(derivedDataPath.path)
        }
        
        var indexStores: [IndexStoreInfo] = []
        
        let contents = try fileManager.contentsOfDirectory(
            at: derivedDataPath,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        for projectDir in contents {
            // Check if this is a project directory (format: ProjectName-uniqueid)
            let projectName = extractProjectName(from: projectDir.lastPathComponent)
            
            // Look for Index.noindex/DataStore
            let indexStorePath = projectDir
                .appendingPathComponent("Index.noindex")
                .appendingPathComponent("DataStore")
            
            if fileManager.fileExists(atPath: indexStorePath.path) {
                // Get the modification date to show when it was last built
                let attributes = try? fileManager.attributesOfItem(atPath: indexStorePath.path)
                let modificationDate = attributes?[.modificationDate] as? Date
                
                // Count index files to verify it's a real index
                let indexFileCount = countIndexFiles(at: indexStorePath)
                
                if indexFileCount > 0 {
                    let info = IndexStoreInfo(
                        projectName: projectName,
                        indexStorePath: indexStorePath,
                        derivedDataPath: projectDir,
                        lastModified: modificationDate,
                        indexFileCount: indexFileCount
                    )
                    indexStores.append(info)
                }
            }
        }
        
        // Sort by last modified date (most recent first)
        return indexStores.sorted { store1, store2 in
            guard let date1 = store1.lastModified, let date2 = store2.lastModified else {
                return store1.projectName < store2.projectName
            }
            return date1 > date2
        }
    }
    
    /// Extract project name from DerivedData folder name (removes the unique ID suffix)
    private func extractProjectName(from folderName: String) -> String {
        // Format is typically: ProjectName-uniqueid
        if let lastDash = folderName.lastIndex(of: "-") {
            return String(folderName[..<lastDash])
        }
        return folderName
    }
    
    /// Count the number of index files in the store
    private func countIndexFiles(at indexStorePath: URL) -> Int {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: indexStorePath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var count = 0
        for case let fileURL as URL in enumerator {
            if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                count += 1
            }
        }
        
        return count
    }
    
    /// Interactive prompt to select an index store
    static func promptForIndexStore(stores: [IndexStoreInfo]) throws -> IndexStoreInfo {
        guard !stores.isEmpty else {
            throw DiscoveryError.noIndexStoresFound
        }
        
        print("\n📇 Available Index Stores:\n")
        
        for (index, store) in stores.enumerated() {
            print("[\(index + 1)] \(store.projectName)")
            
            if let lastModified = store.lastModified {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let relativeTime = formatter.localizedString(for: lastModified, relativeTo: Date())
                print("    Last built: \(relativeTime)")
            }
            
            print("    Index files: \(store.indexFileCount)")
            print("    Path: \(store.indexStorePath.path)")
            print()
        }
        
        print("Select an index store (1-\(stores.count)) or 'q' to quit: ", terminator: "")
        fflush(stdout)
        
        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
            throw DiscoveryError.userCancelled
        }
        
        if input.lowercased() == "q" {
            throw DiscoveryError.userCancelled
        }
        
        guard let selection = Int(input), selection >= 1, selection <= stores.count else {
            throw DiscoveryError.invalidSelection
        }
        
        return stores[selection - 1]
    }
}

/// Information about a discovered index store
struct IndexStoreInfo {
    let projectName: String
    let indexStorePath: URL
    let derivedDataPath: URL
    let lastModified: Date?
    let indexFileCount: Int
}

/// Errors that can occur during index store discovery
enum DiscoveryError: LocalizedError {
    case derivedDataNotFound(String)
    case noIndexStoresFound
    case userCancelled
    case invalidSelection
    
    var errorDescription: String? {
        switch self {
        case .derivedDataNotFound(let path):
            return "DerivedData directory not found at: \(path)"
        case .noIndexStoresFound:
            return "No index stores found. Build your project in Xcode first."
        case .userCancelled:
            return "Operation cancelled by user"
        case .invalidSelection:
            return "Invalid selection. Please enter a number from the list."
        }
    }
}
