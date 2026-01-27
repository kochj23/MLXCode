# MLX Code v1.1.0

**AI-powered coding assistant using Apple MLX for local, private code generation**

Native macOS application leveraging Apple Silicon's Neural Engine for intelligent code assistance without cloud dependencies.

---

## What is MLX Code?

MLX Code is a local LLM-powered coding assistant that bridges Apple's MLX toolkit with development workflows to provide intelligent code assistance, refactoring, documentation generation, and code review—all running locally on your Mac without any cloud dependencies.

**Key Benefits:**
- **100% Local**: All AI processing on your Mac (no cloud, no internet required)
- **Apple Silicon Optimized**: Leverages Neural Engine for fast inference
- **Privacy First**: Your code never leaves your machine
- **Multi-Backend Support**: MLX, Ollama, TinyLLM, and cloud options
- **Real-Time Assistance**: Context-aware code completion and suggestions

**Perfect For:**
- **Privacy-Conscious Developers**: Keep proprietary code local
- **Offline Development**: Work without internet connection
- **Apple Silicon Users**: Maximum performance on M1/M2/M3/M4
- **Code Review**: Automated review with security analysis
- **Documentation**: Auto-generate comprehensive docs

---

## What's New in v1.1.0 (January 2026)

### 🚀 MLX Backend Implementation
**Full MLX integration via mlx_lm CLI:**

- **Process Management**: Subprocess handling with proper output/error pipes
- **Model Support**: mlx-community models (Llama-3.2-3B-Instruct-4bit, Mistral, Phi, etc.)
- **Streaming**: Real-time token generation
- **Error Handling**: Graceful fallback if MLX not installed
- **Auto-Detection**: Checks for mlx_lm availability automatically
- **Neural Engine**: Leverages Apple Silicon for fast inference

**Installation:**
```bash
# Install MLX LM
pip install mlx-lm

# Verify installation
which mlx_lm.generate

# MLX Code auto-detects and uses it
```

**Technical Implementation:**
```swift
private func generateWithMLX(prompt: String, maxTokens: Int) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mlx_lm.generate")
    process.arguments = [
        "--model", "mlx-community/Llama-3.2-3B-Instruct-4bit",
        "--prompt", prompt,
        "--max-tokens", "\(maxTokens)"
    ]

    // Capture output and return
}
```

---

## Features

### Core Functionality
- **Code Generation**: Generate functions, classes, algorithms from descriptions
- **Code Completion**: Context-aware suggestions as you type
- **Refactoring**: Automated code improvement and optimization
- **Documentation**: Auto-generate docstrings and comments
- **Code Review**: Security analysis and best practices checking
- **Bug Detection**: Identify potential issues before runtime
- **Test Generation**: Create unit tests automatically
- **Code Explanation**: Natural language explanations of complex code

### AI Backend Support (10 Backends)
- **MLX (v1.1.0)**: Apple Silicon native, 100% local
- **Ollama**: Local, free, multiple models
- **TinyLLM/TinyChat**: Lightweight alternatives
- **OpenWebUI**: Self-hosted option
- **OpenAI**: GPT-4 (cloud, paid)
- **Google Cloud AI**: Vertex AI (cloud, paid)
- **Azure Cognitive**: OpenAI service (cloud, paid)
- **AWS Bedrock**: Claude, Llama (cloud, paid)
- **IBM Watson**: Enterprise AI (cloud, paid)

### Developer Features
- **Multi-File Operations**: Refactor across entire codebase
- **Git Integration**: AI-powered commit messages and PR descriptions
- **Codebase Indexing**: Semantic search across project
- **Context Analysis**: Understands project structure
- **Slash Commands**: Quick actions (/refactor, /test, /doc, /review)
- **Autonomous Agent**: Multi-step task execution with planning
- **Cost Tracking**: Token usage and cost estimation (cloud backends)

### Code Intelligence
- **Syntax Highlighting**: All major languages supported
- **Code Diff View**: Before/after comparison
- **Interactive Prompts**: Clarifying questions when needed
- **Undo Support**: Revert AI changes easily
- **Security Validation**: Input sanitization and output verification

---

## Security

### Privacy & Data Protection
- **Local-First**: MLX and Ollama keep all code on your Mac
- **No Telemetry**: Zero analytics or tracking
- **Sandboxed**: App runs in macOS sandbox
- **Keychain Storage**: Cloud API keys stored securely
- **Code Sanitization**: AI outputs validated before application

### Ethical AI Guardian
- **Content Monitoring**: Prevents generation of malicious code
- **Pattern Detection**: Identifies harmful patterns (malware, exploits)
- **Automatic Blocking**: Stops prohibited use cases
- **Audit Logging**: All operations logged (hashed, not plaintext)

### Best Practices
- Use MLX or Ollama for maximum privacy
- Store cloud API keys in Keychain (not code)
- Review all AI-generated code before committing
- Keep models updated for latest security patches
- Enable audit logging for compliance

---

## Requirements

### System Requirements
- **macOS 13.0 (Ventura) or later**
- **Architecture**: Universal (Apple Silicon recommended for MLX)
- **Xcode 15.0+** (for building from source)

### AI Backend Requirements
**For MLX (Recommended):**
- Apple Silicon Mac (M1/M2/M3/M4)
- Python 3.9+
- mlx-lm package: `pip install mlx-lm`
- 8GB+ RAM (16GB recommended)

**For Ollama:**
- Any Mac (Intel or Apple Silicon)
- Ollama installed: `brew install ollama`
- 8GB+ RAM

**For Cloud AI:**
- API keys for chosen provider
- Internet connection
- Budget for API costs

### Dependencies
**Built-in:**
- SwiftUI (UI)
- Foundation (core)
- AppKit (macOS integration)

**Optional:**
- mlx-lm (for MLX backend)
- Ollama (for Ollama backend)

---

## Installation

### Option 1: Pre-built Binary

```bash
open "/Volumes/Data/xcode/binaries/20260127-MLXCode-v1.1.0/MLXCode-v1.1.0-build2.dmg"
```

Drag to Applications folder and launch.

### Option 2: Build from Source

```bash
# Clone repository
git clone https://github.com/kochj23/MLXCode.git
cd MLXCode

# Open in Xcode
open "MLX Code.xcodeproj"

# Build and run (⌘R)
```

### Setup MLX Backend

```bash
# Install MLX LM
pip install mlx-lm

# Verify installation
which mlx_lm.generate

# Download a model (optional, auto-downloads on first use)
mlx_lm.download --model mlx-community/Llama-3.2-3B-Instruct-4bit
```

### Setup Ollama Backend

```bash
# Install Ollama
brew install ollama

# Start Ollama server
ollama serve

# Pull a model
ollama pull mistral:latest
# or
ollama pull codellama:latest
```

---

## Configuration

### First Launch

1. **Launch MLX Code**
2. **Acknowledge Ethical AI Terms**
3. **Select AI Backend**: Settings → AI Backend
   - Choose MLX (local, Apple Silicon only)
   - Or Ollama (local, any Mac)
   - Or cloud provider
4. **Test Connection**: Verify backend responds
5. **Start Coding**: Begin using AI assistance

### Backend Configuration

**MLX Setup:**
- Model: mlx-community/Llama-3.2-3B-Instruct-4bit (default)
- Max Tokens: 2048
- Temperature: 0.7
- Auto-detected if installed

**Ollama Setup:**
- Server URL: http://localhost:11434 (default)
- Model: mistral:latest or codellama:latest
- Automatically connects if Ollama running

**Cloud AI Setup:**
- Enter API key in Settings
- Select specific model
- Set token limits and budget

---

## Usage

### Code Generation

```
Prompt: "Create a function to check if a number is prime"

MLX Code generates:
func isPrime(_ n: Int) -> Bool {
    guard n > 1 else { return false }
    guard n != 2 else { return true }
    guard n % 2 != 0 else { return false }

    let sqrtN = Int(Double(n).squareRoot())
    for i in stride(from: 3, through: sqrtN, by: 2) {
        if n % i == 0 { return false }
    }
    return true
}
```

### Slash Commands

- `/refactor` - Improve code structure
- `/test` - Generate unit tests
- `/doc` - Add documentation
- `/review` - Security and best practices review
- `/explain` - Explain code in plain English
- `/optimize` - Performance improvements

### Context-Aware Assistance

MLX Code understands your project:
- Reads codebase structure
- Maintains conversation context
- Suggests consistent patterns
- Respects your code style

---

## Troubleshooting

**MLX Not Found:**
- Install: `pip install mlx-lm`
- Verify: `which mlx_lm.generate`
- Check PATH includes /opt/homebrew/bin

**Slow Performance:**
- Use smaller models (3B vs 7B)
- Reduce max tokens
- Close other apps
- Check Activity Monitor

**Out of Memory:**
- Use 3B models instead of 7B+
- Reduce token limit
- Close browser tabs
- Restart Mac

**Ollama Connection Failed:**
- Start server: `ollama serve`
- Check port 11434 not blocked
- Verify localhost access

---

## Version History

### v1.1.0 (January 2026)
- MLX backend implementation
- Process-based mlx_lm integration
- Model auto-detection
- Streaming support

### v1.0.0 (2025)
- Initial release
- Ollama support
- Cloud AI support
- Code generation features

---

## License

MIT License - Copyright © 2026 Jordan Koch

---

**Last Updated:** January 27, 2026
**Status:** ✅ Production Ready
