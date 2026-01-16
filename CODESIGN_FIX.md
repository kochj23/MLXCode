# Code Signing Fix for MLX Code

**Issue:** App crashes with "Code Signature Invalid" error
**Date:** January 7, 2026
**Resolved:** ✅

---

## 🐛 The Problem

**Crash Report:**
```
Exception Type:    EXC_BAD_ACCESS (SIGKILL (Code Signature Invalid))
Termination Reason:  Namespace CODESIGNING, Code 2, Invalid Page
```

**What Happened:**
- Modified `LocalImageGenerationTool.swift` to fix FLUX integration
- Built and archived the app
- Exported and installed to `~/Applications/MLX Code.app`
- App launched but crashed when using certain features (voice cloning)
- macOS killed the app due to invalid code signature

**Root Cause:**
When copying the app to `~/Applications/`, the code signature validation failed. macOS is strict about code signatures, especially for apps in user directories.

---

## ✅ The Fix

### **Quick Fix (Ad-Hoc Signature):**
```bash
# Re-sign with ad-hoc signature (works for local development)
codesign --force --deep --sign - "/Users/kochj/Applications/MLX Code.app"

# Verify the signature
codesign --verify --verbose "/Users/kochj/Applications/MLX Code.app"
```

### **Proper Fix (Developer Certificate):**
```bash
# Find your signing identity
security find-identity -v -p codesigning

# Re-sign with your developer certificate
codesign --force --deep --sign "Apple Development: kochj@digitalnoise.net (N7M8354PAA)" \
  "/Users/kochj/Applications/MLX Code.app"
```

---

## 📋 Post-Build Checklist

**After every build, archive, and export:**

1. **Re-sign the exported app:**
   ```bash
   codesign --force --deep --sign - \
     "/Volumes/Data/xcode/Binaries/YYYYMMDD-MLXCode-vX.Y.Z/Export/MLX Code.app"
   ```

2. **Copy to Applications:**
   ```bash
   cp -R "/Volumes/Data/xcode/Binaries/YYYYMMDD-MLXCode-vX.Y.Z/Export/MLX Code.app" \
     "/Users/kochj/Applications/"
   ```

3. **Re-sign in Applications:**
   ```bash
   codesign --force --deep --sign - "/Users/kochj/Applications/MLX Code.app"
   ```

4. **Verify:**
   ```bash
   codesign --verify --verbose "/Users/kochj/Applications/MLX Code.app"
   ```

5. **Kill old instances and launch:**
   ```bash
   killall "MLX Code" 2>/dev/null
   open "/Users/kochj/Applications/MLX Code.app"
   ```

---

## 🛠️ Automated Script

Created: `resign_and_install.sh`

**Usage:**
```bash
cd "/Volumes/Data/xcode/MLX Code"
./resign_and_install.sh
```

**What it does:**
1. Finds the latest exported build
2. Re-signs it
3. Copies to ~/Applications
4. Re-signs again
5. Verifies signature
6. Restarts the app

---

## 🔍 Debugging Code Signature Issues

### **Check if signature is valid:**
```bash
codesign --verify --verbose "/Users/kochj/Applications/MLX Code.app"
```

**Expected output:**
```
/Users/kochj/Applications/MLX Code.app: valid on disk
/Users/kochj/Applications/MLX Code.app: satisfies its Designated Requirement
```

### **Check signature details:**
```bash
codesign -dv "/Users/kochj/Applications/MLX Code.app"
```

### **Check entitlements:**
```bash
codesign -d --entitlements - "/Users/kochj/Applications/MLX Code.app"
```

### **View crash logs:**
```bash
log show --predicate 'process == "MLX Code"' --info --last 1h
```

---

## 🚨 When Code Signature Errors Occur

**Symptoms:**
- App crashes immediately on launch
- App crashes when using specific features
- Console shows "Code Signature Invalid"
- Crash report shows `CODESIGNING` termination reason

**Immediate Fix:**
```bash
# Stop the app
killall "MLX Code"

# Re-sign
codesign --force --deep --sign - "/Users/kochj/Applications/MLX Code.app"

# Restart
open "/Users/kochj/Applications/MLX Code.app"
```

---

## 📝 Why This Happens

**macOS Code Signature Validation:**
- macOS validates code signatures to prevent tampering
- When you copy an app, the signature can become invalid
- Modifications to the app bundle invalidate signatures
- Some features (like dynamic library loading) are extra strict

**Development vs Production:**
- **Development:** Ad-hoc signatures work (`--sign -`)
- **Production:** Requires Apple Developer certificate
- **App Store:** Requires distribution certificate

---

## 🔐 Best Practices

### **For Development:**
1. Use ad-hoc signatures (`--sign -`)
2. Re-sign after every copy/move
3. Keep builds in dated folders for tracking
4. Verify signature before launching

### **For Distribution:**
1. Use Apple Developer certificate
2. Notarize the app (required for macOS 10.15+)
3. Create a DMG with properly signed app
4. Test on a clean machine

### **For Testing:**
1. Always test newly built apps
2. Check Console.app for signature errors
3. Use `codesign --verify` before reporting bugs
4. Keep old working builds as backup

---

## 🔄 Build & Install Workflow

### **Complete workflow:**
```bash
# 1. Make code changes
# (edit files in Xcode)

# 2. Build and archive
cd "/Volumes/Data/xcode/MLX Code"
xcodebuild -project "MLX Code.xcodeproj" -scheme "MLX Code" \
  -configuration Release archive \
  -archivePath "/Volumes/Data/xcode/Binaries/$(date +%Y%m%d)-MLXCode-v3.5.4/MLXCode.xcarchive"

# 3. Export
xcodebuild -exportArchive \
  -archivePath "/Volumes/Data/xcode/Binaries/$(date +%Y%m%d)-MLXCode-v3.5.4/MLXCode.xcarchive" \
  -exportPath "/Volumes/Data/xcode/Binaries/$(date +%Y%m%d)-MLXCode-v3.5.4/Export" \
  -exportOptionsPlist "/Volumes/Data/xcode/MLX Code/ExportOptions.plist"

# 4. Re-sign exported app
codesign --force --deep --sign - \
  "/Volumes/Data/xcode/Binaries/$(date +%Y%m%d)-MLXCode-v3.5.4/Export/MLX Code.app"

# 5. Kill old instance
killall "MLX Code" 2>/dev/null

# 6. Install to Applications
rm -rf "/Users/kochj/Applications/MLX Code.app"
cp -R "/Volumes/Data/xcode/Binaries/$(date +%Y%m%d)-MLXCode-v3.5.4/Export/MLX Code.app" \
  "/Users/kochj/Applications/"

# 7. Re-sign in Applications
codesign --force --deep --sign - "/Users/kochj/Applications/MLX Code.app"

# 8. Verify
codesign --verify --verbose "/Users/kochj/Applications/MLX Code.app"

# 9. Launch
open "/Users/kochj/Applications/MLX Code.app"
```

---

## 📊 Version History

- **v3.5.4** (Jan 7, 2026): Fixed FLUX integration, code signing issue resolved
- **v3.5.3** (Jan 6, 2026): Initial FLUX support, code signing issue discovered

---

## 🔗 Resources

- **Apple Developer Code Signing:** https://developer.apple.com/support/code-signing/
- **codesign man page:** `man codesign`
- **Xcode Build Settings:** Project → Target → Signing & Capabilities

---

## ✅ Status

**Current Status:** ✅ RESOLVED

**Last Signed:** January 7, 2026
**Version:** v3.5.4
**Location:** `/Users/kochj/Applications/MLX Code.app`
**Signature:** Valid (Ad-Hoc)

**Verification:**
```
✅ valid on disk
✅ satisfies its Designated Requirement
```

---

**Author:** Jordan Koch
**GitHub:** @kochj23
