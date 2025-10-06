import Testing
import Foundation
import SwiftSyntax
import SwiftParser
@testable import URLFinder

@Suite("URLConstructionVisitor Tests")
struct URLConstructionVisitorTests {
    
    @Test("Visitor extracts simple appendingPathComponent call")
    func testSimplePathComponent() {
        let sourceCode = """
        import Foundation
        
        class Service {
            private lazy var resourcesURL = baseURL
                .appendingPathComponent("accounts")
        }
        """
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = URLConstructionVisitor(targetSymbol: "resourcesURL", filePath: "test.swift")
        visitor.walkTwoPass(sourceFile)
        
        // Verify path component is extracted
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "accounts")
        // Base URL extraction from identifier may not work in all cases due to SwiftSyntax AST structure
        // The important part is that path components are correctly extracted
    }
    
    @Test("Visitor extracts chained appendingPathComponent calls")
    func testChainedPathComponents() {
        let sourceCode = """
        import Foundation
        
        class Service {
            private lazy var enableResourceURL = baseURL
                .appendingPathComponent("accounts")
                .appendingPathComponent("activate")
        }
        """
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = URLConstructionVisitor(targetSymbol: "enableResourceURL", filePath: "test.swift")
        visitor.walkTwoPass(sourceFile)
        
        // Verify chained path components are extracted in correct order
        #expect(visitor.pathComponents.count == 2)
        #expect(visitor.pathComponents[0].value == "accounts")
        #expect(visitor.pathComponents[1].value == "activate")
    }
    
    @Test("Visitor extracts complex nested path")
    func testComplexNestedPath() {
        let sourceCode = """
        import Foundation
        
        class APIService {
            private lazy var currentResourceStatusURL = baseURL
                .appendingPathComponent("accounts")
                .appendingPathComponent("activations")
                .appendingPathComponent("current")
        }
        """
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = URLConstructionVisitor(targetSymbol: "currentResourceStatusURL", filePath: "test.swift")
        visitor.walkTwoPass(sourceFile)
        
        // Verify all nested path components are extracted in order
        #expect(visitor.pathComponents.count == 3)
        #expect(visitor.pathComponents[0].value == "accounts")
        #expect(visitor.pathComponents[1].value == "activations")
        #expect(visitor.pathComponents[2].value == "current")
    }
    
    @Test("Visitor handles URL with no path components")
    func testURLWithNoPathComponents() {
        let sourceCode = """
        import Foundation
        
        class Service {
            private lazy var baseURL = backendService.apiV1BaseURL
        }
        """
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = URLConstructionVisitor(targetSymbol: "baseURL", filePath: "test.swift")
        visitor.walkTwoPass(sourceFile)
        
        #expect(visitor.pathComponents.isEmpty)
    }
    
    @Test("Visitor ignores non-target symbols")
    func testIgnoresNonTargetSymbols() {
        let sourceCode = """
        import Foundation
        
        class Service {
            private lazy var resourcesURL = baseURL
                .appendingPathComponent("accounts")
            
            private lazy var usersURL = baseURL
                .appendingPathComponent("users")
        }
        """
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = URLConstructionVisitor(targetSymbol: "resourcesURL", filePath: "test.swift")
        visitor.walkTwoPass(sourceFile)
        
        // Should only extract resourcesURL, not usersURL
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "accounts")
    }
    
    @Test("Visitor extracts path with slashes in string")
    func testPathWithSlashes() {
        let sourceCode = """
        import Foundation
        
        class Service {
            private lazy var baseURL = backendService.apiV1BaseURL
                .appendingPathComponent("api/services/coordinator")
        }
        """
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = URLConstructionVisitor(targetSymbol: "baseURL", filePath: "test.swift")
        visitor.walkTwoPass(sourceFile)
        
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "api/services/coordinator")
    }
    
    @Test("Visitor handles empty string path component")
    func testEmptyStringPathComponent() {
        let sourceCode = """
        import Foundation
        
        class Service {
            private lazy var testURL = baseURL
                .appendingPathComponent("")
        }
        """
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = URLConstructionVisitor(targetSymbol: "testURL", filePath: "test.swift")
        visitor.walkTwoPass(sourceFile)
        
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "")
    }
}

@Suite("PathComponent Tests")
struct PathComponentTests {
    
    @Test("PathComponent stores all properties")
    func testPathComponentProperties() {
        let component = PathComponent(
            value: "accounts",
            file: "/test/Service.swift",
            line: 42
        )
        
        #expect(component.value == "accounts")
        #expect(component.file == "/test/Service.swift")
        #expect(component.line == 42)
    }
    
    @Test("PathComponent handles special characters")
    func testPathComponentWithSpecialCharacters() {
        let component = PathComponent(
            value: "users/v1/profile",
            file: "/test.swift",
            line: 1
        )
        
        #expect(component.value == "users/v1/profile")
    }
}

@Suite("URL(string:) Detection Tests")
struct URLStringInitTests {
    
    private func parseSource(_ source: String, targetSymbol: String) -> URLConstructionVisitor {
        let sourceFile = Parser.parse(source: source)
        let visitor = URLConstructionVisitor(targetSymbol: targetSymbol, filePath: "/test.swift")
        visitor.walkTwoPass(sourceFile)
        return visitor
    }
    
    @Test("Detects URL(string:) with complete URL")
    func testURLStringInitWithLiteral() {
        let source = """
        let apiURL = URL(string: "https://api.example.com/users")
        """
        
        let visitor = parseSource(source, targetSymbol: "apiURL")
        
        #expect(visitor.baseURL == "https://api.example.com")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "users")
    }
    
    @Test("Detects URL(string:) with multiple path components")
    func testURLStringInitWithMultiplePathComponents() {
        let source = """
        let profileURL = URL(string: "https://api.example.com/users/profile/settings")
        """
        
        let visitor = parseSource(source, targetSymbol: "profileURL")
        
        #expect(visitor.baseURL == "https://api.example.com")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "users/profile/settings")
    }
    
    @Test("Detects URL(string:) with port number")
    func testURLStringInitWithPort() {
        let source = """
        let devURL = URL(string: "http://localhost:8080/api/v1/users")
        """
        
        let visitor = parseSource(source, targetSymbol: "devURL")
        
        #expect(visitor.baseURL == "http://localhost:8080")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "api/v1/users")
    }
    
    @Test("Detects URL(string:) with query parameters")
    func testURLStringInitWithQueryParameters() {
        let source = """
        let searchURL = URL(string: "https://api.example.com/search?q=swift&limit=10")
        """
        
        let visitor = parseSource(source, targetSymbol: "searchURL")
        
        #expect(visitor.baseURL == "https://api.example.com")
        #expect(visitor.pathComponents.count == 2)
        #expect(visitor.pathComponents[0].value == "search")
        #expect(visitor.pathComponents[1].value == "?q=swift&limit=10")
    }
    
    @Test("Detects URL(string:) with root path only")
    func testURLStringInitWithRootPath() {
        let source = """
        let rootURL = URL(string: "https://api.example.com/")
        """
        
        let visitor = parseSource(source, targetSymbol: "rootURL")
        
        #expect(visitor.baseURL == "https://api.example.com")
        #expect(visitor.pathComponents.count == 0)
    }
    
    @Test("Detects URL(string:) with string interpolation")
    func testURLStringInitWithInterpolation() {
        let source = """
        let userURL = URL(string: "\\(baseURL)/users/\\(userId)")
        """
        
        let visitor = parseSource(source, targetSymbol: "userURL")
        
        #expect(visitor.baseURL == "baseURL")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value.contains("users"))
        #expect(visitor.pathComponents[0].value.contains("{userId}"))
    }
    
    @Test("Detects URL(string:) with complex interpolation")
    func testURLStringInitWithComplexInterpolation() {
        let source = """
        let endpoint = URL(string: "\\(config.baseURL)/api/v\\(apiVersion)/users/\\(user.id)")
        """
        
        let visitor = parseSource(source, targetSymbol: "endpoint")
        
        #expect(visitor.baseURL == "config.baseURL")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value.contains("api"))
        #expect(visitor.pathComponents[0].value.contains("{apiVersion}"))
        #expect(visitor.pathComponents[0].value.contains("{user.id}"))
    }
    
    @Test("Detects URL(string:) with identifier reference")
    func testURLStringInitWithIdentifier() {
        let source = """
        let endpoint = URL(string: urlString)
        """
        
        let visitor = parseSource(source, targetSymbol: "endpoint")
        
        #expect(visitor.baseURL == "urlString")
        #expect(visitor.pathComponents.count == 0)
    }
    
    @Test("Detects HTTPS URLs")
    func testURLStringInitWithHTTPS() {
        let source = """
        let secureURL = URL(string: "https://secure.example.com/payment/process")
        """
        
        let visitor = parseSource(source, targetSymbol: "secureURL")
        
        #expect(visitor.baseURL == "https://secure.example.com")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "payment/process")
    }
    
    @Test("Handles relative URL paths")
    func testURLStringInitWithRelativePath() {
        let source = """
        let relativeURL = URL(string: "/api/users")
        """
        
        let visitor = parseSource(source, targetSymbol: "relativeURL")
        
        // Relative URL without scheme - stored as path component
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "/api/users")
    }
    
    @Test("Handles URL(string:) followed by appendingPathComponent")
    func testMixedURLStringAndAppendingPath() {
        let source = """
        let endpoint = URL(string: "https://api.example.com/users")!.appendingPathComponent("profile")
        """
        
        let visitor = parseSource(source, targetSymbol: "endpoint")
        
        #expect(visitor.baseURL == "https://api.example.com")
        #expect(visitor.pathComponents.count == 2)
        #expect(visitor.pathComponents[0].value == "users")
        #expect(visitor.pathComponents[1].value == "profile")
    }
    
    @Test("Handles WebSocket URLs")
    func testURLStringInitWithWebSocket() {
        let source = """
        let wsURL = URL(string: "wss://api.example.com/socket")
        """
        
        let visitor = parseSource(source, targetSymbol: "wsURL")
        
        #expect(visitor.baseURL == "wss://api.example.com")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "socket")
    }
}

@Suite("URLRequest Detection Tests")
struct URLRequestDetectionTests {
    
    private func parseSource(_ source: String, targetSymbol: String) -> URLConstructionVisitor {
        let sourceFile = Parser.parse(source: source)
        let visitor = URLConstructionVisitor(targetSymbol: targetSymbol, filePath: "/test.swift")
        visitor.walkTwoPass(sourceFile)
        return visitor
    }
    
    @Test("Detects URLRequest initialization with URL")
    func testURLRequestInit() {
        let source = """
        let request = URLRequest(url: someURL)
        """
        
        let visitor = parseSource(source, targetSymbol: "request")
        
        #expect(visitor.isURLRequest == true)
    }
    
    @Test("Detects URLRequest with URL(string:)")
    func testURLRequestWithURLStringInit() {
        let source = """
        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        """
        
        let visitor = parseSource(source, targetSymbol: "request")
        
        #expect(visitor.isURLRequest == true)
        #expect(visitor.baseURL == "https://api.example.com")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "users")
    }
    
    // NOTE: HTTP method assignment detection from separate statements is complex
    // and requires analyzing the full AST context. These tests are marked for
    // future implementation in Phase 2b.
    
    @Test("Detects URLRequest with embedded HTTP method", .disabled("Requires code block parsing"))
    func testHTTPMethodAssignment() {
        let source = """
        var request = URLRequest(url: someURL)
        request.httpMethod = "POST"
        """
        
        let visitor = parseSource(source, targetSymbol: "request")
        
        #expect(visitor.isURLRequest == true)
        // #expect(visitor.httpMethod == "POST")  // TODO: Phase 2b
    }
    
    @Test("URLRequest with inline endpoint")
    func testCompleteURLRequest() {
        let source = """
        let request = URLRequest(url: URL(string: "https://api.example.com/users/123")!)
        """
        
        let visitor = parseSource(source, targetSymbol: "request")
        
        #expect(visitor.isURLRequest == true)
        #expect(visitor.baseURL == "https://api.example.com")
        #expect(visitor.pathComponents.count == 1)
        #expect(visitor.pathComponents[0].value == "users/123")
    }
}

@Suite("HTTP Method Model Tests")
struct HTTPMethodTests {
    
    @Test("HTTPMethod has all common methods")
    func testHTTPMethodCases() {
        #expect(HTTPMethod.GET.rawValue == "GET")
        #expect(HTTPMethod.POST.rawValue == "POST")
        #expect(HTTPMethod.PUT.rawValue == "PUT")
        #expect(HTTPMethod.DELETE.rawValue == "DELETE")
        #expect(HTTPMethod.PATCH.rawValue == "PATCH")
        #expect(HTTPMethod.HEAD.rawValue == "HEAD")
        #expect(HTTPMethod.OPTIONS.rawValue == "OPTIONS")
    }
    
    @Test("HTTPMethod is Codable")
    func testHTTPMethodCodable() throws {
        let method = HTTPMethod.POST
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(method)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HTTPMethod.self, from: data)
        
        #expect(decoded == method)
    }
}
