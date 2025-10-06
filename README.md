# swift-url-finder

A command-line tool that analyzes Xcode projects to find and track URL endpoint constructions using Swift's IndexStoreDB.

## Overview

This tool helps you:
1. **Find specific endpoints**: Search for where a specific URL path is used in your codebase
2. **Generate reports**: Create comprehensive reports of all URL endpoints in your project

It uses Apple's IndexStoreDB to query the symbol index database that Xcode builds, allowing it to track how URLs are constructed through property declarations and `appendingPathComponent()` calls.

## Building

```bash
swift build -c release
```

The executable will be at `.build/release/swift-url-finder`.

## Prerequisites

Before using this tool, you need:

1. **An Xcode project with an up-to-date index**
   - Build your project in Xcode to ensure the index is current
   - The index is stored in DerivedData at `~/Library/Developer/Xcode/DerivedData/<ProjectName-ID>/Index.noindex/DataStore`

**That's it!** The tool automatically discovers the index store from your project directory—simply point it to your Xcode project folder.

## Usage

### List Available Index Stores

The easiest way to start is by listing all available index stores:

```bash
swift-url-finder list
```

This will show all Xcode projects that have been indexed:

```
🔍 Scanning for index stores in DerivedData...

📇 Found 3 index store(s):

[1] MyApp
    Last built: Jan 2, 2024 at 3:45 PM
    (2 hours ago)
    Index files: 15234

[2] TestProject
    Last built: Dec 28, 2023 at 10:30 AM
    (5 days ago)
    Index files: 892

💡 Tip: Use --verbose to see full paths
```

### Find a Specific Endpoint

Search for all references to a specific endpoint path:

**Interactive mode** (recommended - will prompt you to select a project):

```bash
swift-url-finder find --endpoint "resources/enable"
```

**Explicit mode** (specify your project path):

```bash
swift-url-finder find \
  --project /path/to/YourProject \
  --endpoint "resources/enable"
```

**Advanced: Override index store location** (usually not needed):

```bash
swift-url-finder find \
  --project /path/to/YourProject \
  --index-store ~/Library/Developer/Xcode/DerivedData/YourProject-abc123/Index.noindex/DataStore \
  --endpoint "resources/enable"
```

Output:
```
🔍 Searching for endpoint: resources/enable
� Project: /path/to/YourProject

✅ Found 2 reference(s):

/path/to/ActivationService.swift:15
/path/to/ActivationService.swift:19
```

With verbose output:
```bash
swift-url-finder find \
  --project /path/to/YourProject \
  --endpoint "resources/enable" \
  --verbose
```

### Generate a Comprehensive Report

Generate a report of all endpoints in the project:

**Interactive mode** (recommended):

```bash
swift-url-finder report
```

The tool will show you a list of available projects to choose from:

```
📇 Available Index Stores:

[1] MyApp
    Last built: 2 hours ago
    Index files: 15234
    Path: ~/Library/Developer/Xcode/DerivedData/MyApp-abc123/Index.noindex/DataStore

[2] TestProject
    Last built: 5 days ago
    Index files: 892
    Path: ~/Library/Developer/Xcode/DerivedData/TestProject-def456/Index.noindex/DataStore

Select an index store (1-2) or 'q' to quit: 
```

**Explicit mode** (specify your project path):

```bash
swift-url-finder report \
  --project /path/to/YourProject
```

**Advanced: Override index store location** (usually not needed):

```bash
swift-url-finder report \
  --project /path/to/YourProject \
  --index-store ~/Library/Developer/Xcode/DerivedData/YourProject-abc123/Index.noindex/DataStore
```

#### Output Formats

**Text (default):**
```bash
swift-url-finder report \
  --project /path/to/YourProject \
  --format text
```

**JSON:**
```bash
swift-url-finder report \
  --project /path/to/YourProject \
  --format json \
  --output endpoints.json
```

**Markdown:**
```bash
swift-url-finder report \
  --project /path/to/YourProject \
  --format markdown \
  --output ENDPOINTS.md
```

## How It Works

### 1. Index Store Analysis

The tool uses `IndexStoreDB` to query the symbol database that Xcode maintains. This gives access to:
- Symbol definitions (properties, variables)
- Symbol references
- Symbol USRs (Unified Symbol Resolutions)

### 2. URL Pattern Detection

The tool identifies URL-related symbols by looking for:
- Property/variable names containing "url" or "endpoint"
- Properties of type `URL`

### 3. Construction Tracing

For each URL symbol found, the tool:
1. Parses the source file using `SwiftSyntax`
2. Identifies the base URL reference
3. Tracks all `appendingPathComponent()` calls
4. Maps the full endpoint path construction

### 4. Reference Tracking

The tool tracks:
- Where each URL is declared
- What base URL it references
- All path components added via `appendingPathComponent()`
- The full constructed path

## Example Output

Given code like:

```swift
public class ActivationService {
    private lazy var baseURL = backendService.apiV1BaseURL
        .appendingPathComponent("api/v1/services/")
    
    private lazy var enableResourceURL = baseURL
        .appendingPathComponent("accounts")
        .appendingPathComponent("activate")
}
```

The tool will identify:
- Symbol: `enableResourceURL`
- Base URL: `baseURL`
- Path components: `["accounts", "activate"]`
- Full path: `resources/enable`
- Location: `ActivationService.swift:5`

## Tips

1. **Keep your index up-to-date**: Build your project in Xcode before running the tool
2. **Use verbose mode**: Add `--verbose` to see detailed progress information
3. **Save reports**: Use `--output` to save reports for later reference
4. **Search patterns**: The endpoint search matches partial paths, so "accounts" will match "resources/enable"

## Troubleshooting

### "Cannot find index store"

Ensure the path points to the `DataStore` directory:
```
~/Library/Developer/Xcode/DerivedData/<Project-ID>/Index.noindex/DataStore
```

### "No symbols found"

- Build your project in Xcode to generate the index
- Ensure you're pointing to the correct DerivedData directory
- Check that your project has been indexed by Xcode

### "No endpoints found"

- The tool looks for properties/variables with "url" or "endpoint" in the name
- Ensure your URL properties follow this naming convention
- Use `--verbose` to see what symbols are being analyzed

## License

This tool uses:
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) for CLI parsing
- [indexstore-db](https://github.com/swiftlang/indexstore-db) for index querying
- [swift-syntax](https://github.com/apple/swift-syntax) for source parsing
