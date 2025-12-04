# Download Diagnostics Enhancement - 2025-11-18 18:47

## Problem
Downloads were failing with "exit code 1" from the app, but the same Python script works perfectly when run manually from terminal.

## Root Cause Analysis

**Manual Test Result:**
```bash
/usr/bin/python3 huggingface_downloader.py download mlx-community/Phi-3.5-mini-instruct-4bit \
  --output ~/.mlx/models/phi-3.5-mini-test --quantize 4bit
# Exit code: 0 (SUCCESS)
# Downloaded: 2.0GB model successfully
```

**App Execution:** Fails with exit code 1, but no detailed error output was being captured.

## Changes Made

### 1. Added Environment Variables
**File:** `MLXService.swift` lines 713-717

The Process() wasn't inheriting the user's environment. Added:
```swift
// Set environment to include system PATH
process.environment = ProcessInfo.processInfo.environment

// Set working directory to home
let homeDir = FileManager.default.homeDirectoryForCurrentUser
process.currentDirectoryURL = homeDir
```

### 2. Separated stdout and stderr
**File:** `MLXService.swift` lines 723-788

Previously, both stdout and stderr were combined into one pipe. Now they're separate:
```swift
let outputPipe = Pipe()
let errorPipe = Pipe()
process.standardOutput = outputPipe
process.standardError = errorPipe
```

This allows us to see:
- **stdout** - JSON progress messages and success output
- **stderr** - Python warnings, errors, and stack traces

### 3. Enhanced Logging
**File:** `MLXService.swift` lines 719-721, 755-788, 811-815

Added logging for:
- Working directory being used
- Environment PATH variable
- Real-time stdout with `📥 Python stdout:` prefix
- Real-time stderr with `⚠️ Python stderr:` prefix
- Full stdout dump after completion
- Full stderr dump after completion

### 4. Better Error Messages
**File:** `MLXService.swift` lines 817-846

Improved error handling to:
- Prefer stderr for error messages (more likely to contain the actual error)
- Fall back to stdout if stderr is empty
- Show combined output for debugging
- Log everything to SecureLogger for Console.app review

## Testing Required

### Step 1: Launch the App
The app is now running with enhanced diagnostics.

### Step 2: Attempt a Download
1. Open Settings (gear icon)
2. Go to "Model" tab
3. Select a model (e.g., "Phi-3.5 Mini")
4. Click "Download" button

### Step 3: Capture the Logs

**Option A: Watch Console.app**
```bash
open -a Console
# Filter by: process = "MLX Code"
# Look for lines with:
# - 📝 Command: (shows exact command)
# - 🏠 Working directory: (shows where it runs)
# - 🌍 Environment PATH: (shows PATH variable)
# - 📥 Python stdout: (shows Python output)
# - ⚠️ Python stderr: (shows Python errors)
# - Process exited with code: (shows exit code)
```

**Option B: Use the watch script**
```bash
cd "/Volumes/Data/xcode/MLX Code"
./watch_logs.sh
```

### Step 4: Compare with Manual Execution

If the app still fails, compare the logged command with manual execution:

**App's command** (from logs):
```
/usr/bin/python3 <script-path> download mlx-community/Phi-3.5-mini-instruct-4bit \
  --output ~/.mlx/models/phi-3.5-mini --quantize 4bit
```

**Manual command** (that works):
```bash
/usr/bin/python3 "/Volumes/Data/xcode/MLX Code/Python/huggingface_downloader.py" \
  download mlx-community/Phi-3.5-mini-instruct-4bit \
  --output ~/.mlx/models/phi-3.5-mini --quantize 4bit
```

The commands should be IDENTICAL. If they're not, that's the problem.

## Expected Diagnostics Output

If the download **succeeds**, you should see:
```
🔍 Looking for huggingface_downloader script...
✅ Found script in bundle: /path/to/script
✅ Using downloader script at: /path/to/script
Script file exists check: true
Python exists at /usr/bin/python3: true
📝 Command: /usr/bin/python3 /path/to/script download mlx-community/Phi-3.5-mini-instruct-4bit --output /Users/kochj/.mlx/models/phi-3.5-mini --quantize 4bit
🏠 Working directory: /Users/kochj
🌍 Environment PATH: /usr/local/bin:/usr/bin:/bin:...
🚀 Starting download process...
✅ Process started successfully, PID: 12345
⏳ Waiting for download to complete...
📥 Python stdout: {"type": "progress", "stage": "downloading", "message": "Downloading..."}
📥 Python stdout: Fetching 13 files: 100%|██████████| 13/13 [00:31<00:00,  2.45s/it]
📥 Python stdout: {"success": true, "path": "/Users/kochj/.mlx/models/phi-3.5-mini", ...}
Process exited with code: 0
📋 Full stdout (XXX bytes):
{... all JSON output ...}
📋 Full stderr (XXX bytes):
/Users/kochj/Library/Python/3.9/lib/python/site-packages/urllib3/__init__.py:35: NotOpenSSLWarning...
```

If the download **fails**, you should see:
```
... (same startup logs) ...
Process exited with code: 1
📋 Full stdout (XX bytes):
(may be empty or contain partial JSON)
📋 Full stderr (XXX bytes):
Traceback (most recent call last):
  File "/path/to/script", line XX, in <module>
    <actual error message here>
❌ Download failed with exit code 1
stderr output: <error message>
Combined output for debugging: <full output>
```

## What to Look For

### If Exit Code 1 with Empty stderr:
- Python script crashed before printing anything
- Script file might not be executable
- Python interpreter issue
- Missing Python dependencies

### If Exit Code 1 with stderr Output:
- **ImportError:** Python package not installed
- **FileNotFoundError:** Path issue or permission denied
- **AttributeError/TypeError:** Bug in Python script
- **HfHubHTTPError:** Network or HuggingFace API issue

### If Exit Code 0 but Model Not Working:
- Download succeeded
- Model loading is the next issue to diagnose

## Next Steps After Testing

1. **If download succeeds:** Move to testing model loading
2. **If download fails:** Send me the EXACT stderr output from the logs
3. **If no output at all:** Process isn't starting - might be sandbox/entitlements issue

## Files Modified This Session

1. `/Volumes/Data/xcode/MLX Code/MLX Code/Services/MLXService.swift`
   - Lines 713-721: Added environment and working directory
   - Lines 723-788: Separated stdout/stderr pipes
   - Lines 811-815: Enhanced output logging
   - Lines 817-846: Improved error handling

## Build Location

```
/Volumes/Data/xcode/MLX Code/build/Release/MLX Code.app
```

Built: 2025-11-18 18:47
Python scripts bundled: ✅ Yes
App Sandbox: ❌ Disabled
Hardened Runtime: ✅ Enabled

---

## Quick Test Command

To test the Python script directly (this WORKS):
```bash
/usr/bin/python3 "/Volumes/Data/xcode/MLX Code/Python/huggingface_downloader.py" \
  download mlx-community/Phi-3.5-mini-instruct-4bit \
  --output ~/.mlx/models/test-download \
  --quantize 4bit
```

Expected: Downloads ~2GB model successfully with exit code 0.
