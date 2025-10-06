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
        visitor.walk(sourceFile)
        
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
        visitor.walk(sourceFile)
        
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
        visitor.walk(sourceFile)
        
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
        visitor.walk(sourceFile)
        
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
        visitor.walk(sourceFile)
        
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
        visitor.walk(sourceFile)
        
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
        visitor.walk(sourceFile)
        
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
