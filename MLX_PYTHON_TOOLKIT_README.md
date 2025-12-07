# Python MLX Toolkit Configuration - MLX Code

## Files Added

The following files have been created to add Python MLX toolkit configuration:

1. **MLXPythonToolkitSettings.swift** - Universal drop-in component
   - Settings manager with health checking
   - SwiftUI view with status indicator
   - Auto-detection and installation
   - Persistent settings storage

2. **MLX Code/Models/MLXPythonSettings.swift** - Alternative implementation
3. **MLX Code/Views/MLXPythonSettingsView.swift** - Standalone view

## Features

### Status Indicator
- 🟢 Green: MLX toolkit working
- 🟡 Yellow: Python found, MLX not installed
- 🔴 Red: Python not found or error
- ⚪ Gray: Not checked yet

### Functionality
- ✅ Configure Python executable path
- ✅ Auto-detect Python and MLX
- ✅ Check MLX availability
- ✅ Install MLX via pip (one-click)
- ✅ Display Python and MLX versions
- ✅ Auto-check on app launch
- ✅ Persistent settings

## How to Add to Settings

### Option 1: Use MLXPythonToolkitSettings.swift (Recommended)

This is a self-contained file with both the settings manager and SwiftUI view.

Add to your SettingsView:

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            // ... other tabs ...

            MLXPythonToolkitSettingsView()
                .tabItem {
                    Label("MLX Python", systemImage: "sparkles")
                }
        }
    }
}
```

### Option 2: Manual Integration

1. Add `MLXPython Toolkit` tab to the existing settings
2. Include the status indicator circle
3. Add check/auto-detect/install buttons
4. Save settings to UserDefaults

## Manual Setup Required

Since Xcode uses FileSystemSynchronizedRootGroup, the file may need to be manually added:

1. Open Xcode project
2. Right-click on "MLX Code" folder
3. Click "Add Files to MLX Code..."
4. Select `MLXPythonToolkitSettings.swift`
5. Ensure "MLX Code" target is checked
6. Build the project

Alternatively, the file is already in the correct directory and should be automatically picked up on next build.

## Usage Example

```swift
import SwiftUI

// Access settings
let settings = MLXPythonToolkitSettings.shared

// Check status
Task {
    await settings.checkMLXAvailability()
}

// Use in view
struct MySettingsView: View {
    @StateObject private var mlxSettings = MLXPythonToolkitSettings.shared

    var body: some View {
        VStack {
            HStack {
                Circle()
                    .fill(mlxSettings.status.color)
                    .frame(width: 16, height: 16)

                Text(mlxSettings.status.message)
            }
        }
    }
}
```

## Testing

After adding the file and rebuilding:

1. Open Settings (Cmd+,)
2. Navigate to "MLX Python" tab
3. Click "Auto-Detect" button
4. Status light should show result
5. If yellow (MLX missing), click "Install MLX"

## Notes

- The file is **self-contained** with no external dependencies
- Works with **SwiftUI** projects
- Can be copied to any Xcode project
- Automatically saves settings to UserDefaults
- Thread-safe with @MainActor

## Integration Status

**Status**: Files created ✅
**Added to Project**: Requires manual step in Xcode
**Tested**: Pending after project addition
**Documented**: Yes ✅

To complete integration:
1. Open MLX Code.xcodeproj in Xcode
2. Verify MLXPythonToolkitSettings.swift appears in file navigator
3. If not, manually add it to the project
4. Uncomment the tab in SettingsView.swift
5. Build and test

---

**Created**: December 6, 2025
**Author**: Jordan Koch
**Version**: 1.0
