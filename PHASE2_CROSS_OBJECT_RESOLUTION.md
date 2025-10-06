# Phase 2: Cross-Object Property Resolution

## Status: Planning

## Current Achievement (Phase 1)
✅ **Same-file variable resolution** - Successfully implemented and tested!

The tool can now trace URL construction through chained variable references within the same file:

```swift
lazy var baseURL = service.apiV1BaseURL
lazy var registrationURL = baseURL.appendingPathComponent("registration")  
lazy var featuresURL = registrationURL.appendingPathComponent("features")
// ✅ Tool correctly resolves: api/features
```

**Validated on example-ios production codebase:**
- `api/features` → Found 1 reference
- `api/user/email` → Found 1 reference (3-level chain)
- `api/auth` → Found 5 references

## Remaining Challenge (Phase 2)
❌ **Cross-object property access** - Not yet implemented

The tool cannot currently resolve properties accessed through other objects:

```swift
// In NeonBackendService.swift:
public var apiV2BaseURL: URL { apiURL.appendingPathComponent("v2") }

// In AccountResetPinService+Live.swift:
let baseUrl = backendService.apiV2BaseURL  // ❌ Can't resolve this
    .appendingPathComponent("auth")
    .appendingPathComponent("account")
```

**Example that doesn't work:**
- `api/v2/api/auth` → Returns 0 results
- Reason: `backendService.apiV2BaseURL` crosses object boundaries

## Phase 2 Implementation Plan

### Goal
Enable the tool to resolve property access across objects, tracing through:
1. Member access expressions (`backendService.apiV2BaseURL`)
2. Type resolution (what is `backendService`?)
3. Cross-file property lookup
4. Computed property evaluation

### Technical Approach

#### Option A: IndexStore-Based Resolution (Recommended)
Use the IndexStore to resolve cross-file references:

```swift
// When encountering: backendService.apiV2BaseURL
// 1. Use IndexStore to find the type of `backendService`
// 2. Query IndexStore for `apiV2BaseURL` property in that type
// 3. Load that file and extract its construction
// 4. Recursively resolve any dependencies
```

**Advantages:**
- Leverages existing index data
- Fast lookups
- No need to parse entire project
- Handles inheritance and protocols

**Disadvantages:**
- More complex IndexStore queries needed
- Need to handle computed properties
- May require caching to avoid repeated parsing

#### Option B: Symbol Graph Approach
Build a dependency graph of all URL-related symbols first:

```swift
// 1. Find all URL properties across all files
// 2. Build dependency graph (which symbols depend on which)
// 3. Topological sort to resolve in correct order
// 4. Cache resolved values
```

**Advantages:**
- Clear separation of concerns
- Easy to visualize dependencies
- Natural caching strategy

**Disadvantages:**
- Requires parsing many files upfront
- Memory intensive for large projects
- Complex cycle detection needed

### Implementation Steps

#### Step 1: Enhance Member Access Detection
Update `URLConstructionVisitor` to detect and store member access patterns:

```swift
// In extractFromMemberAccess:
if let base = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
    // Store: base.baseName.text (e.g., "backendService")
    // Store: memberAccess.declName.baseName.text (e.g., "apiV2BaseURL")
    unresolvedReferences.append((object: base, property: property))
}
```

#### Step 2: Add Type Resolution
Use IndexStore to find the type of a variable:

```swift
func resolveType(of variableName: String, in file: String) async throws -> String? {
    // Query IndexStore for variable's type information
    // Return the type name (e.g., "NeonBackendService")
}
```

#### Step 3: Cross-File Property Lookup
Query IndexStore to find where a property is defined:

```swift
func findPropertyDefinition(
    propertyName: String,
    inType typeName: String
) async throws -> (file: String, line: Int)? {
    // Use IndexStore to find property definition
    // Return file path and location
}
```

#### Step 4: Recursive Resolution
Implement recursive resolver that handles multiple levels:

```swift
func resolveCrossObjectURL(
    object: String,
    property: String, 
    fromFile: String,
    visited: Set<String> = []
) async throws -> [PathComponent] {
    // 1. Resolve object type
    // 2. Find property definition
    // 3. Parse property's construction
    // 4. Recursively resolve any dependencies
    // 5. Return combined path components
}
```

#### Step 5: Integration
Update `ProjectAnalyzer` to use cross-object resolution:

```swift
// After local resolution, check for unresolved references
if visitor.hasUnresolvedReferences {
    let resolved = try await resolveCrossObjectReferences(
        visitor.unresolvedReferences,
        fromFile: declaration.file
    )
    pathComponents.append(contentsOf: resolved)
}
```

### Testing Strategy

#### Unit Tests
- Test type resolution from IndexStore
- Test property lookup across files
- Test recursive resolution with 2+ levels
- Test cycle detection
- Test inheritance/protocol conformance

#### Integration Tests
Create test fixtures:

```swift
// File1.swift
class Service {
    var baseURL: URL { URL(string: "https://api.com")! }
    var v1URL: URL { baseURL.appendingPathComponent("v1") }
}

// File2.swift
let service = Service()
let authURL = service.v1URL.appendingPathComponent("auth")
// Should resolve to: "v1/auth"
```

#### Real-World Validation
Test on example-ios endpoints:
- `api/v2/api/auth`
- `api/v1/services/accounts`
- Any endpoint using `backendService.apiV2BaseURL`

### Performance Considerations

1. **Caching**: Cache resolved properties to avoid redundant parsing
2. **Lazy evaluation**: Only resolve cross-file references when needed
3. **Parallel resolution**: Resolve independent branches in parallel
4. **Early termination**: Stop at known base URLs (http://, https://)

### Known Edge Cases

1. **Computed properties with complex logic**
   ```swift
   var url: URL {
       if isProduction {
           return productionURL
       } else {
           return stagingURL
       }
   }
   ```
   → May need heuristics or configuration to handle

2. **Dynamic URL construction**
   ```swift
   var url: URL {
       URL(string: "\(baseURL)/\(version)/\(endpoint)")!
   }
   ```
   → May need pattern matching or partial resolution

3. **Protocol extensions**
   ```swift
   extension BackendServiceProtocol {
       var apiV2BaseURL: URL { ... }
   }
   ```
   → Need to handle protocol default implementations

### Success Criteria

Phase 2 will be considered complete when:
- ✅ Can resolve `api/v2/api/auth` endpoint
- ✅ Can trace through 2+ object boundaries
- ✅ Handles computed properties
- ✅ Detects and prevents infinite cycles
- ✅ Performance: < 5 seconds for example-ios project
- ✅ All tests pass (existing + new cross-object tests)

### Timeline Estimate

- **Research & Design**: 2-3 hours
- **Implementation**: 4-6 hours
- **Testing & Validation**: 2-3 hours  
- **Total**: 8-12 hours

## Next Steps

1. ✅ Commit Phase 1 (same-file resolution) - DONE
2. Review this plan with stakeholders
3. Start with Step 1: Enhance member access detection
4. Iteratively implement and test each step
5. Validate on real-world example-ios endpoints

---

**Note**: This document will be updated as Phase 2 progresses. Current focus is on getting stakeholder approval before beginning implementation.
