import Foundation

/// HTTP methods for network requests
enum HTTPMethod: String, Codable, CaseIterable {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
    case HEAD
    case OPTIONS
    case CONNECT
    case TRACE
}

/// Represents a reference to an endpoint URL in the codebase
struct EndpointReference: Codable {
    let file: String
    let line: Int
    let column: Int
    let symbolName: String
    let baseURL: String?
    let pathComponents: [String]
    let fullPath: String
    let httpMethod: String?  // Optional HTTP method if used in URLRequest
    let isURLRequest: Bool   // Whether this is used in a URLRequest
    
    var description: String {
        let methodStr = httpMethod.map { " [\($0)]" } ?? ""
        return "\(file):\(line):\(column) - \(symbolName)\(methodStr) -> \(fullPath)"
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
    var httpMethod: String?      // HTTP method if this URL is used in a request
    var isURLRequest: Bool = false  // Whether this is a URLRequest
    
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
