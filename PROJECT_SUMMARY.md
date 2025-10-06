# Project Summary: swift-url-finder

## Overview

A sophisticated command-line tool for analyzing Xcode projects to discover and track URL endpoint constructions using Apple's IndexStoreDB.

## Key Features

✅ **Interactive Index Store Discovery**
- Automatically scans Xcode's DerivedData folder
- Lists all available index stores with metadata
- Prompts user to select from available options
- Shows last build time and file counts

✅ **Endpoint Search**
- Find specific endpoints by path
- Shows file location and line numbers
- Tracks URL construction patterns
- Follows `appendingPathComponent()` chains

✅ **Comprehensive Reporting**
- Generate full endpoint reports
- Multiple output formats (text, JSON, markdown)
- Maps endpoints to source locations
- Tracks base URLs and path transformations

## Architecture

### Project Structure

```
swift-url-finder/
├── Package.swift                    # Swift Package Manager configuration
├── README.md                        # Full documentation
├── QUICKSTART.md                    # Quick start guide
├── find-index-store.sh             # Helper script for finding index stores
│
├── Sources/swift-url-finder/
│   ├── endpoint_finder.swift       # Main entry point & CLI configuration
│   │
│   ├── Commands/                   # CLI command implementations
│   │   ├── ListIndexStores.swift  # List available index stores
│   │   ├── FindEndpoint.swift     # Search for specific endpoints
│   │   └── GenerateReport.swift   # Generate comprehensive reports
│   │
│   ├── Discovery/                  # Index store discovery
│   │   └── IndexStoreDiscovery.swift  # Scans DerivedData for indexes
│   │
│   ├── Analyzer/                   # Core analysis engine
│   │   ├── ProjectAnalyzer.swift  # Main analyzer using IndexStoreDB
│   │   └── URLConstructionVisitor.swift  # SwiftSyntax visitor for parsing
│   │
│   ├── Models/                     # Data models
│   │   └── Models.swift           # EndpointReference, URLDeclaration, etc.
│   │
│   └── Formatters/                 # Output formatting
│       └── ReportFormatter.swift  # Text, JSON, Markdown formatters
│
└── Tests/
    └── swift-url-finderTests/
        └── endpoint_finderTests.swift
```

### Core Components

#### 1. IndexStoreDiscovery
- Scans `~/Library/Developer/Xcode/DerivedData`
- Finds all `Index.noindex/DataStore` directories
- Extracts project metadata (name, last modified, file count)
- Provides interactive selection UI

#### 2. ProjectAnalyzer (IndexStoreAnalyzer)
- Loads IndexStoreDB from DerivedData
- Queries symbols matching URL patterns
- Uses SwiftSyntax to parse source files
- Tracks URL construction chains
- Generates endpoint references

#### 3. URLConstructionVisitor
- SwiftSyntax visitor pattern
- Walks syntax tree to find URL declarations
- Extracts `appendingPathComponent()` calls
- Builds path component chains
- Maps to source locations

#### 4. ReportFormatter
- Formats endpoint data for output
- Supports text, JSON, and markdown
- Provides human-readable summaries
- Generates structured data for automation

### Data Flow

```
1. User runs command
   ↓
2. IndexStoreDiscovery scans DerivedData
   ↓
3. User selects index store (or provided explicitly)
   ↓
4. IndexStoreAnalyzer loads IndexStoreDB
   ↓
5. Query for URL-related symbols
   ↓
6. For each symbol:
   - Parse source file with SwiftSyntax
   - Extract URL construction pattern
   - Track path components
   - Map to source location
   ↓
7. Build EndpointReference collection
   ↓
8. Format and output results
```

## Technical Details

### Dependencies

- **swift-argument-parser** (1.3.0+): CLI parsing and command structure
- **indexstore-db** (main branch): Symbol database querying
- **swift-syntax** (510.0.0+): Source code parsing and AST traversal

### Requirements

- Swift 6.2+
- macOS 13.0+
- Xcode (for project indexing)

### URL Detection Strategy

The tool identifies URL symbols by:
1. Symbol kind (property, variable)
2. Name pattern (contains "url" or "endpoint")
3. Type inference from IndexStoreDB

### Path Construction Tracking

Tracks patterns like:
```swift
private lazy var enableResourceURL = baseURL
    .appendingPathComponent("accounts")
    .appendingPathComponent("activate")
```

Extracts:
- Base URL: `baseURL`
- Path components: `["accounts", "activate"]`
- Full path: `"resources/enable"`
- Source location: `file:line:column`

## Usage Patterns

### 1. Interactive Mode (Recommended)
```bash
swift-url-finder find --project ~/MyApp --endpoint "accounts"
# Tool prompts for index store selection
```

### 2. Explicit Mode
```bash
swift-url-finder find \
  --project ~/MyApp \
  --index-store ~/Library/.../DataStore \
  --endpoint "accounts"
```

### 3. List Index Stores
```bash
swift-url-finder list [--verbose]
```

### 4. Generate Reports
```bash
swift-url-finder report \
  --project ~/MyApp \
  --format markdown \
  --output ENDPOINTS.md
```

## Example Use Cases

### 1. API Endpoint Discovery
Find all endpoints in a backend service to document the API surface.

### 2. Endpoint Refactoring
Before changing an endpoint path, find all references to ensure complete migration.

### 3. Security Audits
Generate a report of all API endpoints for security review.

### 4. Documentation Generation
Automatically generate API documentation from code.

### 5. CI/CD Integration
Track endpoint changes across commits using JSON output.

## Future Enhancements

Potential improvements:
- [ ] Support for URLRequest and URLSession patterns
- [ ] Detect query parameters and headers
- [ ] Cross-reference with OpenAPI specs
- [ ] Git integration to track endpoint changes
- [ ] Support for other URL construction patterns
- [ ] Network layer framework detection (Alamofire, etc.)
- [ ] GraphQL endpoint detection
- [ ] REST vs GraphQL classification

## Development Notes

### Building
```bash
swift build -c release
```

### Testing
```bash
swift test
```

### Installing
```bash
swift build -c release
cp .build/release/swift-url-finder /usr/local/bin/
```

## Contributing

When adding features:
1. Update models in `Models.swift`
2. Extend `ProjectAnalyzer` for new analysis
3. Add output formatting to `ReportFormatter`
4. Update documentation in README.md

## License

Uses open-source dependencies from Apple and SwiftLang.
