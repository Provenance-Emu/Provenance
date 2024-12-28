# PVFeatureFlags

A Swift feature flags library that supports remote configuration, version control, and app type restrictions. Built with SwiftUI support and compatible with iOS/macOS/tvOS.

## Features

- Remote configuration via JSON
- Version and build number gating
- App type restrictions (Standard/Lite/App Store variants)
- SwiftUI integration with `@StateObject` and environment support
- Cached feature states for performance
- Thread-safe updates
- Platform agnostic (iOS, macOS, tvOS, etc.)
- Comprehensive testing support

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/PVFeatureFlags.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File > Add Packages
2. Enter the repository URL
3. Click "Add Package"

## Setup

### 1. Create Feature Flags Configuration

Create a JSON file with your feature flags configuration:

```json
{
    "features": {
        "inAppFreeROMs": {
            "enabled": true,
            "minVersion": "1.0.0",
            "minBuildNumber": "100",
            "allowedAppTypes": ["standard", "standard.appstore"],
            "description": "Allows downloading free ROMs directly in the app"
        }
    }
}
```

### 2. Configure Info.plist

Add the `PVAppType` key to your Info.plist with one of these values:
- `standard` - Standard non-App Store version
- `lite` - Lite non-App Store version
- `standard.appstore` - Standard App Store version
- `lite.appstore` - Lite App Store version

```xml
<key>PVAppType</key>
<string>standard</string>
```

## Usage

### Basic Usage

```swift
import PVFeatureFlags

// Check if a feature is enabled
if PVFeatureFlagsManager.shared.inAppFreeROMs {
    // Feature is enabled
}

// Load remote configuration
Task {
    try? await PVFeatureFlagsManager.shared.loadConfiguration(
        from: URL(string: "https://your-domain.com/features.json")!
    )
}
```

### SwiftUI Integration

#### Option 1: Using StateObject

```swift
struct ContentView: View {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared

    var body: some View {
        if featureFlags.inAppFreeROMs {
            Text("Free ROMs feature is enabled!")
        }
    }
}
```

#### Option 2: Using Environment

```swift
// In your App file
@main
struct MyApp: App {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(featureFlags)
                .task {
                    try? await featureFlags.loadConfiguration(
                        from: URL(string: "https://your-domain.com/features.json")!
                    )
                }
        }
    }
}

// In your views
struct ContentView: View {
    @Environment(\.featureFlags) var featureFlags

    var body: some View {
        if featureFlags.inAppFreeROMs {
            Text("Free ROMs feature is enabled!")
        }
    }
}
```

### Feature Flag JSON Structure

```json
{
    "features": {
        "featureKey": {
            "enabled": true,                           // Required: Base enable/disable
            "minVersion": "1.0.0",                    // Optional: Minimum app version
            "minBuildNumber": "100",                  // Optional: Minimum build number
            "allowedAppTypes": ["standard"],          // Optional: Allowed app types
            "description": "Feature description"       // Optional: Feature description
        }
    }
}
```

### App Types

The library supports four app types:
- `standard`: Regular non-App Store version
- `lite`: Lite non-App Store version
- `standard.appstore`: Regular App Store version
- `lite.appstore`: Lite App Store version

You can check app type properties:

```swift
let appType = PVAppType.standard
appType.isAppStore  // false
appType.isLite      // false
```

## Advanced Usage

### Custom Feature Flag Manager

```swift
let customFlags = PVFeatureFlags(
    appType: .standard,
    buildNumber: "101",
    appVersion: "1.1.0"
)

let manager = PVFeatureFlagsManager(featureFlags: customFlags)
```

### Manual Feature Checks

```swift
// Check any feature by key
if PVFeatureFlagsManager.shared.isEnabled("customFeature") {
    // Feature is enabled
}
```

### Testing Support

The library includes testing-specific APIs to help with unit testing:

```swift
// Create a feature flags instance with pre-loaded configuration
let testFlags = PVFeatureFlags(
    configuration: myTestConfig,
    appType: .standard,
    buildNumber: "101",
    appVersion: "1.1.0"
)

// Or set configuration after initialization
let flags = PVFeatureFlags(appType: .standard)
flags.setConfiguration(myTestConfig)
```

Note: These testing APIs are marked as `internal` and are only available when importing the module with `@testable`.

## Requirements

- Swift 6.0+
- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+ / visionOS 1.0+
- Mac Catalyst 16.0+

## Thread Safety

The library is designed to be thread-safe:
- All feature flag operations are actor-isolated
- SwiftUI integration is main-actor bound
- Configuration updates are atomic

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
