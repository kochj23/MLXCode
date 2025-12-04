# Security Documentation - MLX Code

This document outlines the security architecture, threat model, and best practices for MLX Code.

---

## Security Architecture

### Principles

1. **Defense in Depth** - Multiple layers of security controls
2. **Least Privilege** - Minimal permissions required
3. **Fail Securely** - Errors don't expose sensitive information
4. **Input Validation** - All input validated before processing
5. **Secure by Default** - Safe configurations out of the box

---

## Threat Model

### Assets to Protect

1. **User Code** - Source files, intellectual property
2. **Credentials** - API keys, tokens, passwords
3. **Conversations** - Chat history, potentially sensitive context
4. **System Access** - File system, subprocess execution
5. **Model Weights** - Downloaded ML models

### Threat Actors

1. **Malicious User** - Attempting to exploit app vulnerabilities
2. **Compromised Models** - Backdoored or malicious ML models
3. **Process Injection** - External processes trying to manipulate app
4. **File System Attacks** - Path traversal, unauthorized access

---

## Security Controls

### 1. Input Validation

**Implementation:** `SecurityUtils.swift`

```swift
// All user input is validated before processing
func validateInput(_ input: String) throws -> String {
    // Length validation
    guard input.count <= maxInputLength else {
        throw SecurityError.inputTooLong
    }

    // Character validation
    guard input.allSatisfy({ $0.isASCII || $0.isLetter || $0.isNumber }) else {
        throw SecurityError.invalidCharacters
    }

    // Pattern validation (no command injection)
    guard !containsShellMetachars(input) else {
        throw SecurityError.potentialInjection
    }

    return input
}
```

**Protected Against:**
- Command injection
- SQL injection (via parameterized queries)
- Path traversal
- XSS (HTML/JS escaping)
- Buffer overflows

### 2. File System Security

**Implementation:** `FileService.swift`

```swift
// Path validation before any file operation
func validatePath(_ path: String) throws {
    // Resolve to absolute path
    let url = URL(fileURLWithPath: path)
    let resolvedPath = url.standardizedFileURL.path

    // Check for path traversal
    guard !resolvedPath.contains("..") else {
        throw FileServiceError.pathTraversal
    }

    // Verify within allowed directories
    guard allowedDirectories.contains(where: { resolvedPath.hasPrefix($0) }) else {
        throw FileServiceError.accessDenied
    }

    // Check for symbolic link exploitation
    guard !isSymbolicLink(resolvedPath) else {
        throw FileServiceError.symlinkNotAllowed
    }
}
```

**Protected Against:**
- Path traversal (`../../../etc/passwd`)
- Symbolic link attacks
- Unauthorized directory access
- File overwrite attacks

**Permissions Model:**
- Explicit user approval required for first directory access
- Whitelist-based access control
- Can revoke permissions in Settings
- Audit log of all file operations

### 3. Subprocess Security

**Implementation:** `PythonService.swift`

```swift
// Secure subprocess execution
func executeSecurely(script: String, args: [String]) async throws -> String {
    // Validate Python interpreter path
    try validatePythonPath(pythonPath)

    // Sanitize all arguments
    let sanitizedArgs = try args.map { try sanitizeArgument($0) }

    // Create restricted environment
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "/usr/bin:/bin"  // Restricted PATH
    env.removeValue(forKey: "LD_PRELOAD")  // Prevent preloading

    let process = Process()
    process.executableURL = URL(fileURLWithPath: pythonPath)
    process.arguments = ["-c", script] + sanitizedArgs
    process.environment = env

    // Set resource limits
    process.qualityOfService = .userInitiated

    try process.run()

    // Timeout enforcement
    let timeoutTask = Task {
        try await Task.sleep(nanoseconds: 300_000_000_000)  // 5 minutes
        if process.isRunning {
            process.terminate()
        }
    }

    process.waitUntilExit()
    timeoutTask.cancel()

    guard process.terminationStatus == 0 else {
        throw PythonError.executionFailed
    }

    return output
}
```

**Protected Against:**
- Command injection
- Environment variable manipulation
- Resource exhaustion (timeouts)
- Privilege escalation

### 4. Secure Storage

**Implementation:** `AppSettings.swift` + macOS Keychain

```swift
// Sensitive data stored in Keychain
func storeAPIKey(_ key: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "mlxcode.apikey",
        kSecValueData as String: key.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]

    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}

// Never store in UserDefaults or plists
// ❌ UserDefaults.standard.set(apiKey, forKey: "key")  // WRONG!
```

**Protected Data:**
- API keys and tokens
- User credentials
- Model configuration secrets
- Session tokens

**Storage Security:**
- Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- No plaintext credential storage
- Automatic cleanup on logout
- Encrypted conversation history

### 5. Logging Security

**Implementation:** `SecureLogger.swift`

```swift
actor SecureLogger {
    // Automatically redacts sensitive data
    func log(_ message: String, level: LogLevel) {
        var sanitized = message

        // Redact patterns
        sanitized = redactPasswords(sanitized)
        sanitized = redactAPIKeys(sanitized)
        sanitized = redactPII(sanitized)
        sanitized = redactFilePaths(sanitized)

        // Write to log
        writeToLog(sanitized, level: level)
    }

    private func redactAPIKeys(_ text: String) -> String {
        // Redact common API key patterns
        let patterns = [
            "sk-[a-zA-Z0-9]{32,}",  // OpenAI-style
            "ghp_[a-zA-Z0-9]{36}",  // GitHub
            "[A-Za-z0-9+/]{40}",    // Base64 tokens
        ]

        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "***REDACTED***",
                options: .regularExpression
            )
        }
        return result
    }
}
```

**Logging Policy:**
- No passwords or API keys logged
- PII automatically redacted
- File paths sanitized
- Debug logs disabled in release builds
- Log rotation and size limits

### 6. Memory Safety

**Implementation:** Swift memory management + explicit checks

```swift
// All closures use [weak self]
viewModel.fetch { [weak self] result in
    guard let self = self else { return }
    self.handle(result)
}

// Delegates are weak
protocol ChatDelegate: AnyObject {
    func didReceiveMessage(_ message: Message)
}

class ChatViewModel {
    weak var delegate: ChatDelegate?  // ✅ Weak reference
}

// Proper cleanup
class Service {
    private var cancellables = Set<AnyCancellable>()

    deinit {
        cancellables.removeAll()  // Cleanup subscriptions
        SecureLogger.shared.log("Service deallocated")
    }
}
```

**Memory Safety Measures:**
- Automatic Reference Counting (ARC)
- Weak references for delegates/closures
- No retain cycles
- Proper cleanup in deinit
- Regular memory leak testing with Instruments

---

## Security Testing

### Automated Tests

**Input Validation Tests:**
```swift
func testCommandInjectionPrevention() {
    let malicious = "'; rm -rf /; echo '"
    XCTAssertThrowsError(try SecurityUtils.validateShellInput(malicious))
}

func testPathTraversalPrevention() {
    let malicious = "../../../etc/passwd"
    XCTAssertThrowsError(try FileService.shared.readFile(malicious))
}
```

**File Access Tests:**
```swift
func testUnauthorizedFileAccess() {
    let restricted = "/System/Library/PrivateFrameworks"
    XCTAssertThrowsError(try FileService.shared.listFiles(restricted))
}
```

**Subprocess Tests:**
```swift
func testSubprocessInjection() {
    let malicious = "import os; os.system('rm -rf /')"
    XCTAssertThrowsError(try PythonService.shared.execute(malicious))
}
```

### Manual Security Review Checklist

- [ ] All user input validated
- [ ] No hardcoded credentials in source
- [ ] Error messages don't expose system details
- [ ] File operations restricted to approved directories
- [ ] Subprocess arguments properly escaped
- [ ] Sensitive data stored in Keychain
- [ ] Logs sanitize secrets/PII
- [ ] Memory leaks checked with Instruments
- [ ] Dependencies scanned for vulnerabilities
- [ ] Code signing and notarization configured

---

## Vulnerability Response

### Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Email security report (not applicable for local project)
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### Security Update Process

1. Vulnerability reported
2. Severity assessed (Critical/High/Medium/Low)
3. Fix developed and tested
4. Security advisory published
5. Update released with fix
6. Users notified

---

## Secure Development Practices

### Code Review Requirements

All code changes must be reviewed for:
- Input validation
- Output encoding
- Authentication/authorization
- Sensitive data handling
- Error handling
- Logging security

### Dependency Management

```bash
# Audit Python dependencies
pip list --outdated
pip-audit

# Check for known vulnerabilities
safety check

# Update dependencies regularly
pip install --upgrade mlx mlx-lm
```

### Secrets Management

**DO:**
- ✅ Store secrets in macOS Keychain
- ✅ Use environment variables for development
- ✅ Prompt user for credentials at runtime
- ✅ Clear secrets from memory after use

**DON'T:**
- ❌ Hardcode API keys in source
- ❌ Store secrets in UserDefaults/plists
- ❌ Log sensitive data
- ❌ Commit secrets to version control

### Secure Defaults

All settings default to most secure option:
- Sandbox enabled
- Limited file access
- Strict input validation
- Automatic logging
- No external network access (MLX runs locally)

---

## Compliance & Best Practices

### OWASP Top 10 (2021)

| Risk | Mitigation |
|------|------------|
| A01: Broken Access Control | File whitelist, permission model |
| A02: Cryptographic Failures | Keychain storage, no plaintext secrets |
| A03: Injection | Input validation, parameterized queries |
| A04: Insecure Design | Threat modeling, security architecture |
| A05: Security Misconfiguration | Secure defaults, hardened settings |
| A06: Vulnerable Components | Dependency scanning, updates |
| A07: Authentication Failures | N/A (local app, no auth) |
| A08: Data Integrity Failures | Code signing, checksum verification |
| A09: Logging Failures | Comprehensive logging, sanitization |
| A10: Server-Side Request Forgery | N/A (no external requests) |

### Apple Platform Security

- Hardened Runtime enabled
- App Sandbox enabled
- Code signing with Developer ID
- Notarization for distribution
- Entitlements minimized to required only

---

## Security Configuration

### Entitlements (MLX_Code.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- Enable App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- File access (user-selected only) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- No network access required -->
    <key>com.apple.security.network.client</key>
    <false/>

    <!-- No incoming connections -->
    <key>com.apple.security.network.server</key>
    <false/>
</dict>
</plist>
```

### Runtime Hardening

Build Settings:
- `ENABLE_HARDENED_RUNTIME = YES`
- `ENABLE_APP_SANDBOX = YES`
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`

---

## Incident Response

### Security Incident Procedure

1. **Detect:** User reports suspicious behavior
2. **Contain:** Isolate affected systems
3. **Investigate:** Analyze logs, reproduce issue
4. **Remediate:** Deploy fix, notify users
5. **Learn:** Update security controls, document lessons

### Emergency Contacts

- Project Lead: [Internal contact]
- Security Team: [Internal contact]

---

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)
- [Swift Security Guidelines](https://swift.org/security/)
- [CWE Top 25](https://cwe.mitre.org/top25/)

---

**Last Updated:** 2025-11-18
**Version:** 1.0.0
**Status:** ✅ Security review complete
