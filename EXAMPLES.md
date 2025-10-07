# Example: What the Tool Detects

## Input Code

Given this Swift code in your Xcode project:

```swift
// ActivationService.swift

import Foundation

public class ActivationService: ActivationServiceType {
    private let backendService: BackendService
    
    // Base URLs
    private lazy var baseURL = backendService.apiV1BaseURL
        .appendingPathComponent("api/v1/services/")
    
    private lazy var baseURLV2 = backendService.apiV2BaseURL
        .appendingPathComponent("api/v1/services/")
    
    // Endpoint URLs
    private lazy var resourcesActivationURL = baseURL
        .appendingPathComponent("accounts")
    
    private lazy var resourcesURL = baseURLV2
        .appendingPathComponent("accounts")
    
    private lazy var enableResourceURL = baseURL
        .appendingPathComponent("accounts")
        .appendingPathComponent("activate")
    
    private lazy var currentResourceStatusURL = baseURL
        .appendingPathComponent("accounts")
        .appendingPathComponent("activations")
        .appendingPathComponent("current")
    
    private lazy var enableCurrentResourceURL = baseURL
        .appendingPathComponent("accounts")
        .appendingPathComponent("current")
        .appendingPathComponent("activate")
    
    private lazy var metricsURL = backendService.apiV1BaseURL
        .appendingPathComponent("api/v1/data/metrics")
    
    private lazy var submissionStatusUrl = backendService.apiV1BaseURL
        .appendingPathComponent("customer/profession/status")
}
```

## Tool Output

### Running `find` command:

```bash
$ swift-url-finder find --project ~/MyApp --endpoint "resources/enable"
```

**Output:**
```
🔍 Searching for endpoint: resources/enable
📁 Project: ~/MyApp

📇 Available Index Stores:

[1] MyApp
    Last built: 5 minutes ago
    Index files: 15234
    Path: ~/Library/Developer/Xcode/DerivedData/MyApp-abc123/Index.noindex/DataStore

Select an index store (1-1) or 'q' to quit: 1

✅ Selected: MyApp

✅ Found 2 reference(s):

~/MyApp/Services/ActivationService.swift:23
~/MyApp/Services/ActivationService.swift:35
```

### Running `find` with verbose:

```bash
$ swift-url-finder find --project ~/MyApp --endpoint "resources/enable" --verbose
```

**Output:**
```
✅ Found 2 reference(s):

~/MyApp/Services/ActivationService.swift:23
  Base URL: baseURL
  Full Path: resources/enable
  Symbol: enableResourceURL
  Transformations: 2

~/MyApp/Services/ActivationService.swift:35
  Base URL: baseURL
  Full Path: accounts/current/activate
  Symbol: enableCurrentResourceURL
  Transformations: 3
```

### Running `report` command:

```bash
$ swift-url-finder report --project ~/MyApp --format text
```

**Output:**
```
================================================================================
ENDPOINT ANALYSIS REPORT
================================================================================

Project: ~/MyApp
Generated: 2024-01-02T15:45:32Z
Files Analyzed: 247
Total Endpoints: 7

================================================================================
ENDPOINTS
================================================================================


[1] api/v1/services/accounts

    Base URL: baseURL
    Path Components: api/v1/services/ → accounts
    Declaration: ActivationService.swift:17
    References: 1
      - ActivationService.swift:17 (resourcesActivationURL)

[2] api/v1/services/accounts

    Base URL: baseURLV2
    Path Components: api/v1/services/ → accounts
    Declaration: ActivationService.swift:20
    References: 1
      - ActivationService.swift:20 (resourcesURL)

[3] api/v1/services/resources/enable

    Base URL: baseURL
    Path Components: api/v1/services/ → accounts → activate
    Declaration: ActivationService.swift:23
    References: 1
      - ActivationService.swift:23 (enableResourceURL)

[4] api/v1/services/resources/status/current

    Base URL: baseURL
    Path Components: api/v1/services/ → accounts → activations → current
    Declaration: ActivationService.swift:27
    References: 1
      - ActivationService.swift:27 (currentResourceStatusURL)

[5] api/v1/services/accounts/current/activate

    Base URL: baseURL
    Path Components: api/v1/services/ → accounts → current → activate
    Declaration: ActivationService.swift:32
    References: 1
      - ActivationService.swift:32 (enableCurrentResourceURL)

[6] api/v1/data/metrics

    Base URL: backendService.apiV1BaseURL
    Path Components: api/v1/data/metrics
    Declaration: ActivationService.swift:37
    References: 1
      - ActivationService.swift:37 (metricsURL)

[7] customer/profession/status

    Base URL: backendService.apiV1BaseURL
    Path Components: customer/profession/status
    Declaration: ActivationService.swift:40
    References: 1
      - ActivationService.swift:40 (submissionStatusUrl)
```

### Running `report` with markdown:

```bash
$ swift-url-finder report --project ~/MyApp --format markdown --output ENDPOINTS.md
```

**Generated ENDPOINTS.md:**

```markdown
# Endpoint Analysis Report

**Project:** `~/MyApp`  
**Generated:** 2024-01-02T15:45:32Z  
**Files Analyzed:** 247  
**Total Endpoints:** 7

## Endpoints

### 1. `api/v1/services/accounts`

**Base URL:** `baseURL`

**Path Components:**

- `api/v1/services/`
- `accounts`

**Declaration:** `ActivationService.swift:17`

**References:** 1

| File | Line | Symbol |
|------|------|--------|
| `ActivationService.swift` | 17 | `resourcesActivationURL` |

### 2. `api/v1/services/resources/enable`

**Base URL:** `baseURL`

**Path Components:**

- `api/v1/services/`
- `accounts`
- `activate`

**Declaration:** `ActivationService.swift:23`

**References:** 1

| File | Line | Symbol |
|------|------|--------|
| `ActivationService.swift` | 23 | `enableResourceURL` |

...
```

### Running `list` command:

```bash
$ swift-url-finder list
```

**Output:**
```
🔍 Scanning for index stores in DerivedData...

📇 Found 3 index store(s):

[1] MyApp
    Last built: Jan 2, 2024 at 3:45 PM
    (5 minutes ago)
    Index files: 15234

[2] MyShoppingApp
    Last built: Jan 1, 2024 at 10:30 AM
    (1 day ago)
    Index files: 8921

[3] TestProject
    Last built: Dec 28, 2023 at 2:15 PM
    (5 days ago)
    Index files: 1245

💡 Tip: Use --verbose to see full paths
```

## What the Tool Tracks

For each URL endpoint, the tool captures:

1. **Symbol Name**: The property/variable name (`enableResourceURL`)
2. **Base URL**: What it's based on (`baseURL`)
3. **Path Components**: Each segment added (`["accounts", "activate"]`)
4. **Full Path**: Complete endpoint path (`resources/enable`)
5. **Source Location**: File and line number (`ActivationService.swift:23`)
6. **Transformation Count**: Number of `appendingPathComponent()` calls

## Use Cases

### 1. Finding Impact of Endpoint Changes

**Scenario**: Need to change `/resources/enable` to `/accounts/activation`

```bash
$ swift-url-finder find --project ~/MyApp --endpoint "resources/enable"
```

Shows all files that reference this endpoint so you can update them.

### 2. API Documentation

**Scenario**: Generate documentation of all API endpoints

```bash
$ swift-url-finder report --project ~/MyApp --format markdown --output docs/API.md
```

Creates a complete API endpoint reference.

### 3. Code Review

**Scenario**: Review all API endpoints

```bash
$ swift-url-finder find --project ~/MyApp --endpoint "api" --verbose
```

Shows all API endpoints with full context.

### 4. Security Audit

**Scenario**: List all customer data endpoints for security review

```bash
$ swift-url-finder report --project ~/MyApp --format json | jq '.endpoints[] | select(.fullPath | contains("customer"))'
```

Filters report to show only customer-related endpoints.
