# Next Steps & Missing URL Operations

## Currently Supported

✅ **URL Property Detection**
- Properties/variables with "url" or "endpoint" in the name
- Lazy properties with URL construction
- Instance properties, class properties, static properties

✅ **Path Construction**
- `.appendingPathComponent("path")` - single and chained
- Path components with slashes (e.g., "api/services/coordinator")
- Empty path components

## Missing URL Operations & Patterns

### 1. URL Initialization Patterns ⭐ HIGH PRIORITY

**Current Gap**: We only detect `.appendingPathComponent()`, but URLs are constructed in many ways.

**Missing Patterns**:

```swift
// Direct URL initialization
let url = URL(string: "https://api.example.com/users")

// URL components
var components = URLComponents()
components.scheme = "https"
components.host = "api.example.com"
components.path = "/users"
let url = components.url

// String interpolation
let userId = 123
let url = URL(string: "https://api.example.com/users/\(userId)")

// String concatenation
let baseURL = "https://api.example.com"
let endpoint = baseURL + "/users"
let url = URL(string: endpoint)

// Path joining with /
let url = URL(string: baseURL + "/" + "users" + "/" + "profile")
```

**Why It Matters**: Many iOS apps use `URL(string:)` directly, especially for string-based endpoints.

**Implementation**:
- Detect `URL(string:)` initializer calls
- Extract string literals and interpolations
- Track string concatenation patterns

---

### 2. URLRequest Construction ⭐ HIGH PRIORITY

**Current Gap**: We don't track how URLs are used in network requests.

**Missing Patterns**:

```swift
// URLRequest initialization
var request = URLRequest(url: resourcesURL)
request.httpMethod = "POST"

// URLSession methods
URLSession.shared.dataTask(with: resourcesURL)
URLSession.shared.dataTask(with: request)

// Common patterns
func fetchUsers() {
    let request = URLRequest(url: usersURL)
    // ...
}
```

**Why It Matters**: 
- Tracks which endpoints are actually used in network calls
- Can detect HTTP methods (GET, POST, PUT, DELETE)
- Shows the full context of API usage

**Implementation**:
- Detect `URLRequest` initializations
- Track `httpMethod` assignments
- Find `URLSession` method calls
- Associate HTTP methods with endpoints

---

### 3. Query Parameters ⭐ MEDIUM PRIORITY

**Current Gap**: We don't track query parameters added to URLs.

**Missing Patterns**:

```swift
// appendingQueryItem
var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
components?.queryItems = [
    URLQueryItem(name: "userId", value: userId),
    URLQueryItem(name: "limit", value: "10")
]
let url = components?.url

// appendingQueryItems
components?.queryItems?.append(URLQueryItem(name: "offset", value: "0"))

// String-based query parameters
let url = URL(string: "\(baseURL)?userId=\(userId)&limit=10")
```

**Why It Matters**:
- Many APIs use query parameters for filtering/pagination
- Complete endpoint signature includes query params
- Useful for API documentation generation

**Implementation**:
- Track `URLComponents` usage
- Detect `queryItems` assignments
- Parse query strings in URL(string:)
- Store parameters with endpoint

---

### 4. HTTP Headers & Body ⭐ MEDIUM PRIORITY

**Current Gap**: We don't track headers or request bodies.

**Missing Patterns**:

```swift
// Headers
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

// Body
let body = ["username": "john", "password": "secret"]
request.httpBody = try? JSONEncoder().encode(body)

// Common patterns
request.addValue("gzip", forHTTPHeaderField: "Accept-Encoding")
```

**Why It Matters**:
- Documents authentication requirements
- Shows content types (JSON, form data, etc.)
- Complete API signature

**Implementation**:
- Track `setValue(_:forHTTPHeaderField:)` calls
- Detect `httpBody` assignments
- Associate headers with endpoints

---

### 5. Network Library Support 🔌 HIGH PRIORITY

**Current Gap**: Only works with Foundation's URL APIs.

**Missing Libraries**:

#### Alamofire
```swift
AF.request("https://api.example.com/users")
    .responseJSON { response in }

AF.request(usersURL, method: .post, parameters: params)
```

#### Moya
```swift
enum UserAPI {
    case getUser(id: Int)
    case createUser(User)
}

extension UserAPI: TargetType {
    var baseURL: URL { return URL(string: "https://api.example.com")! }
    var path: String {
        switch self {
        case .getUser(let id): return "/users/\(id)"
        case .createUser: return "/users"
        }
    }
}
```

#### URLSession Extensions
```swift
extension URLSession {
    func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T
}
```

**Why It Matters**: Many production apps use these popular libraries.

**Implementation**:
- Plugin architecture for library-specific detectors
- Alamofire: Track `AF.request()` calls
- Moya: Parse `TargetType` implementations
- Custom extensions: Configurable patterns

---

### 6. Environment-Based URLs 🌍 MEDIUM PRIORITY

**Current Gap**: We don't track environment-specific base URLs.

**Missing Patterns**:

```swift
// Environment switching
#if DEBUG
let baseURL = "https://dev.api.example.com"
#else
let baseURL = "https://api.example.com"
#endif

// Configuration-based
enum Environment {
    case development, staging, production
    
    var baseURL: String {
        switch self {
        case .development: return "https://dev.api.example.com"
        case .staging: return "https://staging.api.example.com"
        case .production: return "https://api.example.com"
        }
    }
}

// Property wrappers
@Environment(\.apiBaseURL) var baseURL
```

**Why It Matters**:
- Shows different environments
- Tracks staging vs production URLs
- Complete deployment picture

**Implementation**:
- Detect `#if DEBUG` / `#if RELEASE` blocks
- Track enum-based URL switching
- Parse property wrappers

---

### 7. WebSocket & GraphQL 📡 LOW PRIORITY

**Current Gap**: REST-only focus.

**Missing Patterns**:

```swift
// WebSocket
let socket = URLSessionWebSocketTask(url: wsURL)
let webSocket = WebSocket(url: URL(string: "wss://api.example.com/ws")!)

// GraphQL
let apollo = ApolloClient(url: URL(string: "https://api.example.com/graphql")!)

// GraphQL queries
let query = """
    query GetUser($id: ID!) {
        user(id: $id) { name email }
    }
"""
```

**Why It Matters**: Modern apps increasingly use these technologies.

**Implementation**:
- Detect WebSocket URL patterns
- Parse GraphQL endpoint declarations
- Track query/mutation definitions

---

### 8. URL Validation & Transformation 🔄 LOW PRIORITY

**Current Gap**: We don't track URL validation or transformations.

**Missing Patterns**:

```swift
// URL validation
guard let url = URL(string: urlString), 
      url.scheme == "https" else { return }

// URL transformation
let secureURL = url.replacingScheme(with: "https")
let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

// URL components manipulation
var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
components?.scheme = "https"
components?.port = 8080
```

**Why It Matters**: Security and reliability concerns.

**Implementation**:
- Track URL validation patterns
- Detect scheme replacements
- Monitor encoding operations

---

### 9. Async/Await Network Patterns ⚡ MEDIUM PRIORITY

**Current Gap**: We don't specifically track modern async patterns.

**Missing Patterns**:

```swift
// Async URLSession
let (data, response) = try await URLSession.shared.data(from: usersURL)

// Async sequences
for try await line in url.lines {
    // ...
}

// Modern networking
func fetchUser(id: Int) async throws -> User {
    let url = baseURL.appendingPathComponent("users/\(id)")
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}
```

**Why It Matters**: Modern Swift heavily uses async/await.

**Implementation**:
- Track async function calls with URLs
- Detect `try await` patterns
- Associate error handling with endpoints

---

### 10. Multipart Form Data & File Uploads 📤 LOW PRIORITY

**Current Gap**: We don't track file upload endpoints.

**Missing Patterns**:

```swift
// Multipart form data
var request = URLRequest(url: uploadURL)
request.httpMethod = "POST"
let boundary = UUID().uuidString
request.setValue("multipart/form-data; boundary=\(boundary)", 
                 forHTTPHeaderField: "Content-Type")

// File upload
request.httpBody = imageData
request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
```

**Why It Matters**: Different endpoint type with different requirements.

**Implementation**:
- Detect multipart form data setup
- Track file upload patterns
- Classify endpoints by type

---

## Recommended Implementation Priority

### Phase 1: Core URL Patterns (2-3 weeks)
1. ✅ **URL(string:)** initialization - Most common pattern
2. ✅ **URLRequest** construction - Shows actual usage
3. ✅ **String concatenation** - Common in older code

**Deliverable**: Support 80% of real-world URL patterns

### Phase 2: Query Parameters & Headers (1-2 weeks)
4. ✅ **URLComponents** and query parameters
5. ✅ **HTTP headers** tracking
6. ✅ **HTTP methods** (GET/POST/etc.)

**Deliverable**: Complete request signature tracking

### Phase 3: Network Libraries (2-4 weeks)
7. ✅ **Alamofire** support
8. ✅ **Moya** support
9. ✅ Plugin architecture for custom libraries

**Deliverable**: Support popular networking libraries

### Phase 4: Advanced Features (2-3 weeks)
10. ✅ **Environment-based URLs**
11. ✅ **Async/await patterns**
12. ✅ **WebSocket & GraphQL** (if needed)

**Deliverable**: Complete modern iOS app coverage

---

## Implementation Architecture

### Plugin System Design

```swift
protocol URLPatternDetector {
    /// Name of the pattern (e.g., "Alamofire", "URL(string:)")
    var name: String { get }
    
    /// Detect if this visitor can handle the syntax node
    func canHandle(_ node: SyntaxProtocol) -> Bool
    
    /// Extract URL information from the node
    func extract(from node: SyntaxProtocol, context: AnalysisContext) -> [URLPattern]?
}

struct URLPattern {
    let url: String?
    let method: HTTPMethod?
    let queryParameters: [QueryParameter]
    let headers: [HTTPHeader]
    let location: SourceLocation
}
```

### Example Detectors

```swift
class URLStringInitDetector: URLPatternDetector {
    var name: String { "URL(string:)" }
    
    func canHandle(_ node: SyntaxProtocol) -> Bool {
        // Check if this is URL(string:) call
    }
    
    func extract(from node: SyntaxProtocol, context: AnalysisContext) -> [URLPattern]? {
        // Extract URL string literal
    }
}

class AlamofireDetector: URLPatternDetector {
    var name: String { "Alamofire" }
    
    func canHandle(_ node: SyntaxProtocol) -> Bool {
        // Check if this is AF.request() call
    }
    
    func extract(from node: SyntaxProtocol, context: AnalysisContext) -> [URLPattern]? {
        // Extract Alamofire request details
    }
}
```

---

## Enhanced Data Models

### Extended EndpointReference

```swift
struct EndpointReference: Codable {
    // Existing
    let file: String
    let line: Int
    let column: Int
    let symbolName: String
    let baseURL: String?
    let pathComponents: [String]
    let fullPath: String
    
    // New additions
    let constructionPattern: URLConstructionPattern  // appendingPathComponent, URL(string:), etc.
    let httpMethod: HTTPMethod?                      // GET, POST, PUT, DELETE
    let queryParameters: [QueryParameter]            // URL query parameters
    let headers: [HTTPHeader]                        // HTTP headers
    let requestBody: RequestBody?                    // Body content info
    let isWebSocket: Bool                            // WebSocket endpoint
    let environment: String?                         // dev, staging, prod
    let usageContext: UsageContext                   // Where/how it's used
}

enum URLConstructionPattern: String, Codable {
    case appendingPathComponent
    case urlStringInit
    case urlComponents
    case stringConcatenation
    case alamofire
    case moya
    case custom
}

enum HTTPMethod: String, Codable {
    case GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
}

struct QueryParameter: Codable {
    let name: String
    let value: String?  // Nil if dynamic
    let isDynamic: Bool
}

struct HTTPHeader: Codable {
    let name: String
    let value: String?
    let isDynamic: Bool
}

struct RequestBody: Codable {
    let contentType: String
    let isMultipart: Bool
    let fields: [String]?  // For structured data
}

struct UsageContext: Codable {
    let function: String?
    let class: String?
    let isAsync: Bool
    let errorHandling: Bool
}
```

---

## New CLI Commands

### 1. Analyze Specific Endpoint

```bash
swift-url-finder analyze \
  --project ~/MyApp \
  --endpoint "users/profile" \
  --show-usage \
  --show-headers \
  --show-body
```

Output:
```
📍 Endpoint: users/profile

🔗 Construction:
  Pattern: appendingPathComponent
  Base: baseURL (https://api.example.com)
  Full: https://api.example.com/users/profile

📡 Network Usage:
  Method: GET
  Headers:
    - Authorization: Bearer {token}
    - Content-Type: application/json
  
🎯 References (3):
  1. UserService.swift:45 (fetchUserProfile)
     - Async: Yes
     - Error Handling: Yes
  
  2. ProfileViewController.swift:89 (loadProfile)
     - Async: Yes
     - Caching: Yes
  
  3. OfflineManager.swift:123 (syncProfile)
     - Async: Yes
     - Background: Yes
```

### 2. Compare Environments

```bash
swift-url-finder compare \
  --project ~/MyApp \
  --environments dev,staging,prod
```

Output:
```
🌍 Environment Comparison:

baseURL:
  dev:     https://dev.api.example.com
  staging: https://staging.api.example.com
  prod:    https://api.example.com

Endpoints using baseURL: 47

⚠️  Environment-specific endpoints:
  - /debug/logs (dev only)
  - /admin/metrics (staging, prod)
```

### 3. Validate Endpoints

```bash
swift-url-finder validate \
  --project ~/MyApp \
  --check-https \
  --check-duplicates
```

Output:
```
✅ Security Check:
  - All endpoints use HTTPS
  
⚠️  Potential Issues:
  - 3 endpoints use HTTP for localhost
  - 2 duplicate endpoint definitions found:
    • users/profile defined in UserService.swift:45 and ProfileService.swift:89
```

---

## Testing Strategy for New Features

### Test Coverage Goals

1. **URL Pattern Detection** - 90% coverage
   - Each pattern type has tests
   - Edge cases (empty strings, nil, special chars)
   - Nested patterns

2. **Network Library Integration** - 80% coverage
   - Alamofire request patterns
   - Moya target types
   - Custom extensions

3. **Data Model Serialization** - 100% coverage
   - All new fields Codable
   - Backward compatibility
   - Migration tests

---

## Documentation Updates Needed

1. **README.md** - Add new pattern examples
2. **EXAMPLES.md** - Show Alamofire/Moya usage
3. **AI_INSTRUCTIONS.md** - Document plugin architecture
4. **API_PATTERNS.md** - New doc for supported patterns

---

## Performance Considerations

### Concerns
- More patterns = slower analysis
- IndexStoreDB queries can be expensive
- Large projects (1000+ files)

### Solutions
1. **Parallel Processing** - Analyze files concurrently
2. **Caching** - Cache analysis results per file
3. **Incremental Analysis** - Only re-analyze changed files
4. **Lazy Loading** - Load details on-demand
5. **Progress Reporting** - Show % complete for large projects

---

## Breaking Changes to Consider

### Version 2.0 Changes

1. **Model Updates** - Extended `EndpointReference` structure
2. **JSON Format** - Updated report format
3. **CLI Arguments** - New required `--pattern` flag?

### Migration Path
- Support old JSON format with compatibility layer
- Provide migration tool
- Clear upgrade documentation

---

## Community Engagement

### Gather Real-World Patterns
1. Survey popular iOS projects on GitHub
2. Analyze top networking libraries
3. Document common patterns
4. Prioritize by usage frequency

### Example Projects to Study
- Alamofire examples
- Moya examples
- Open-source iOS apps (WordPress, Firefox, Signal)
- Apple sample code

---

## Success Metrics

### How to measure improvement:

1. **Pattern Coverage**: % of URLs detected in sample projects
2. **Library Support**: Number of popular libraries supported
3. **User Adoption**: GitHub stars, downloads
4. **Real-World Usage**: Survey users on what patterns they use
5. **Performance**: Time to analyze large project (< 30s for 1000 files)

---

## Quick Wins (Can Implement Today)

### 1. URL(string:) Detection (2-3 hours)
```swift
// Add to URLConstructionVisitor
if let call = node.as(FunctionCallExprSyntax.self),
   call.calledExpression.description.contains("URL"),
   let arg = call.arguments.first?.expression.as(StringLiteralExprSyntax.self) {
    // Extract URL string
}
```

### 2. HTTP Method Detection (1-2 hours)
```swift
// Track httpMethod assignments
if let assignment = node.as(AssignmentExprSyntax.self),
   assignment.left.description.contains("httpMethod") {
    // Extract method
}
```

### 3. String Concatenation (2-3 hours)
```swift
// Detect + operator on strings
if let binary = node.as(BinaryOperatorExprSyntax.self),
   binary.operator.text == "+" {
    // Track string concatenation
}
```

---

## Conclusion

The tool currently handles **basic URL construction** well, but misses:
- **Direct URL initialization** (high impact)
- **Network library patterns** (high impact for real apps)
- **Request context** (methods, headers, body)
- **Query parameters** (common in REST APIs)

Implementing **Phase 1** alone would dramatically increase the tool's usefulness in real-world projects.
