import Foundation

/// Sample service for testing endpoint detection
class APIService {
    let baseURL = URL(string: "https://api.example.com")!
    
    // Test: Simple URL with appendingPathComponent
    lazy var usersEndpoint: URL = {
        baseURL.appendingPathComponent("users")
    }()
    
    // Test: Chained path components
    lazy var userProfileEndpoint: URL = {
        baseURL
            .appendingPathComponent("users")
            .appendingPathComponent("profile")
    }()
    
    // Test: Direct URL(string:) initialization
    let searchURL = URL(string: "https://api.example.com/search")!
    
    // Test: URL with query parameters
    let paginatedURL = URL(string: "https://api.example.com/items?page=1&limit=20")!
    
    // Test: String interpolation
    func userURL(for userId: Int) -> URL {
        URL(string: "\(baseURL)/users/\(userId)")!
    }
    
    // Test: URLRequest
    func createUserRequest() -> URLRequest {
        URLRequest(url: URL(string: "https://api.example.com/users")!)
    }
    
    // Test: Endpoint variable
    var accountsEndpoint: URL {
        baseURL.appendingPathComponent("accounts")
    }
}
