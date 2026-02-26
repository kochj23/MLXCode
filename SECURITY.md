# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 6.1.x   | Yes       |
| < 6.0   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public GitHub issue**
2. Email: kochj23 (via GitHub)
3. Include: description, steps to reproduce, potential impact

We aim to respond within 48 hours and provide a fix within 7 days for critical issues.

## Security Features

- **100% Local Inference**: All AI runs on-device via Apple MLX — no data leaves your machine
- **Keychain Storage**: API keys stored in macOS Keychain, not UserDefaults
- **Command Validation**: Shell commands validated with regex word-boundary matching
- **Python Import Validation**: Regex-based validation prevents code injection
- **SHA256 Model Verification**: Downloaded models verified against expected hashes
- **Secure Logging**: SecureLogger replaces print() — no sensitive data in console
- **No Telemetry**: Zero analytics, crash reporting, or usage tracking

## Best Practices

- Never hardcode API keys or credentials
- Report suspicious behavior immediately
- Keep dependencies updated
- Review all code changes for security implications
