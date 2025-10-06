import Foundation

/// Network client for testing
class NetworkClient {
    private let baseURL = "https://api.myapp.com"
    
    // Test: Multiple endpoints in one file
    let loginEndpoint = URL(string: "https://api.myapp.com/auth/login")!
    let logoutEndpoint = URL(string: "https://api.myapp.com/auth/logout")!
    
    // Test: Computed property with path
    var settingsURL: URL {
        URL(string: "\(baseURL)/settings")!
    }
}
