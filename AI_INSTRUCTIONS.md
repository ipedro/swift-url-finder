# AI Instructions for swift-url-finder

## Project Overview

**swift-url-finder** is a sophisticated command-line tool that analyzes Xcode projects to discover and track URL endpoint constructions using Apple's IndexStoreDB. It provides developers with the ability to find where specific endpoints are used in their codebase and generate comprehensive reports of all URL endpoints in a project.

## Core Purpose

The tool solves a specific problem in iOS/macOS development: tracking API endpoints across large codebases. It uses Xcode's symbol index database (not just AST parsing) to find URL declarations and traces how they're constructed through chained `appendingPathComponent()` calls.

### Real-World Use Case

Given code like this:
```swift
public class ActivationService {
    private lazy var baseURL = backendService.apiV1BaseURL
        .appendingPathComponent("api/v1/services/")
    
    private lazy var enableResourceURL = baseURL
        .appendingPathComponent("accounts")
        .appendingPathComponent("activate")
}
```

The tool can:
1. Find all references to `resources/enable` endpoint
2. Show exactly where it's declared (`ActivationService.swift:23`)
3. Track the full path construction chain
4. Generate reports mapping all endpoints to source locations

## Architecture

### Technology Stack

- **Swift 6.2** - Modern Swift with strict concurrency
- **IndexStoreDB** - Apple's library for querying Xcode's symbol index
- **SwiftSyntax** - For parsing Swift source code and extracting URL patterns
- **ArgumentParser** - For clean CLI interface

### Directory Structure

```
swift-url-finder/
├── Package.swift                    # SPM configuration (target: URLFinder)
├── Sources/URLFinder/              # Main target (note: different from package name)
│   ├── main.swift                  # Entry point with @main
│   ├── Commands/                   # CLI subcommands
│   │   ├── ListIndexStores.swift  # List available index stores
│   │   ├── FindEndpoint.swift     # Search for specific endpoints
│   │   └── GenerateReport.swift   # Generate comprehensive reports
│   ├── Discovery/                  # Index store discovery
│   │   └── IndexStoreDiscovery.swift
│   ├── Analyzer/                   # Core analysis engine
│   │   ├── ProjectAnalyzer.swift  # Uses IndexStoreDB
│   │   └── URLConstructionVisitor.swift  # SwiftSyntax visitor
│   ├── Models/                     # Data models
│   │   └── Models.swift
│   └── Formatters/                 # Output formatting
│       └── ReportFormatter.swift
└── Tests/URLFinderTests/           # Test target
    ├── URLFinderTests.swift        # Core tests
    └── URLConstructionVisitorTests.swift
```

### Naming Conventions

**CRITICAL**: The project uses different names at different levels:
- **Package name**: `swift-url-finder` (follows Swift community conventions)
- **Executable name**: `swift-url-finder` (CLI command)
- **Target name**: `URLFinder` (no hyphens, follows Swift module naming)
- **Test target**: `URLFinderTests`

This is intentional and correct. Don't "fix" this by making them all match.

## Key Components

### 1. IndexStoreDiscovery (Discovery Layer)

**Purpose**: Automatically discovers available index stores from Xcode's DerivedData.

**Key Features**:
- Scans `~/Library/Developer/Xcode/DerivedData`
- Extracts project names from directory structure
- Validates index stores have actual data
- Provides interactive selection UI
- Handles custom DerivedData paths

**Usage Pattern**:
```swift
let discovery = IndexStoreDiscovery()
let stores = try discovery.discoverIndexStores()
let selected = try IndexStoreDiscovery.promptForIndexStore(stores: stores)
```

**Important Notes**:
- Default initialization uses standard DerivedData path
- Custom path constructor for non-standard setups
- Throws `DiscoveryError` for various failure cases
- Returns empty array if no valid indexes found (not an error)

### 2. IndexStoreAnalyzer (Core Analysis)

**Purpose**: Uses the IndexStore wrapper library to query Xcode's symbol index and analyze URL construction patterns.

**Key Responsibilities**:
1. Initialize IndexStore from project directory (auto-discovers index store location)
2. Query for URL-related symbols (properties/variables containing "url" or "endpoint")
3. Get symbol occurrences and definitions
4. Parse source files with SwiftSyntax to extract URL construction
5. Build endpoint references with full path information

**Actor Isolation**: This is an `actor` to ensure thread-safe access to mutable state.

**Initialization**:
```swift
// Primary usage - auto-discovers index store from project
let analyzer = try IndexStoreAnalyzer(
    projectPath: projectURL,
    verbose: true
)

// Advanced - override index store location
let analyzer = try IndexStoreAnalyzer(
    projectPath: projectURL,
    indexStorePath: customIndexURL,
    verbose: true
)
```

**Design Philosophy**:
- Project directory is the primary input (aligns with IndexStore wrapper's design)
- Index store location is auto-discovered from `.build/` or DerivedData
- Optional index store override for advanced use cases
- IndexStore.Configuration handles path resolution automatically

**Critical Implementation Details**:
- Uses IndexStore wrapper library (CheekyGhost-Labs/IndexStore v3.0)
- IndexStore.Configuration handles libIndexStore path resolution
- Auto-discovers index store from project directory
- Symbol querying through IndexStore wrapper
- Symbol kinds to look for: `.instanceProperty`, `.classProperty`, `.staticProperty`, `.variable`

**SwiftSyntax Integration**:
```swift
let sourceFile = Parser.parse(source: sourceCode)
let visitor = URLConstructionVisitor(targetSymbol: symbolName, filePath: filePath)
visitor.walk(sourceFile)
```

### 3. URLConstructionVisitor (Syntax Analysis)

**Purpose**: Walks SwiftSyntax AST to extract URL construction patterns.

**Pattern Recognition**:
- Identifies variable declarations for target symbols
- Extracts base URL references
- Follows chained `.appendingPathComponent()` calls
- Captures string literal arguments
- Tracks source locations for each component

**Key Method**: `visit(_ node: VariableDeclSyntax)`

**Extraction Logic**:
1. Find variable declaration matching target symbol
2. Get initializer expression
3. Recursively process function calls
4. Check if method is `appendingPathComponent`
5. Extract string literal argument
6. Track source location using `SourceLocationConverter`

**Important**: Base URL extraction may not always work due to AST complexity. The critical part is extracting path components correctly.

### 4. Commands (CLI Interface)

Each command is a `ParsableCommand` or `AsyncParsableCommand`:

**ListIndexStores**: 
- Simple, synchronous
- Scans and displays available indexes
- Useful for users to see what's available

**FindEndpoint**:
- Primary input: `--project` (path to Xcode project/workspace directory)
- Required: `--endpoint` (path to search for)
- Optional: `--index-store` (override auto-discovery)
- Interactive mode prompts if no project provided
- Async (analysis can take time)
- Returns file:line references

**GenerateReport**:
- Primary input: `--project` (path to Xcode project/workspace directory)
- Optional: `--index-store` (override auto-discovery)
- Supports multiple output formats (text, JSON, markdown)
- Can write to file or stdout
- Interactive mode prompts if no project provided
- Async

**Interactive Mode**:
All commands check if `--project` is provided. If not:
1. Run `IndexStoreDiscovery().discoverIndexStores()`
2. Call `IndexStoreDiscovery.promptForIndexStore()`
3. Infer project path from selected index store (going up directory tree)
4. Use inferred project path and optionally the custom index store

This makes the tool user-friendly without requiring manual path hunting, while still aligning with the IndexStore wrapper's project-directory-first design.

### 5. ReportFormatter (Output)

**Formats**: Text, JSON, Markdown

**Design**: Single `format(report:)` method that switches on format type.

**Text Format**:
- Human-readable
- Shows hierarchy and organization
- Good for terminal output

**JSON Format**:
- Machine-readable
- Uses `JSONEncoder` with pretty printing
- For CI/CD and automation

**Markdown Format**:
- Documentation-friendly
- Tables for references
- Good for including in repos

## Models

### EndpointReference
Complete information about where an endpoint is used:
- `file`: Absolute path
- `line`, `column`: Source location
- `symbolName`: Variable/property name
- `baseURL`: What it's based on
- `pathComponents`: Array of path segments
- `fullPath`: Computed full endpoint path

### URLDeclaration
Internal representation during analysis:
- Tracks symbol name and location
- Accumulates `PathComponent` array
- Computes `fullPath` from components

### EndpointReport
Final report structure:
- Project metadata
- Analysis statistics
- Array of `EndpointInfo`
- Timestamp

### PathComponent
Individual segment in URL construction:
- `value`: The string (e.g., "accounts")
- `file`, `line`: Where it was added

## Testing Strategy

### Current Coverage: 26 Tests, 100% Pass Rate

**Test Organization**:
1. **Models** - Data structure behavior
2. **Discovery** - Index store finding logic
3. **Formatters** - Output generation
4. **Analyzers** - SwiftSyntax parsing

**Test Principles**:
- Fast (milliseconds)
- Isolated (no dependencies between tests)
- Deterministic (consistent results)
- Edge cases covered

**Not Tested** (intentionally):
- CLI commands (require integration tests)
- IndexStoreDB integration (needs real index store)
- Full end-to-end workflows

**When Adding Features**:
1. Write tests first (TDD)
2. Add to appropriate test suite
3. Use descriptive test names
4. Test both success and failure paths
5. Update TEST_COVERAGE.md

## Common Development Tasks

### Adding a New Output Format

1. Add case to `OutputFormat` enum in `GenerateReport.swift`
2. Add format method in `ReportFormatter.swift`
3. Add tests in `URLFinderTests.swift`
4. Update documentation

### Adding New URL Pattern Detection

1. Update `isURLSymbol()` in `ProjectAnalyzer.swift`
2. Add tests for the new pattern
3. Consider if `URLConstructionVisitor` needs changes
4. Update EXAMPLES.md with sample

### Improving Base URL Extraction

The current implementation sometimes fails to extract base URLs. To improve:

1. Study SwiftSyntax AST for your specific patterns
2. Update `extractFromMemberAccess()` in `URLConstructionVisitor.swift`
3. Add tests with real-world code examples
4. Consider handling property wrappers (`@State`, etc.)

### Adding New Command

1. Create new file in `Sources/URLFinder/Commands/`
2. Implement `AsyncParsableCommand` protocol
3. Add to `subcommands` array in `main.swift`
4. Follow the pattern: check for index store, prompt if needed
5. Add documentation to README.md

## Build and Run

### Development Build
```bash
swift build
.build/debug/swift-url-finder --help
```

### Release Build
```bash
swift build -c release
.build/release/swift-url-finder --help
```

### Running Tests
```bash
swift test              # All tests
swift test --verbose    # Detailed output
```

### Installation
```bash
swift build -c release
cp .build/release/swift-url-finder /usr/local/bin/
```

## Critical Implementation Notes

### Package.swift Configuration

**IMPORTANT**: The target includes a critical swift setting:
```swift
swiftSettings: [
    .unsafeFlags(["-parse-as-library"])
]
```

This is required because we use `@main` attribute. Without it, the build fails with:
```
error: 'main' attribute cannot be used in a module that contains top-level code
```

### IndexStoreDB Initialization

Correct initialization pattern:
```swift
indexStoreDB = try IndexStoreDB(
    storePath: indexStorePath.path,
    databasePath: NSTemporaryDirectory() + "/endpoint-finder-index.db",
    library: IndexStoreLibrary(dylibPath: libPath.path)
)

// Wait for initialization
try await Task.sleep(nanoseconds: 500_000_000)
```

The sleep is necessary because IndexStoreDB loads asynchronously.

### Symbol Querying

**Per-file approach** (current):
```swift
for filePath in swiftFiles {
    let fileSymbols = indexStoreDB.symbols(inFilePath: filePath.path)
    symbols.append(contentsOf: fileSymbols)
}
```

This is more reliable than trying to query all symbols at once.

### Actor Isolation

`IndexStoreAnalyzer` is an actor. Methods must be called with `await`:
```swift
try await analyzer.analyzeProject()
let references = await analyzer.findEndpointReferences(endpoint: endpoint)
let report = await analyzer.generateReport()
```

### Source Location Conversion

Getting line numbers from SwiftSyntax nodes:
```swift
let converter = SourceLocationConverter(fileName: filePath, tree: node.root)
let position = node.positionAfterSkippingLeadingTrivia
let location = converter.location(for: position)
let line = location.line  // Int, not Optional
```

## User Experience Design

### Interactive Mode Philosophy

The tool prioritizes user experience:
1. **No required paths**: Users don't need to know DerivedData structure
2. **Auto-discovery**: Scans and shows available options
3. **Clear prompts**: "Select an index store (1-3) or 'q' to quit"
4. **Helpful errors**: Suggests solutions when things go wrong
5. **Verbose mode**: Available for debugging

### Error Messages

Good error messages explain:
- What went wrong
- Why it might have happened
- What the user should do

Example:
```
❌ No index stores found in DerivedData.
   Build your project in Xcode first to generate the index.
```

### Progress Feedback

For long operations:
```
🔍 Searching for endpoint: resources/enable
📁 Project: ~/MyApp
📇 Index Store: ...

✅ Found 2 reference(s):
```

Use emoji sparingly but effectively for visual cues.

## Performance Considerations

### Index Store Size

Index stores can be large (100MB+). The tool:
- Only loads what's needed
- Doesn't keep everything in memory
- Uses streaming/iteration where possible

### Large Projects

For projects with thousands of files:
- Show progress during analysis
- Consider adding `--max-files` option
- Implement caching for repeated queries

### Swift Compilation

Building the tool requires downloading IndexStoreDB and SwiftSyntax.
First build may take 2-3 minutes. Subsequent builds are fast.

## Future Enhancements

### Planned Features

1. **URLRequest Support**: Detect endpoints in URLRequest construction
2. **Query Parameters**: Track query string parameters
3. **HTTP Methods**: Identify GET/POST/etc. usage
4. **OpenAPI Export**: Generate OpenAPI/Swagger specs
5. **Git Integration**: Track endpoint changes across commits
6. **Network Frameworks**: Support Alamofire, Moya, etc.

### Architectural Improvements

1. **Caching**: Cache analysis results for large projects
2. **Incremental Analysis**: Only re-analyze changed files
3. **Plugin System**: Allow custom URL pattern detectors
4. **Language Server**: Integrate as LSP for IDE support

## Troubleshooting

### "Cannot find IndexStoreDB"

The index store path must point to `DataStore` directory:
```
~/Library/Developer/Xcode/DerivedData/<Project-ID>/Index.noindex/DataStore
```

### "No symbols found"

1. Build project in Xcode
2. Wait for indexing to complete
3. Verify index store exists and has files

### "@main attribute" error

Ensure Package.swift has:
```swift
swiftSettings: [.unsafeFlags(["-parse-as-library"])]
```

### Tests failing

1. Clean build: `swift package clean`
2. Resolve packages: `swift package resolve`
3. Run tests: `swift test`

## Documentation

### Keep Updated

When making changes, update:
1. **README.md** - User-facing documentation
2. **QUICKSTART.md** - Getting started guide
3. **EXAMPLES.md** - Usage examples
4. **PROJECT_SUMMARY.md** - Technical overview
5. **TEST_COVERAGE.md** - After adding tests
6. **CHANGELOG.md** - For version releases
7. **This file** - AI instructions

### Writing Style

- Clear and concise
- Code examples for complex concepts
- Step-by-step for workflows
- Emoji for visual cues (but don't overuse)
- Real-world examples

## Git Workflow

### Commit Messages

Format:
```
<Short summary>

<Detailed explanation>
- Bullet points for changes
- What was added/modified
- Why changes were made
```

### Before Committing

1. Run tests: `swift test`
2. Check for errors: Review VSCode problems
3. Update documentation if needed
4. Write clear commit message

## Code Style

### Swift Style

- Use Swift 6 features
- Prefer `let` over `var`
- Use meaningful names
- Document public APIs
- Use `// MARK:` for organization

### Naming

- `camelCase` for variables/functions
- `PascalCase` for types
- Descriptive names (not `temp`, `data`, `x`)
- Verb phrases for functions (`analyzeProject`, `findEndpoints`)

### Error Handling

- Use `throws` for recoverable errors
- Custom error types for domain errors
- Provide helpful error messages
- Don't swallow errors silently

## API Design Principles

### Progressive Disclosure

- Simple things should be simple
- Complex things should be possible
- Sensible defaults
- Optional configuration

### Example

```swift
// Simple: uses defaults
let discovery = IndexStoreDiscovery()

// Advanced: custom path
let discovery = IndexStoreDiscovery(customPath: customURL)
```

### Async/Await

Use async/await consistently:
- Long-running operations are `async`
- CPU-bound work can be synchronous
- Use `actor` for mutable state
- Avoid callbacks

## Dependencies

### Current Dependencies

1. **swift-argument-parser** (1.3.0+)
   - Stable, well-maintained
   - Used for CLI parsing

2. **indexstore-db** (main branch)
   - Maintained by Swift team
   - Core dependency, can't be replaced

3. **swift-syntax** (510.0.0+)
   - Maintained by Swift team
   - Version-locked to Swift version

### Dependency Updates

Check periodically for updates:
```bash
swift package update
```

Test thoroughly after updating dependencies.

## Community Guidelines

### Issue Reports

Encourage users to provide:
- Swift version
- Xcode version
- Sample code that reproduces issue
- Index store path (if applicable)

### Pull Requests

Welcome contributions that:
- Include tests
- Update documentation
- Follow existing code style
- Have clear commit messages

## Conclusion

This tool demonstrates several advanced Swift concepts:
- IndexStoreDB integration
- SwiftSyntax AST walking
- Actor-based concurrency
- CLI design with ArgumentParser
- Comprehensive testing

The codebase is well-structured, tested, and documented. When making changes, maintain these standards and keep the user experience as the top priority.

Remember: The goal is to make it easy for developers to understand their API surface and track endpoint usage across their codebase.
