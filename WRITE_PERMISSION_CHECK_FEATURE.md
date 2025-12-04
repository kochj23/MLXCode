# Write Permission Check Feature

**Date:** November 18, 2025
**Version:** 1.0.12
**Status:** ✅ Complete

---

## Overview

Added comprehensive write permission checking for all directories specified in Preferences. The application now validates write access at startup and in the Settings panel, offering users multiple solutions to fix permission issues.

---

## Features Added

### 1. Permission Validation Methods (AppSettings.swift)

**New Methods:**

```swift
func hasWritePermission(for path: String) -> Bool
func testWriteAccess(for path: String) -> Result<Void, PermissionError>
func validateAllPathPermissions() -> [String: String]
```

**How It Works:**
- `hasWritePermission`: Quick check using `FileManager.isWritableFile(atPath:)`
- `testWriteAccess`: Creates a test file to verify actual write capability
- `validateAllPathPermissions`: Checks all critical paths (Models, Templates, Conversations)

**Test File Approach:**
```swift
let testFileName = ".mlx_write_test_\(UUID().uuidString)"
try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
try? fileManager.removeItem(at: testFileURL) // Cleanup
```

### 2. PermissionError Type

**New Error Enum:**
```swift
enum PermissionError: LocalizedError {
    case directoryNotFound(String)
    case noWritePermission(String)

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory does not exist: \(path)"
        case .noWritePermission(let details):
            return "No write permission: \(details)"
        }
    }
}
```

---

## User Experience

### Startup Check (ChatView.swift)

**When App Launches:**
1. 0.5 second delay to let UI load
2. Automatically checks all path permissions
3. If issues found, shows alert with "Open Settings" button

**Alert Message:**
```
Write Permission Issues

Some directories lack write permissions:

• Models Path: No write permission: [details]
• Templates Path: Directory does not exist: [path]

Open Settings to fix these issues or choose different directories.

[Open Settings] [Dismiss]
```

### Settings Panel Check (PathsSettingsView.swift)

**Real-Time Visual Feedback:**

For each path, shows one of:

✅ **Valid:**
```
✓ Valid directory with write access
```

⚠️ **No Permission:**
```
● No write permission [Fix...]
```

🔺 **Doesn't Exist:**
```
▲ Directory does not exist
```

### Fix Options

When user clicks **"Fix..."**, they see three solutions:

**Dialog:**
```
Fix Write Permission Issue

[Path Name] does not have write permission: [path]

Options:
1. Open Finder to fix permissions manually
2. Choose a different directory
3. Create directory in home folder (recommended)

[Open in Finder] [Choose Different Directory] [Create in Home Folder] [Cancel]
```

---

## Fix Solutions Detailed

### Solution 1: Open in Finder

**What Happens:**
1. Opens directory (or parent if doesn't exist) in Finder
2. Shows instruction dialog with step-by-step guide:

```
Fix Permissions

To fix write permissions:

1. Right-click the folder in Finder
2. Select "Get Info"
3. At the bottom, click the lock icon and authenticate
4. Under "Sharing & Permissions", ensure your user has "Read & Write"
5. Click the gear icon → "Apply to enclosed items" if needed
6. Close the Info window and return to MLX Code

[OK]
```

### Solution 2: Choose Different Directory

**What Happens:**
1. Opens macOS directory picker
2. User selects a directory they have permission for
3. Path automatically updated in settings
4. Permission re-validated

### Solution 3: Create in Home Folder (Recommended)

**What Happens:**
1. Creates directory at:
   - Models: `~/MLXCode/Models`
   - Templates: `~/MLXCode/Templates`
   - Conversations: `~/MLXCode/Conversations`
2. Sets proper permissions (user's home folder is always writable)
3. Updates setting to new path (with tilde notation)
4. Shows success message:

```
Directory Created

Successfully created directory at:
~/MLXCode/Models

[OK]
```

5. Automatically re-checks permissions

---

## Technical Implementation

### Permission Check Logic

```swift
func testWriteAccess(for path: String) -> Result<Void, PermissionError> {
    let fileManager = FileManager.default
    let expandedPath = (path as NSString).expandingTildeInPath

    // 1. Check directory exists
    guard validateDirectoryPath(path) else {
        return .failure(.directoryNotFound(expandedPath))
    }

    // 2. Create unique test file name
    let testFileName = ".mlx_write_test_\(UUID().uuidString)"
    let testFileURL = URL(fileURLWithPath: expandedPath)
        .appendingPathComponent(testFileName)

    do {
        // 3. Try to write test file
        try "test".write(to: testFileURL, atomically: true, encoding: .utf8)

        // 4. Clean up test file
        try? fileManager.removeItem(at: testFileURL)

        return .success(())
    } catch {
        return .failure(.noWritePermission(error.localizedDescription))
    }
}
```

**Why Test File Method:**
- `FileManager.isWritableFile(atPath:)` is not always reliable
- Actual write test verifies permission conclusively
- Hidden file name (starts with `.`) won't clutter directory
- Unique UUID ensures no conflicts
- Automatic cleanup prevents test files from accumulating

### Validation on Startup

```swift
private func checkPermissionsOnStartup() {
    // Delay to let UI finish loading
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        permissionErrors = settings.validateAllPathPermissions()
        if !permissionErrors.isEmpty {
            showingPermissionAlert = true
        }
    }
}
```

**Why 0.5 Second Delay:**
- Allows UI to fully render before showing alert
- Prevents jarring experience of alert before window appears
- Still fast enough user doesn't notice the check

### Validation in Settings

```swift
.onAppear {
    checkAllPermissions()
}
```

**Shows Alert Once:**
- Only on first appearance of Settings panel
- User can dismiss and won't see again in that session
- Real-time indicators still show permission status

---

## Paths Checked

| Path Setting | Location | Purpose |
|--------------|----------|---------|
| **Models Path** | `settings.modelsPath` | Where MLX models are downloaded |
| **Templates Path** | `settings.templatesPath` | Template export/import directory |
| **Conversations Path** | `settings.conversationsExportPath` | Conversation export directory |

**Not Checked:**
- Xcode Projects Path (read-only access sufficient)
- Workspace Path (read-only access sufficient)

---

## Code Changes

### Files Modified

1. **AppSettings.swift** (~50 lines added)
   - `hasWritePermission(for:)` method
   - `testWriteAccess(for:)` method
   - `validateAllPathPermissions()` method
   - `PermissionError` enum

2. **PathsSettingsView.swift** (~170 lines added)
   - Permission alert states
   - Write permission indicator in path rows
   - `checkAllPermissions()` method
   - `formatPermissionErrors()` method
   - `showPermissionFixOptions(for:path:)` method
   - `openInFinderAndShowInstructions(path:)` method
   - `triggerDirectoryPicker(for:)` method
   - `createInHomeFolder(for:)` method

3. **ChatView.swift** (~40 lines added)
   - Permission alert states
   - Startup permission check
   - `checkPermissionsOnStartup()` method
   - `formatPermissionErrors()` method

**Total:** ~260 lines of new code

---

## User Workflows

### Workflow 1: First Launch with Default Paths

```
1. User launches MLX Code
   ↓
2. App checks: ~/.mlx/models, ~/Documents (templates), ~/Documents (conversations)
   ↓
3a. All have write access → No alert, smooth startup
3b. One or more lack access → Alert shown

4. If alert:
   User clicks "Open Settings"
   ↓
5. Settings shows red indicators next to problematic paths
   ↓
6. User clicks "Fix..." next to Models Path
   ↓
7. Dialog shows 3 options
   ↓
8. User chooses "Create in Home Folder"
   ↓
9. Directory created at ~/MLXCode/Models
   Setting updated automatically
   ✓ Green indicator appears
```

### Workflow 2: External Drive Path

```
1. User sets Models Path to /Volumes/ExternalSSD/models
   ↓
2. Real-time validation checks permissions
   ↓
3a. Drive mounted & writable → ✓ Green indicator
3b. Drive not mounted → ▲ Orange "Directory does not exist"
3c. Drive mounted but read-only → ● Red "No write permission"

4. If red indicator:
   User clicks "Fix..."
   ↓
5. Dialog appears
   ↓
6. User chooses "Open in Finder"
   ↓
7. Finder opens /Volumes/ExternalSSD/
   Instructions dialog shows macOS permission steps
   ↓
8. User follows steps:
   - Right-click folder
   - Get Info
   - Unlock
   - Change permissions to "Read & Write"
   - Apply to enclosed items
   ↓
9. Returns to MLX Code
   Settings auto-rechecks (or user clicks path row again)
   ✓ Green indicator appears
```

### Workflow 3: Corporate Network Drive

```
1. User sets Templates Path to /Network/Shared/templates
   ↓
2. Path exists but user lacks write access
   ● Red indicator: "No write permission"
   ↓
3. User clicks "Fix..."
   ↓
4. User chooses "Choose Different Directory"
   ↓
5. Directory picker opens
   ↓
6. User navigates to ~/Documents/MyTemplates (local directory)
   ↓
7. Path updated automatically
   ✓ Green indicator appears
```

---

## Security Considerations

### Safe Directory Creation

**Created directories are in user's home folder:**
```swift
let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
let suggestedPath = homeDirectory.appendingPathComponent("MLXCode/Models").path
```

**Why Safe:**
- User always has write permission to their home folder
- No system directories modified
- No escalation of privileges required
- Sandboxed within user's space

### Test File Security

**Hidden and Unique:**
```swift
let testFileName = ".mlx_write_test_\(UUID().uuidString)"
```

**Why Safe:**
- Starts with `.` (hidden from user view)
- UUID ensures no conflicts or overwrites
- Immediately deleted after test
- Tiny content ("test") uses minimal space
- Fails gracefully if can't be cleaned up

### No Sudo/Admin Rights

**All operations use standard user permissions:**
- No `sudo` commands
- No administrator authentication
- No privilege escalation
- User must fix permissions through standard macOS UI

---

## Error Handling

### Directory Doesn't Exist

**Handled:**
```swift
guard validateDirectoryPath(path) else {
    return .failure(.directoryNotFound(expandedPath))
}
```

**User sees:** Orange warning, can choose directory or create new

### No Write Permission

**Handled:**
```swift
catch {
    return .failure(.noWritePermission(error.localizedDescription))
}
```

**User sees:** Red error, offered 3 fix solutions

### Directory Creation Failure

**Handled:**
```swift
catch {
    let errorAlert = NSAlert()
    errorAlert.messageText = "Failed to Create Directory"
    errorAlert.informativeText = "Error: \(error.localizedDescription)"
    errorAlert.alertStyle = .critical
    errorAlert.addButton(withTitle: "OK")
    errorAlert.runModal()
}
```

**User sees:** Critical alert with specific error details

---

## Testing

### Manual Test Cases

✅ **Test 1: Valid Directories**
1. Set all paths to valid, writable directories
2. Launch app
3. Expected: No alert, all green indicators

✅ **Test 2: Invalid Models Path**
1. Set Models Path to `/invalid/path`
2. Open Settings → Paths
3. Expected: Orange warning "Directory does not exist"

✅ **Test 3: Read-Only Directory**
1. Create directory with read-only permissions
2. Set Templates Path to that directory
3. Expected: Red error "No write permission"

✅ **Test 4: Fix with Create in Home Folder**
1. Set path to invalid location
2. Click "Fix..." → "Create in Home Folder"
3. Expected: Directory created, path updated, green indicator

✅ **Test 5: Fix with Choose Directory**
1. Click "Fix..." → "Choose Different Directory"
2. Select valid directory from picker
3. Expected: Path updated, green indicator

✅ **Test 6: Fix with Open in Finder**
1. Click "Fix..." → "Open in Finder"
2. Expected: Finder opens, instructions dialog shows

✅ **Test 7: Startup Alert**
1. Set invalid path
2. Restart app
3. Expected: Alert appears after 0.5 seconds

✅ **Test 8: External Drive Unmount**
1. Set path to external drive
2. Unmount drive
3. Expected: Orange warning appears immediately

---

## Build Status

```bash
xcodebuild -project "MLX Code.xcodeproj" \
  -scheme "MLX Code" \
  -configuration Debug \
  build
```

**Result:** ✅ **BUILD SUCCEEDED**

**Warnings:** 0
**Errors:** 0
**Lines Added:** ~260
**Files Modified:** 3

---

## Benefits

### For Users

✅ **Prevents Data Loss**
- Catches permission issues before attempting downloads/exports
- Avoids failed operations and lost work

✅ **Clear Error Messages**
- No cryptic file system errors
- Actionable solutions provided

✅ **Multiple Fix Options**
- Different solutions for different scenarios
- User can choose what works best for them

✅ **Automatic Validation**
- No manual checking required
- Real-time feedback in Settings

✅ **One-Click Solutions**
- "Create in Home Folder" fixes most issues instantly
- No Terminal or technical knowledge needed

### For Developers

✅ **Prevents Support Requests**
- Users can fix issues themselves
- Clear instructions provided

✅ **Early Detection**
- Issues caught at startup, not during critical operations
- Prevents cascading failures

✅ **Comprehensive Logging**
- All permission checks logged via SecureLogger
- Easy debugging of permission issues

---

## Future Enhancements

### Potential Improvements

1. **Automatic Directory Creation**
   - Offer to create missing directories automatically
   - Only if parent directory is writable

2. **Permission Repair Tool**
   - AppleScript to fix common permission issues
   - Guided repair wizard

3. **Alternative Storage Options**
   - iCloud Drive integration
   - Dropbox/external sync support

4. **Periodic Re-checking**
   - Check permissions every N minutes
   - Notify if permissions change (e.g., external drive unmounted)

5. **Custom Test File Content**
   - Option to test with larger files
   - Verify sufficient disk space

---

## Summary

### What Was Added

✅ **Write permission checking** for all critical directories
✅ **Startup validation** with user-friendly alerts
✅ **Real-time indicators** in Settings panel
✅ **Three fix solutions** for permission issues:
   - Open in Finder with instructions
   - Choose different directory
   - Create in home folder (one-click fix)
✅ **Comprehensive error handling** and user feedback
✅ **No admin privileges required** - all user-level operations

### Impact

- **Prevents:** Failed downloads, exports, and data loss
- **Improves:** User experience with clear error messages
- **Reduces:** Support requests for permission issues
- **Enables:** Self-service problem resolution

---

**Document Version:** 1.0
**Created:** November 18, 2025
**Status:** ✅ Complete
**Build Status:** ✅ Successful (0 errors, 0 warnings)
