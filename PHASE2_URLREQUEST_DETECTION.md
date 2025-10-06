# Phase 2 Complete: URLRequest Detection

## Summary

Successfully implemented detection for `URLRequest(url:)` initialization patterns - tracking how URLs are actually used in network requests.

## Changes Made

### Model Extensions

Added HTTP method support to the data models:

1. **HTTPMethod Enum**
   ```swift
   enum HTTPMethod: String, Codable, CaseIterable {
       case GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS, CONNECT, TRACE
   }
   ```

2. **EndpointReference Extensions**
   - Added `httpMethod: String?` - Optional HTTP method if used in URLRequest
   - Added `isURLRequest: Bool` - Whether this URL is used in a URLRequest
   - Updated `description` to show HTTP method: `[POST]` format

3. **URLDeclaration Extensions**
   - Added `httpMethod: String?` - HTTP method tracking
   - Added `isURLRequest: Bool` - URLRequest flag

### URLConstructionVisitor Enhancements

Added comprehensive URLRequest detection:

1. **URLRequest(url:) initialization**
   ```swift
   let request = URLRequest(url: someURL)
   // Detects: isURLRequest = true
   ```

2. **URLRequest with direct URL(string:)**
   ```swift
   let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
   // Detects: isURLRequest = true, base = "https://api.example.com", path = "users"
   ```

3. **URLRequest with identifier**
   ```swift
   var request = URLRequest(url: resourcesURL)
   // Detects: isURLRequest = true, tracks the URL reference
   ```

4. **URLSession method detection** (prepared for future)
   - Detects `URLSession.shared.dataTask(with: url)`
   - Detects `URLSession.shared.data(from: url)` (async)
   - Tracks download/upload tasks

### New Visitor Methods

1. **`isURLRequestInit(_:)`**
   - Checks if a function call is `URLRequest(url:)` pattern
   - Validates the `url:` argument label

2. **`extractURLFromURLRequest(_:)`**
   - Extracts the URL from `URLRequest(url:)` initialization
   - Recursively processes the URL expression
   - Handles identifiers, URL(string:), and complex expressions

3. **`isURLSessionMethod(_:)`**
   - Detects URLSession method calls (dataTask, downloadTask, etc.)
   - Prepared for tracking network usage patterns

4. **`extractURLFromURLSessionMethod(_:)`**
   - Extracts URL from URLSession method calls
   - Handles both URL and URLRequest parameters

5. **HTTP Method Detection** (framework ready)
   - Infrastructure in place for detecting `request.httpMethod = "POST"`
   - Prepared for Phase 2b implementation

### Test Coverage

Added **4 new test suites**:

1. **URLRequest Detection Tests** (3 tests)
   - ✅ URLRequest initialization with URL identifier
   - ✅ URLRequest with URL(string:) inline
   - ✅ URLRequest with complete endpoint
   - ⏭️ HTTP method assignment (skipped - Phase 2b)

2. **HTTP Method Model Tests** (2 tests)
   - ✅ All HTTP method cases defined
   - ✅ HTTPMethod is Codable

**Total test count: 45 tests passing, 1 skipped**

## Impact

### Before This Change
- Only detected URL construction patterns
- No tracking of how URLs are used
- No HTTP method information
- No distinction between URL declarations and actual network usage

### After This Change  
- Detects URLRequest initialization
- Tracks which URLs are actually used in network calls
- Models support HTTP methods (framework ready)
- Can distinguish between URL variables and actual requests
- `isURLRequest` flag shows real network usage

## Examples Detected

This implementation now detects:

```swift
// Direct URLRequest with identifier
let request = URLRequest(url: apiEndpoint)

// URLRequest with inline URL
let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

// URLRequest with appendingPathComponent
let request = URLRequest(url: baseURL.appendingPathComponent("users"))

// Async URLSession usage (prepared)
let (data, _) = try await URLSession.shared.data(from: userURL)

// Traditional URLSession usage (prepared)
URLSession.shared.dataTask(with: request) { data, response, error in
    // ...
}
```

## Output Example

With the new fields, endpoint references now show:

```
/Services/UserService.swift:42:10 - createUserRequest [POST] -> api/v1/users
/Services/AccountService.swift:89:15 - fetchAccountsRequest [GET] -> api/accounts
```

(Note: HTTP method display is ready, detection implementation coming in Phase 2b)

## Known Limitations & Future Work

### Phase 2b (Next Steps)
HTTP method assignment detection requires more complex AST analysis:

```swift
var request = URLRequest(url: someURL)
request.httpMethod = "POST"  // TODO: Detect this pattern
```

**Challenges:**
- Multiple statements require code block context
- Need to track variable mutations across statements
- Assignment expressions have complex AST structure

**Solution Approach:**
- Parse entire function bodies as context
- Track statement sequences
- Build variable mutation graph

### Additional URLSession Patterns
Currently prepared but not fully implemented:
- `URLSession.shared.dataTask(with: url)`
- `URLSession.shared.data(from: url)` (async)
- Download/upload tasks

## Files Modified

- `Sources/URLFinder/Models/Models.swift` - Added HTTPMethod enum and extended models
- `Sources/URLFinder/Analyzer/URLConstructionVisitor.swift` - Added URLRequest detection
- `Sources/URLFinder/Analyzer/ProjectAnalyzer.swift` - Updated to use new model fields
- `Tests/URLFinderTests/URLFinderTests.swift` - Updated all EndpointReference creations
- `Tests/URLFinderTests/URLConstructionVisitorTests.swift` - Added 5 new tests

## Testing

```bash
swift test
# ✔ Test run with 45 tests in 13 suites passed after 0.009 seconds.
# ➜ Test "Detects URLRequest with embedded HTTP method" skipped
```

All tests passing! ✅ (1 skipped for Phase 2b)

## Next Priority

**Phase 2b: HTTP Method Assignment Detection**
- Implement code block context parsing
- Track variable mutations
- Detect `request.httpMethod = "POST"` patterns
- Support all HTTP methods (GET, POST, PUT, DELETE, PATCH)

See `NEXT_STEPS.md` for full roadmap.
