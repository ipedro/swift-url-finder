import Testing
import Foundation
@testable import URLFinder

// MARK: - Model Tests

@Suite("EndpointReference Tests")
struct EndpointReferenceTests {
    
    @Test("EndpointReference creates valid description")
    func testEndpointReferenceDescription() {
        let reference = EndpointReference(
            file: "/path/to/file.swift",
            line: 42,
            column: 10,
            symbolName: "testURL",
            baseURL: "baseURL",
            pathComponents: ["api", "v1", "users"],
            fullPath: "api/v1/users"
        )
        
        #expect(reference.description == "/path/to/file.swift:42:10 - testURL -> api/v1/users")
    }
    
    @Test("EndpointReference is Codable")
    func testEndpointReferenceCodable() throws {
        let reference = EndpointReference(
            file: "/test.swift",
            line: 1,
            column: 1,
            symbolName: "url",
            baseURL: "base",
            pathComponents: ["test"],
            fullPath: "test"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(reference)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EndpointReference.self, from: data)
        
        #expect(decoded.file == reference.file)
        #expect(decoded.symbolName == reference.symbolName)
        #expect(decoded.fullPath == reference.fullPath)
    }
}

@Suite("URLDeclaration Tests")
struct URLDeclarationTests {
    
    @Test("URLDeclaration computes fullPath correctly")
    func testFullPathComputation() {
        var declaration = URLDeclaration(
            name: "testURL",
            file: "/test.swift",
            line: 1,
            column: 1,
            baseURL: "base"
        )
        
        declaration.pathComponents = [
            PathComponent(value: "api", file: "/test.swift", line: 1),
            PathComponent(value: "v1", file: "/test.swift", line: 2),
            PathComponent(value: "users", file: "/test.swift", line: 3)
        ]
        
        #expect(declaration.fullPath == "api/v1/users")
    }
    
    @Test("URLDeclaration with empty path components returns empty string")
    func testEmptyPathComponents() {
        let declaration = URLDeclaration(
            name: "emptyURL",
            file: "/test.swift",
            line: 1,
            column: 1,
            baseURL: nil
        )
        
        #expect(declaration.fullPath == "")
    }
    
    @Test("URLDeclaration with single path component")
    func testSinglePathComponent() {
        var declaration = URLDeclaration(
            name: "singleURL",
            file: "/test.swift",
            line: 1,
            column: 1,
            baseURL: "base"
        )
        
        declaration.pathComponents = [
            PathComponent(value: "users", file: "/test.swift", line: 1)
        ]
        
        #expect(declaration.fullPath == "users")
    }
}

@Suite("EndpointReport Tests")
struct EndpointReportTests {
    
    @Test("EndpointReport is Codable")
    func testEndpointReportCodable() throws {
        let reference = EndpointReference(
            file: "/test.swift",
            line: 1,
            column: 1,
            symbolName: "url",
            baseURL: "base",
            pathComponents: ["test"],
            fullPath: "test"
        )
        
        let endpointInfo = EndpointInfo(
            fullPath: "test",
            baseURL: "base",
            pathComponents: ["test"],
            references: [reference],
            declarationFile: "/test.swift",
            declarationLine: 1
        )
        
        let report = EndpointReport(
            projectPath: "/project",
            analyzedFiles: 10,
            totalEndpoints: 1,
            endpoints: [endpointInfo],
            timestamp: "2024-01-01T00:00:00Z"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(report)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EndpointReport.self, from: data)
        
        #expect(decoded.projectPath == report.projectPath)
        #expect(decoded.analyzedFiles == report.analyzedFiles)
        #expect(decoded.totalEndpoints == report.totalEndpoints)
        #expect(decoded.endpoints.count == 1)
    }
}

// MARK: - IndexStoreDiscovery Tests

@Suite("IndexStoreDiscovery Tests")
struct IndexStoreDiscoveryTests {
    
    @Test("IndexStoreDiscovery initializes with default path")
    func testDefaultInitialization() {
        let discovery = IndexStoreDiscovery()
        let expectedPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Developer")
            .appendingPathComponent("Xcode")
            .appendingPathComponent("DerivedData")
        
        #expect(discovery.derivedDataPath == expectedPath)
    }
    
    @Test("IndexStoreDiscovery initializes with custom path")
    func testCustomPathInitialization() {
        let customPath = URL(fileURLWithPath: "/custom/path")
        let discovery = IndexStoreDiscovery(customPath: customPath)
        
        #expect(discovery.derivedDataPath == customPath)
    }
    
    @Test("IndexStoreDiscovery throws error for non-existent path")
    func testNonExistentPath() {
        let nonExistentPath = URL(fileURLWithPath: "/non/existent/path/\(UUID().uuidString)")
        let discovery = IndexStoreDiscovery(customPath: nonExistentPath)
        
        #expect(throws: DiscoveryError.self) {
            try discovery.discoverIndexStores()
        }
    }
    
    @Test("IndexStoreDiscovery with empty directory returns empty array")
    func testEmptyDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let discovery = IndexStoreDiscovery(customPath: tempDir)
        let stores = try discovery.discoverIndexStores()
        
        #expect(stores.isEmpty)
    }
}

@Suite("IndexStoreInfo Tests")
struct IndexStoreInfoTests {
    
    @Test("IndexStoreInfo stores all properties correctly")
    func testIndexStoreInfoProperties() {
        let now = Date()
        let info = IndexStoreInfo(
            projectName: "TestProject",
            indexStorePath: URL(fileURLWithPath: "/path/to/store"),
            derivedDataPath: URL(fileURLWithPath: "/path/to/derived"),
            lastModified: now,
            indexFileCount: 100
        )
        
        #expect(info.projectName == "TestProject")
        #expect(info.indexStorePath.path == "/path/to/store")
        #expect(info.derivedDataPath.path == "/path/to/derived")
        #expect(info.lastModified == now)
        #expect(info.indexFileCount == 100)
    }
}

@Suite("DiscoveryError Tests")
struct DiscoveryErrorTests {
    
    @Test("DiscoveryError provides descriptive error messages")
    func testErrorDescriptions() {
        let derivedDataError = DiscoveryError.derivedDataNotFound("/test/path")
        #expect(derivedDataError.errorDescription?.contains("/test/path") == true)
        
        let noStoresError = DiscoveryError.noIndexStoresFound
        #expect(noStoresError.errorDescription?.contains("No index stores found") == true)
        
        let cancelledError = DiscoveryError.userCancelled
        #expect(cancelledError.errorDescription?.contains("cancelled") == true)
        
        let invalidError = DiscoveryError.invalidSelection
        #expect(invalidError.errorDescription?.contains("Invalid selection") == true)
    }
}

// MARK: - ReportFormatter Tests

@Suite("ReportFormatter Tests")
struct ReportFormatterTests {
    
    func createSampleReport() -> EndpointReport {
        let reference = EndpointReference(
            file: "/project/Service.swift",
            line: 42,
            column: 10,
            symbolName: "resourcesURL",
            baseURL: "baseURL",
            pathComponents: ["api", "v1", "accounts"],
            fullPath: "api/v1/accounts"
        )
        
        let endpointInfo = EndpointInfo(
            fullPath: "api/v1/accounts",
            baseURL: "baseURL",
            pathComponents: ["api", "v1", "accounts"],
            references: [reference],
            declarationFile: "/project/Service.swift",
            declarationLine: 42
        )
        
        return EndpointReport(
            projectPath: "/test/project",
            analyzedFiles: 50,
            totalEndpoints: 1,
            endpoints: [endpointInfo],
            timestamp: "2024-01-01T00:00:00Z"
        )
    }
    
    @Test("ReportFormatter formats as text")
    func testTextFormat() {
        let formatter = ReportFormatter(format: .text)
        let report = createSampleReport()
        let output = formatter.format(report: report)
        
        #expect(output.contains("ENDPOINT ANALYSIS REPORT"))
        #expect(output.contains("/test/project"))
        #expect(output.contains("api/v1/accounts"))
        #expect(output.contains("Service.swift"))
    }
    
    @Test("ReportFormatter formats as JSON")
    func testJSONFormat() throws {
        let formatter = ReportFormatter(format: .json)
        let report = createSampleReport()
        let output = formatter.format(report: report)
        
        #expect(output.contains("projectPath"))
        #expect(output.contains("totalEndpoints"))
        // Note: JSON escapes slashes, so check for escaped version
        #expect(output.contains("api") && output.contains("accounts"))
        
        // Verify it's valid JSON
        let data = output.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(EndpointReport.self, from: data)
        #expect(decoded.totalEndpoints == 1)
    }
    
    @Test("ReportFormatter formats as Markdown")
    func testMarkdownFormat() {
        let formatter = ReportFormatter(format: .markdown)
        let report = createSampleReport()
        let output = formatter.format(report: report)
        
        #expect(output.contains("# Endpoint Analysis Report"))
        #expect(output.contains("**Project:**"))
        #expect(output.contains("**Total Endpoints:**"))
        #expect(output.contains("`api/v1/accounts`"))
        #expect(output.contains("| File | Line | Symbol |"))
    }
}

// MARK: - OutputFormat Tests

@Suite("OutputFormat Tests")
struct OutputFormatTests {
    
    @Test("OutputFormat has all required cases")
    func testOutputFormatCases() {
        let formats: [OutputFormat] = [.text, .json, .markdown]
        #expect(formats.count == 3)
    }
    
    @Test("OutputFormat can be created from string")
    func testOutputFormatFromString() {
        #expect(OutputFormat(rawValue: "text") == .text)
        #expect(OutputFormat(rawValue: "json") == .json)
        #expect(OutputFormat(rawValue: "markdown") == .markdown)
    }
}
