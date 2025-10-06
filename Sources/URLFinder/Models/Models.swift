import Foundation

/// Represents a reference to an endpoint URL in the codebase
struct EndpointReference: Codable {
    let file: String
    let line: Int
    let column: Int
    let symbolName: String
    let baseURL: String?
    let pathComponents: [String]
    let fullPath: String
    
    var description: String {
        "\(file):\(line):\(column) - \(symbolName) -> \(fullPath)"
    }
}

/// Represents a URL declaration in the code
struct URLDeclaration {
    let name: String
    let file: String
    let line: Int
    let column: Int
    let baseURL: String?
    var pathComponents: [PathComponent] = []
    
    var fullPath: String {
        pathComponents.map { $0.value }.joined(separator: "/")
    }
}

/// Represents a path component added to a URL
struct PathComponent {
    let value: String
    let file: String
    let line: Int
}

/// Report containing all endpoints found in the project
struct EndpointReport: Codable {
    let projectPath: String
    let analyzedFiles: Int
    let totalEndpoints: Int
    let endpoints: [EndpointInfo]
    let timestamp: String
}

/// Information about a single endpoint
struct EndpointInfo: Codable {
    let fullPath: String
    let baseURL: String?
    let pathComponents: [String]
    let references: [EndpointReference]
    let declarationFile: String
    let declarationLine: Int
}
