# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-10-06

### Changed
- **BREAKING**: Renamed project from `endpoint-finder` to `swift-url-finder` to follow Swift community naming conventions
  - Executable name changed from `endpoint-finder` to `swift-url-finder`
  - Package name changed to `swift-url-finder`
  - Module name changed to `swift_url_finder`
  - All documentation updated to reflect new name

### Migration Guide

If you had the old version installed:

1. Remove old executable:
   ```bash
   rm /usr/local/bin/endpoint-finder  # or wherever you installed it
   ```

2. Build new version:
   ```bash
   swift build -c release
   ```

3. Update any scripts that reference `endpoint-finder` to use `swift-url-finder`:
   ```bash
   # Old
   endpoint-finder find --project ~/MyApp --endpoint "accounts"
   
   # New
   swift-url-finder find --project ~/MyApp --endpoint "accounts"
   ```

4. Update PATH if you had it configured:
   ```bash
   # Old
   export PATH="$PATH:/path/to/endpoint-finder/.build/release"
   
   # New
   export PATH="$PATH:/path/to/swift-url-finder/.build/release"
   ```

### Initial Features

- Interactive index store discovery from Xcode DerivedData
- Smart endpoint search using IndexStoreDB
- Comprehensive reporting with multiple output formats (text, JSON, markdown)
- Three subcommands:
  - `list`: List all available index stores
  - `find`: Find specific endpoints in a project
  - `report`: Generate comprehensive endpoint reports
- Support for tracking URL construction through `appendingPathComponent()` chains
- Verbose mode for detailed analysis output
