# Quick Start Guide

## Setup (One-time)

1. **Build the tool:**
   ```bash
   cd /Users/pedro/Developer/swift-url-finder
   swift build -c release
   ```

2. **Add to PATH (optional but recommended):**
   ```bash
   # Add this to your ~/.zshrc
   export PATH="$PATH:/Users/pedro/Developer/swift-url-finder/.build/release"
   
   # Then reload your shell
   source ~/.zshrc
   ```

## Basic Workflow

### Step 1: Prepare Your Xcode Project

Before using the tool, make sure your Xcode project has been indexed:

1. Open your project in Xcode
2. Build the project (⌘B)
3. Wait for "Indexing..." to complete (check the Activity view)

### Step 2: List Available Index Stores

```bash
swift-url-finder list
```

This shows all Xcode projects that have index stores available.

### Step 3: Find Endpoints

**Quick search for a specific endpoint:**

```bash
swift-url-finder find \
  --project ~/Developer/MyApp \
  --endpoint "resources/enable"
```

The tool will:
1. Show you a list of available index stores
2. Ask you to select one
3. Search for the endpoint
4. Display all locations where it's used

**Example output:**
```
🔍 Searching for endpoint: resources/enable
📁 Project: ~/Developer/MyApp

📇 Available Index Stores:

[1] MyApp
    Last built: 2 hours ago
    Index files: 15234
    Path: ~/Library/.../MyApp-abc123/Index.noindex/DataStore

Select an index store (1-1) or 'q' to quit: 1

✅ Selected: MyApp

✅ Found 2 reference(s):

~/Developer/MyApp/Services/ActivationService.swift:15
~/Developer/MyApp/Services/ActivationService.swift:19
```

### Step 4: Generate a Full Report

```bash
swift-url-finder report \
  --project ~/Developer/MyApp \
  --format markdown \
  --output ENDPOINTS.md
```

This creates a comprehensive report of all endpoints in your project.

## Advanced Usage

### Skip Interactive Prompt

If you want to specify the project directly:

```bash
swift-url-finder find \
  --project ~/Developer/MyApp \
  --endpoint "resources/enable"
```

### Override Index Store Location (Advanced)

If you need to use a custom index store location:

```bash
swift-url-finder find \
  --project ~/Developer/MyApp \
  --index-store ~/Library/Developer/Xcode/DerivedData/MyApp-abc123/Index.noindex/DataStore \
  --endpoint "resources/enable"
```

### Verbose Output

See detailed information during analysis:

```bash
swift-url-finder find \
  --project ~/Developer/MyApp \
  --endpoint "accounts" \
  --verbose
```

### Different Output Formats

**JSON (for CI/CD or programmatic use):**
```bash
swift-url-finder report \
  --project ~/Developer/MyApp \
  --format json \
  --output endpoints.json
```

**Markdown (for documentation):**
```bash
swift-url-finder report \
  --project ~/Developer/MyApp \
  --format markdown \
  --output ENDPOINTS.md
```

**Text (human-readable, default):**
```bash
swift-url-finder report \
  --project ~/Developer/MyApp \
  --format text
```

## Common Scenarios

### 1. Finding Where an Endpoint is Used

```bash
swift-url-finder find \
  --project ~/Developer/MyApp \
  --endpoint "user/profile"
```

### 2. Documenting All API Endpoints

```bash
swift-url-finder report \
  --project ~/Developer/MyApp \
  --format markdown \
  --output docs/API_ENDPOINTS.md
```

### 3. CI/CD Integration

```bash
# Generate JSON report for automated processing
swift-url-finder report \
  --project $PROJECT_PATH \
  --index-store $INDEX_STORE_PATH \
  --format json \
  --output endpoints.json

# Parse with jq or similar tool
jq '.totalEndpoints' endpoints.json
```

## Troubleshooting

### "No index stores found"

**Solution:** Build your project in Xcode first.

### "No references found"

**Possible causes:**
- The endpoint path doesn't match exactly
- The URL property doesn't contain "url" or "endpoint" in its name
- Try a partial match (e.g., just "accounts" instead of "resources/enable")

### "Cannot find IndexStoreDB"

**Solution:** Make sure you've built the project with `swift build`

## Tips

1. **Keep index up-to-date**: Rebuild your Xcode project after making changes
2. **Use partial searches**: Search for "accounts" to find all account-related endpoints
3. **Save reports**: Use `--output` to save reports for comparison over time
4. **Verbose mode**: Use `--verbose` when debugging to see what the tool is doing
