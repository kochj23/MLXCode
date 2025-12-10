# MLX Code - Debugging Approaches & Solutions Log

**Session Date:** December 9, 2025
**Purpose:** Document all approaches tried, issues encountered, and solutions found

---

## 🔍 Issue #1: ~/.mlx Write Permissions on Work Machine

### Problem
User's work machine restricts writes to `~/.mlx` directory, preventing model storage.

### Approaches Tried:

**Approach 1: Fix Permissions**
- Attempted: Guide user to chmod/chown
- Result: ❌ Failed - corporate policy prevents permission changes

**Approach 2: Alternative Locations**
- Attempted: Use ~/Documents or ~/Library/Application Support
- Result: ⚠️ Partial - requires user to manually set path

**Approach 3: Smart Path Detection (SOLUTION)**
- Implemented: Auto-detect first writable location
- Priority order:
  1. ~/.mlx/models (backward compatible)
  2. ~/Documents/MLXCode/models (work machine friendly)
  3. ~/Library/Application Support/MLXCode/models (macOS standard)
  4. Temp directory (fallback)
- Result: ✅ SUCCESS
- Files: AppSettings.swift:120 (detectWritableModelsPath)

**Key Learnings:**
- Always test write permissions before selecting path
- Create directories automatically if they don't exist
- Provide fallback options for restricted environments
- Make backward compatible with existing setups

---

## 🐛 Issue #2: "Stuck at 11 Tokens" During Generation

### Problem
Text generation stopped after exactly 11 tokens every time.

### Approaches Tried:

**Approach 1: Model Loading Issue**
- Investigated: Checked if model fully loaded
- Result: ❌ Model loaded fine, not the issue

**Approach 2: Python Daemon Crash**
- Investigated: Checked daemon process status
- Result: ❌ Daemon running normally

**Approach 3: EOS Token Hit Early**
- Investigated: Thought model generated end-of-sequence token
- Result: ❌ Model generated 20+ tokens in standalone test

**Approach 4: Swift Token Handling Bug (SOLUTION)**
- Investigated: Checked Swift code handling "complete" signal
- Found: Line 275 `fullResponse = response.text ?? ""`
- Issue: Overwrites accumulated tokens with empty string!
- Solution: Changed to preserve fullResponse
- Result: ✅ SUCCESS
- Files: MLXService.swift:274-276

**Key Learnings:**
- Test Python daemon standalone before blaming Swift
- Check data flow between processes carefully
- Don't overwrite accumulated state without good reason
- Log every step for debugging

---

## 💥 Issue #3: "The data couldn't be read because it is missing"

### Problem
Model loading failed with cryptic error about missing data.

### Approaches Tried (10+ iterations):

**Approach 1: File Permissions**
- Investigated: Checked model file accessibility
- Result: ❌ Files readable, not the issue

**Approach 2: Sandbox Restrictions**
- Attempted: Added file access entitlements
- Result: ❌ Still failed

**Approach 3: Security-Scoped Bookmarks**
- Attempted: Create bookmarks for model directories
- Result: ❌ Made it worse - stale bookmarks caused errors

**Approach 4: Remove Sandbox Entirely**
- Attempted: Disabled app sandbox
- Result: ⚠️ Helped but didn't fix root cause

**Approach 5-9: Various Python Path Fixes**
- Tried: Different Python binaries, environment variables
- Result: ❌ Not the issue

**Approach 10: JSON Decoding Investigation (SOLUTION)**
- Method: Created unit test to decode sample responses
- Found: PythonResponse.type was non-optional
- Issue: Daemon's load response doesn't include "type" field
- JSONDecoder failed with misleading error
- Solution: Made type field optional (type: String?)
- Result: ✅ SUCCESS
- Files: MLXService.swift:741

**Test Code That Found It:**
```swift
let json = #"{"success":true,"path":"...","name":"..."}"#
try JSONDecoder().decode(PythonResponse.self, from: data)
// Error: keyNotFound "type"
// Message: "The data couldn't be read because it is missing"
```

**Key Learnings:**
- JSONDecoder errors are often misleading
- Test JSON parsing with actual daemon responses
- Make struct fields optional when formats vary
- Use unit tests to isolate issues
- Don't give up after 5 tries - systematic testing wins

---

## 🔒 Issue #4: "xcrun: error: cannot be used within an App Sandbox"

### Problem
Model downloads and operations failed with xcrun sandbox error.

### Approaches Tried:

**Approach 1: Remove Sandbox**
- Attempted: Disable app sandbox
- Result: ⚠️ Helps but doesn't fix root cause

**Approach 2: Add xcrun to Entitlements**
- Attempted: Allow xcrun execution
- Result: ❌ xcrun fundamentally forbidden in sandbox

**Approach 3: Disable mlx_lm.convert Import**
- Investigated: Convert might trigger xcrun
- Solution: Set MLX_CONVERT_AVAILABLE = False
- Result: ⚠️ Partial fix

**Approach 4: Sanitize Environment Variables**
- Attempted: Remove Xcode paths from PATH
- Solution: Filter out Developer directories
- Result: ⚠️ Still failing

**Approach 5: Direct Python Binary (SOLUTION)**
- Investigated: /usr/bin/python3 is xcode-select shim!
- Solution: Use direct path:
  `/Applications/Xcode.app/.../Python3.framework/.../python3.9`
- Result: ✅ SUCCESS
- Files: MLXService.swift:424, 829

**Approach 6: Add PYTHONPATH (CRITICAL)**
- Investigated: Packages not found even with direct Python
- Solution: Set PYTHONPATH environment variable:
  `PYTHONPATH=/Users/*/Library/Python/3.9/lib/python/site-packages`
- Result: ✅ SUCCESS
- Files: MLXService.swift:438, 457

**Key Learnings:**
- /usr/bin/python3 is a SHIM that calls xcrun
- Always use direct binary paths in sandboxed contexts
- Environment variables critical for Python package discovery
- Test exact command subprocess will run before blaming code
- xcode-select shims incompatible with app sandbox

---

## 📦 Issue #5: "huggingface_hub not installed"

### Problem
Python subprocess couldn't find user-installed packages.

### Approaches Tried:

**Approach 1: Check Python Installation**
- Verified: MLX and huggingface_hub installed
- Result: ❌ Packages exist but not found

**Approach 2: Wrong Python Binary**
- Investigated: Using Homebrew Python vs Xcode Python
- Result: ⚠️ Need Xcode Python for MLX compatibility

**Approach 3: PYTHONPATH Not Set (SOLUTION)**
- Investigated: Python.framework doesn't auto-find user packages
- Solution: Explicitly set PYTHONPATH in subprocess environment
- Code:
  ```swift
  env["PYTHONPATH"] = "/Users/\(NSUserName())/Library/Python/3.9/lib/python/site-packages"
  ```
- Result: ✅ SUCCESS
- Files: MLXService.swift:438, 457, 870

**Key Learnings:**
- Xcode's Python doesn't auto-include user site-packages
- Must explicitly set PYTHONPATH for subprocesses
- Test with exact environment subprocess will have
- Don't assume environment inheritance

---

## 🔧 Issue #6: Model Discovery Returning Wrong Paths

### Problem
Models had incorrect hardcoded paths after path detection changes.

### Approaches Tried:

**Approach 1: Update Saved Models**
- Attempted: Modify saved model paths in UserDefaults
- Result: ❌ Complex, error-prone

**Approach 2: Clear and Regenerate**
- Attempted: Delete saved models, recreate with new paths
- Result: ⚠️ Loses user customizations

**Approach 3: Auto-Discovery on Startup (SOLUTION)**
- Implemented: Scan filesystem for actual models on launch
- Process:
  1. Search all potential model directories
  2. Find directories with config.json
  3. Create model entries with REAL filesystem paths
  4. Replace old cached list
- Result: ✅ SUCCESS
- Files: MLXCodeApp.swift:39-63, MLXService.swift:329-393

**Approach 4: Manual "Scan Disk" Button**
- Added: User-triggered refresh in Settings → Model
- Shows: Popup with all discovered models and paths
- Result: ✅ SUCCESS
- Files: SettingsView.swift:247-266, 635-684

**Key Learnings:**
- Don't trust cached data - verify against filesystem
- Auto-discovery prevents stale configuration
- Give users manual refresh option
- Show what was discovered for transparency

---

## 🚀 Development Patterns That Worked

### Pattern 1: Systematic Debugging
```
1. Reproduce issue in isolation
2. Test each component separately
3. Create unit tests for suspected area
4. Use logs extensively
5. Test fixes standalone before integrating
```

### Pattern 2: Layered Fallbacks
```
Try Option 1 (ideal)
  ↓ failed
Try Option 2 (good)
  ↓ failed
Try Option 3 (acceptable)
  ↓ failed
Try Option 4 (minimal viable)
  ↓ SUCCESS
```

### Pattern 3: Test-Driven Fixes
```swift
// 1. Write test that reproduces bug
func testJSONDecoding() {
    let json = actualDaemonResponse
    XCTAssertNoThrow(try decode(json))
}

// 2. Test fails (reproduces bug)
// 3. Fix code
// 4. Test passes
// 5. Apply fix to production
```

### Pattern 4: External Verification
```bash
# Before blaming app, test command directly:
/usr/bin/python3 script.py args
# If this works, problem is in Swift
# If this fails, problem is in Python/environment
```

---

## 🎓 Critical Lessons Learned

### 1. JSONDecoder Errors Are Misleading
**Issue:** "The data couldn't be read because it is missing"
**Reality:** Missing required field in struct
**Solution:** Log raw JSON before parsing, make fields optional

### 2. xcode-select Shims Incompatible with Sandbox
**Issue:** /usr/bin/python3 calls xcrun
**Reality:** It's a shim, not the actual binary
**Solution:** Use direct binary path

### 3. Subprocess Environment Differs from Parent
**Issue:** Packages not found in subprocess
**Reality:** Environment variables not inherited properly
**Solution:** Explicitly set PYTHONPATH, HOME, PATH

### 4. Don't Trust Cached Paths
**Issue:** Old model paths still referenced
**Reality:** Filesystem is source of truth
**Solution:** Auto-discover from disk on launch

### 5. Unit Tests Reveal Root Causes
**Issue:** Spent hours guessing
**Reality:** 5-minute unit test found exact problem
**Solution:** Write test first, debug second

---

## 🔨 Development Tools That Helped

### 1. Standalone Python Testing
```bash
# Test exact subprocess command:
env -i PATH="..." PYTHONPATH="..." /path/to/python3.9 script.py

# If this works, subprocess will work
# If this fails, fix environment first
```

### 2. Swift Test Scripts
```bash
# Quick compile and test:
swift test_json_decode.swift

# Faster than rebuilding entire project
```

### 3. Process Sampling
```bash
# See what a process is doing:
sample PID 1

# Shows thread states, loaded libraries
```

### 4. Git Stashing for Experiments
```bash
git stash      # Try experimental fix
git stash pop  # Revert if it doesn't work
```

---

## 📝 Code Patterns to Remember

### Secure Token Storage
```swift
// ✅ DO: Use Keychain
let query: [String: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "com.app.service",
    kSecValueData: tokenData
]
SecItemAdd(query as CFDictionary, nil)

// ❌ DON'T: Use UserDefaults
UserDefaults.standard.set(token, forKey: "token") // INSECURE!
```

### Optional JSON Fields
```swift
// ✅ DO: Make fields optional when format varies
struct Response: Codable {
    let type: String?      // Optional
    let success: Bool?     // Optional
}

// ❌ DON'T: Require all fields
struct Response: Codable {
    let type: String       // REQUIRED - will fail!
}
```

### Subprocess Environment
```swift
// ✅ DO: Set explicitly
var env: [String: String] = [:]
env["PYTHONPATH"] = userSitePackages
env["PATH"] = cleanPath
process.environment = env

// ❌ DON'T: Inherit everything
process.environment = ProcessInfo.processInfo.environment // May include problematic vars
```

### Smart Path Detection
```swift
// ✅ DO: Try multiple options with fallback
let candidates = ["~/.mlx/models", "~/Documents/MLXCode/models", ...]
for path in candidates {
    if canWrite(path) { return path }
}
return fallback

// ❌ DON'T: Hardcode single path
let path = "~/.mlx/models" // Fails on restricted systems
```

---

## 🎯 Quick Reference - Common Issues

### "Cannot be used within an App Sandbox"
**Cause:** Calling xcrun, xcodebuild, or xcode-select
**Fix:** Use direct binary paths, remove sandbox, or sanitize environment

### "The data couldn't be read"
**Cause:** JSONDecoder missing required field
**Fix:** Make struct fields optional, log raw JSON

### "Module not found" in Python
**Cause:** PYTHONPATH not set
**Fix:** Export PYTHONPATH=/Users/*/Library/Python/3.9/lib/python/site-packages

### "No such file or directory"
**Cause:** Tilde (~) not expanded, or stale cached path
**Fix:** Use (path as NSString).expandingTildeInPath, auto-discover from disk

### Model Won't Load
**Checklist:**
1. ✅ File exists? `FileManager.default.fileExists(atPath:)`
2. ✅ Has config.json? Check for required files
3. ✅ Daemon running? Check process list
4. ✅ Correct Python? Use direct binary, not shim
5. ✅ PYTHONPATH set? Check subprocess environment
6. ✅ JSON parsing? Log raw responses

---

## 📚 Resources Created

### Documentation
- `FINAL_SESSION_SUMMARY.md` - What was accomplished
- `CLAUDE_CODE_FEATURE_PARITY.md` - Competitive analysis
- `ROADMAP_V4.md` - Integration plan
- `DEBUGGING_APPROACHES_LOG.md` - This file

### Scripts
- `setup_mlx_models.sh` - External model downloader
- Test scripts for JSON decoding

### Unit Tests
- `MLXServiceTests.swift` - JSON response parsing tests

---

## 🔄 Future Debugging Strategy

When encountering new issues:

1. **Isolate the Component**
   - Test daemon standalone
   - Test Python script directly
   - Test Swift parsing separately

2. **Log Everything**
   - Raw data before parsing
   - Environment variables
   - File paths (expanded)
   - Process status

3. **Create Unit Test**
   - Reproduce bug in test
   - Fix until test passes
   - Prevents regression

4. **Document Approach**
   - What was tried
   - Why it failed
   - What worked
   - Key learnings

5. **Verify Externally**
   - Test command in terminal
   - Check with different environment
   - Validate assumptions

---

## ✅ Success Metrics

**Issues Resolved:** 6 major bugs
**Time Saved:** Hours of future debugging with this documentation
**Approaches Logged:** 20+ different attempts
**Solutions Found:** 6 working fixes
**Code Quality:** All fixes tested and verified

---

**This log will help future debugging by documenting what works, what doesn't, and why.**

**Last Updated:** December 9, 2025
