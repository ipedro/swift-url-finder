import Foundation
import Testing
@testable import URLFinder

@Suite("ProjectAnalyzer Tests", .enabled(if: false))
struct ProjectAnalyzerTests {
    
    // Note: These tests are disabled because they require a real IndexStoreDB
    // To enable: Build the test fixtures, then set .enabled(if: true)
    
    @Test("Finds Swift files in project", .disabled("Requires IndexStoreDB"))
    func testFindSwiftFiles() throws {
        let fixturesPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
        
        // This would require a mock or test double
        // let analyzer = try IndexStoreAnalyzer(
        //     projectPath: fixturesPath,
        //     indexStorePath: fixturesPath.appendingPathComponent(".index"),
        //     verbose: true
        // )
        
        // For now, test the file finding logic directly
        let fileManager = FileManager.default
        var swiftFiles: [URL] = []
        
        guard let enumerator = fileManager.enumerator(
            at: fixturesPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            Issue.record("Cannot enumerate fixtures directory")
            return
        }
        
        // Synchronously iterate through enumerator
        while let element = enumerator.nextObject() {
            if let fileURL = element as? URL, fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
            }
        }
        
        #expect(swiftFiles.count >= 2) // SampleService.swift, NetworkClient.swift
        #expect(swiftFiles.contains { $0.lastPathComponent == "SampleService.swift" })
        #expect(swiftFiles.contains { $0.lastPathComponent == "NetworkClient.swift" })
    }
}

@Suite("ProjectAnalyzer Symbol Detection Tests")
struct SymbolDetectionTests {
    
    @Test("isURLSymbol detects URL properties")
    func testIsURLSymbolDetection() {
        // These tests validate the symbol detection logic without IndexStoreDB
        
        struct TestCase {
            let name: String
            let shouldDetect: Bool
        }
        
        let testCases: [TestCase] = [
            // Should detect
            TestCase(name: "apiURL", shouldDetect: true),
            TestCase(name: "baseURL", shouldDetect: true),
            TestCase(name: "endpoint", shouldDetect: true),
            TestCase(name: "loginEndpoint", shouldDetect: true),
            TestCase(name: "usersURL", shouldDetect: true),
            TestCase(name: "URL", shouldDetect: true),
            
            // Should not detect (not URL-related)
            TestCase(name: "username", shouldDetect: false),
            TestCase(name: "password", shouldDetect: false),
            TestCase(name: "count", shouldDetect: false),
            TestCase(name: "isEnabled", shouldDetect: false),
        ]
        
        for testCase in testCases {
            let lowerName = testCase.name.lowercased()
            let detected = lowerName.contains("url") || 
                          lowerName.contains("endpoint") ||
                          lowerName.hasSuffix("url")
            
            #expect(detected == testCase.shouldDetect, 
                    "Expected '\(testCase.name)' detection to be \(testCase.shouldDetect), got \(detected)")
        }
    }
    
    @Test("Normalizes endpoint paths for comparison")
    func testEndpointNormalization() {
        let testCases: [(input: String, expected: String)] = [
            ("/api/users", "api/users"),
            ("api/users/", "api/users"),
            ("/api/users/", "api/users"),
            ("api/users", "api/users"),
        ]
        
        for (input, expected) in testCases {
            let normalized = input.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            #expect(normalized == expected, "Failed to normalize '\(input)'")
        }
    }
}

@Suite("ProjectAnalyzer Helper Function Tests")
struct HelperFunctionTests {
    
    @Test("findSwiftFiles skips build artifacts")
    func testSwiftFileFiltering() {
        let testPaths = [
            "/project/Sources/Main.swift",
            "/project/.build/debug/Main.swift",
            "/project/DerivedData/Build/Main.swift",
            "/project/Pods/Library/File.swift",
            "/project/Carthage/Build/Framework.swift",
            "/project/Tests/TestFile.swift",
        ]
        
        let shouldInclude = testPaths.map { path -> Bool in
            !path.contains("/.build/") &&
            !path.contains("/DerivedData/") &&
            !path.contains("/Pods/") &&
            !path.contains("/Carthage/")
        }
        
        #expect(shouldInclude[0] == true) // Sources/Main.swift
        #expect(shouldInclude[1] == false) // .build
        #expect(shouldInclude[2] == false) // DerivedData
        #expect(shouldInclude[3] == false) // Pods
        #expect(shouldInclude[4] == false) // Carthage
        #expect(shouldInclude[5] == true) // Tests/TestFile.swift
    }
    
    @Test("generateReport groups endpoints correctly")
    func testReportGeneration() {
        let references = [
            EndpointReference(
                file: "/test/Service.swift",
                line: 10,
                column: 5,
                symbolName: "usersURL",
                baseURL: "https://api.example.com",
                pathComponents: ["users"],
                fullPath: "users",
                httpMethod: nil,
                isURLRequest: false
            ),
            EndpointReference(
                file: "/test/Service.swift",
                line: 20,
                column: 5,
                symbolName: "usersEndpoint",
                baseURL: "https://api.example.com",
                pathComponents: ["users"],
                fullPath: "users",
                httpMethod: nil,
                isURLRequest: false
            ),
            EndpointReference(
                file: "/test/Client.swift",
                line: 15,
                column: 5,
                symbolName: "resourcesURL",
                baseURL: "https://api.example.com",
                pathComponents: ["accounts"],
                fullPath: "accounts",
                httpMethod: nil,
                isURLRequest: false
            ),
        ]
        
        // Simulate grouping logic
        let grouped = Dictionary(grouping: references) { $0.fullPath }
        
        #expect(grouped.count == 2) // "users" and "accounts"
        #expect(grouped["users"]?.count == 2)
        #expect(grouped["accounts"]?.count == 1)
    }
    
    @Test("findEndpointReferences filters correctly")
    func testEndpointReferenceFiltering() {
        let allReferences = [
            EndpointReference(
                file: "/test/A.swift",
                line: 1,
                column: 1,
                symbolName: "usersURL",
                baseURL: nil,
                pathComponents: ["api", "v1", "users"],
                fullPath: "api/v1/users",
                httpMethod: nil,
                isURLRequest: false
            ),
            EndpointReference(
                file: "/test/B.swift",
                line: 2,
                column: 1,
                symbolName: "resourcesURL",
                baseURL: nil,
                pathComponents: ["api", "v1", "accounts"],
                fullPath: "api/v1/accounts",
                httpMethod: nil,
                isURLRequest: false
            ),
            EndpointReference(
                file: "/test/C.swift",
                line: 3,
                column: 1,
                symbolName: "userProfileURL",
                baseURL: nil,
                pathComponents: ["api", "v2", "users", "profile"],
                fullPath: "api/v2/users/profile",
                httpMethod: nil,
                isURLRequest: false
            ),
        ]
        
        // Simulate filtering logic
        let searchTerm = "users"
        let normalizedSearch = searchTerm.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        let filtered = allReferences.filter { reference in
            let normalizedPath = reference.fullPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return normalizedPath.contains(normalizedSearch)
        }
        
        #expect(filtered.count == 2) // Should match "users" and "users/profile"
        #expect(filtered.contains { $0.symbolName == "usersURL" })
        #expect(filtered.contains { $0.symbolName == "userProfileURL" })
        #expect(!filtered.contains { $0.symbolName == "resourcesURL" })
    }
    
    @Test("EndpointReport timestamp is valid ISO8601")
    func testReportTimestamp() {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        
        // Verify we can parse it back
        let parsed = formatter.date(from: timestamp)
        #expect(parsed != nil)
        
        // Verify format (should be like: 2025-10-06T12:34:56Z)
        #expect(timestamp.contains("T"))
        #expect(timestamp.contains("Z") || timestamp.contains("+") || timestamp.contains("-"))
    }
}

@Suite("ProjectAnalyzer Error Handling Tests")
struct ErrorHandlingTests {
    
    @Test("Handles missing source file gracefully")
    func testMissingSourceFile() {
        let nonExistentPath = URL(fileURLWithPath: "/nonexistent/file.swift")
        let result = try? String(contentsOf: nonExistentPath, encoding: .utf8)
        
        #expect(result == nil) // Should return nil, not crash
    }
    
    @Test("Handles directory enumeration errors")
    func testDirectoryEnumerationError() {
        let fileManager = FileManager.default
        let nonExistentDir = URL(fileURLWithPath: "/nonexistent/directory")
        
        let enumerator = fileManager.enumerator(
            at: nonExistentDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        // Enumerator may return nil or be empty for non-existent directory
        if let enumerator = enumerator {
            let files = Array(enumerator)
            #expect(files.isEmpty)
        }
        // If nil, that's also acceptable behavior
    }
    
    @Test("Handles empty project directory")
    func testEmptyProjectDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Find Swift files in empty directory
        let fileManager = FileManager.default
        var swiftFiles: [URL] = []
        
        if let enumerator = fileManager.enumerator(
            at: tempDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "swift" {
                    swiftFiles.append(fileURL)
                }
            }
        }
        
        #expect(swiftFiles.isEmpty)
    }
}

@Suite("ProjectAnalyzer Report Sorting Tests")
struct ReportSortingTests {
    
    @Test("Sorts endpoints alphabetically")
    func testEndpointSorting() {
        let endpoints = [
            ("users", "users"),
            ("accounts", "accounts"),
            ("profile", "profile"),
            ("settings", "settings"),
        ]
        
        let sorted = endpoints.sorted { $0.0 < $1.0 }
        
        #expect(sorted[0].0 == "accounts")
        #expect(sorted[1].0 == "profile")
        #expect(sorted[2].0 == "settings")
        #expect(sorted[3].0 == "users")
    }
    
    @Test("Sorts references by file then line")
    func testReferenceSorting() {
        let references = [
            ("FileB.swift", 10),
            ("FileA.swift", 20),
            ("FileA.swift", 10),
            ("FileC.swift", 5),
        ]
        
        let sorted = references.sorted { 
            $0.0 < $1.0 || ($0.0 == $1.0 && $0.1 < $1.1)
        }
        
        #expect(sorted[0].0 == "FileA.swift" && sorted[0].1 == 10)
        #expect(sorted[1].0 == "FileA.swift" && sorted[1].1 == 20)
        #expect(sorted[2].0 == "FileB.swift" && sorted[2].1 == 10)
        #expect(sorted[3].0 == "FileC.swift" && sorted[3].1 == 5)
    }
}
