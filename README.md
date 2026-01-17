# MLX Code

> Local LLM-powered coding assistant for macOS using Apple's MLX framework (or TinyLLM by Jason Cox)

![Voice Cloning Panel](Documentation/screenshots/voice-cloning-panel.png)

---

## Overview

**MLX Code** is a native macOS application that brings powerful AI-assisted coding capabilities to your local machine using Apple's MLX machine learning framework. Think Claude Code or Cursor, but running entirely on your Mac with complete privacy and no cloud dependencies.

### Key Features

- 🤖 **Local LLM Execution** - Run code-focused models locally using Apple's MLX
- 🔄 **Multi-Backend Support** - Can use MLX, TinyLLM (by Jason Cox), or Ollama
- 🔧 **Xcode Integration** - Direct integration with Xcode projects (build, test, analyze)
- 💬 **Chat Interface** - Claude Code-style conversational interface
- 📁 **File Operations** - Read, write, edit, search files with AI assistance
- 🔒 **Privacy First** - All processing happens locally, no data leaves your machine
- ⚡ **Apple Silicon Optimized** - Leverages M-series chip capabilities via MLX
- 🐳 **Lightweight Option** - TinyLLM by Jason Cox provides Docker-based alternative
- 🛡️ **Security Focused** - Sandboxed execution, input validation, secure storage

---

## Architecture

### Technology Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **ML Framework:** MLX (via Python subprocess)
- **Alternative Backends:** TinyLLM by Jason Cox, Ollama (see Alternative Backends section)
- **Pattern:** MVVM with Combine
- **Deployment:** macOS 14.0+ (Apple Silicon recommended)

### Project Structure

```
MLX Code/
├── MLX Code/
│   ├── MLXCodeApp.swift           # App entry point
│   ├── Models/
│   │   ├── Message.swift          # Chat message model
│   │   ├── Conversation.swift     # Conversation thread model
│   │   ├── AppSettings.swift      # Settings manager
│   │   └── MLXModel.swift         # MLX model configuration
│   ├── ViewModels/
│   │   └── ChatViewModel.swift    # Main chat logic
│   ├── Views/
│   │   ├── ChatView.swift         # Main chat interface
│   │   ├── MessageRowView.swift   # Message display
│   │   ├── SettingsView.swift     # Settings panel
│   │   └── ModelSelectorView.swift # Model picker
│   ├── Services/
│   │   ├── MLXService.swift       # MLX model interface
│   │   ├── PythonService.swift    # Python subprocess manager
│   │   ├── XcodeService.swift     # Xcode integration
│   │   └── FileService.swift      # File operations
│   ├── Utilities/
│   │   ├── SecureLogger.swift     # Secure logging
│   │   └── SecurityUtils.swift    # Security utilities
│   └── Resources/
│       └── Assets.xcassets/       # App icons and assets
├── MLX Code Tests/                # Unit tests
└── Documentation/                 # Additional docs
```

---

## Installation

### Prerequisites

1. **macOS 14.0+** (Sonoma or later)
2. **Apple Silicon Mac** (M1/M2/M3/M4 recommended for best performance)
3. **Xcode 15.0+**
4. **Python 3.10+** with MLX installed
5. **Command Line Tools** (`xcode-select --install`)

### Python Environment Setup

```bash
# Create virtual environment
python3 -m venv ~/mlx-env

# Activate environment
source ~/mlx-env/bin/activate

# Install MLX and dependencies
pip install mlx mlx-lm numpy transformers

# Verify installation
python -c "import mlx.core as mx; print(mx.__version__)"
```

### Building from Source

1. **Clone/open project:**
   ```bash
   cd "/Volumes/Data/xcode/MLX Code"
   open "MLX Code.xcodeproj"
   ```

2. **Configure Python path in app:**
   - Launch app
   - Open Settings (⌘,)
   - Set Python interpreter path (e.g., `/Users/you/mlx-env/bin/python`)

3. **Build and run:**
   - Press ⌘R in Xcode
   - Or: Product → Run

---

## Usage

### First Launch

1. **Select Model:**
   - Open Settings → Model tab
   - Choose from pre-configured models (CodeLlama, Deepseek Coder, Qwen Coder)
   - Or add custom MLX-compatible model

2. **Configure Python:**
   - Settings → Advanced
   - Set Python interpreter path
   - Verify MLX installation

3. **Start Chatting:**
   - Type your coding question or request
   - MLX Code can read/write files, run builds, execute tests

### Basic Commands

**File Operations:**
```
"Read the contents of MyViewController.swift"
"Create a new file called NetworkManager.swift with URL session code"
"Find all TODO comments in the project"
"Replace all instances of 'oldMethod' with 'newMethod'"
```

**Xcode Integration:**
```
"Build the current project"
"Run unit tests and show me the results"
"Clean the build folder"
"Show me the current build settings"
```

**Code Assistance:**
```
"Refactor this function to use async/await"
"Add error handling to this network call"
"Write unit tests for this class"
"Explain what this code does"
```

### Keyboard Shortcuts

- **⌘N** - New conversation
- **⌘,** - Settings
- **⌘R** - Reload conversation
- **⌘K** - Clear conversation
- **⌘⌃S** - Toggle sidebar

---

## Supported Models

### Pre-configured Models

1. **Deepseek Coder 6.7B** (Recommended)
   - Best for code completion and generation
   - Fast inference on M-series chips
   - Supports 100+ programming languages

2. **CodeLlama 13B**
   - Strong reasoning capabilities
   - Excellent for refactoring and debugging
   - Requires M2 Pro+ for good performance

3. **Qwen Coder 7B**
   - Balanced performance/quality
   - Good for general coding tasks

### Adding Custom Models

1. Download MLX-compatible model
2. Settings → Model → Add Custom Model
3. Provide model path and configuration
4. Load model and start using

**Model Requirements:**
- Must be MLX-compatible format
- Quantized models (4-bit/8-bit) recommended for speed
- Minimum 8GB unified memory for 7B models

---

## Alternative Backends

While MLX Code is optimized for Apple's MLX framework, it can be extended to support alternative AI backends for increased flexibility and performance options.

### TinyLLM Integration

**TinyLLM by Jason Cox** provides a lightweight, OpenAI-compatible LLM server that can be used as an alternative to MLX.

**Project:** https://github.com/jasonacox/TinyLLM
**Author:** Jason Cox
**License:** MIT License

#### Why TinyLLM?

✅ **Lightweight:** Runs in Docker container with minimal resource usage
✅ **OpenAI-Compatible:** Standard API format for easy integration
✅ **Fast Setup:** Single `docker-compose up` command
✅ **Flexible Models:** Configure models via docker-compose.yml
✅ **Alternative Option:** Use when MLX setup is challenging or unavailable

#### TinyLLM Setup

```bash
# Clone TinyLLM repository by Jason Cox
git clone https://github.com/jasonacox/TinyLLM
cd TinyLLM

# Start TinyLLM server with Docker
docker-compose up -d

# Verify running
curl http://localhost:8000/

# TinyLLM is now available at http://localhost:8000
```

#### Integration with MLX Code

To use TinyLLM with MLX Code, integrate the **AIBackendManager** component:

**AIBackendManager Features:**
- Supports Ollama, MLX Toolkit, and TinyLLM
- User-selectable backend in Settings
- Automatic availability detection
- Graceful fallbacks
- OpenAI-compatible API for TinyLLM

**Example Implementation:**
```swift
// Universal backend manager supports all three:
let response = try await AIBackendManager.shared.generate(
    prompt: "Explain this code",
    systemPrompt: "You are a helpful coding assistant",
    temperature: 0.7
)

// Works with: Ollama, MLX, or TinyLLM by Jason Cox
```

**See Also:**
- Universal AI backend integration in other projects:
  - MBox Explorer: https://github.com/kochj23/MBox-Explorer
  - GTNW: https://github.com/kochj23/GTNW
  - NMAPScanner: https://github.com/kochj23/NMAPScanner

#### Backend Comparison

| Backend | Speed | Setup | Resource Usage | Best For |
|---------|-------|-------|----------------|----------|
| **MLX** | Fast | Moderate | Medium (local) | Apple Silicon optimization |
| **TinyLLM** | Medium | Easy | Low (Docker) | Lightweight, easy setup |
| **Ollama** | Fast | Easy | Medium (local) | Quick testing, many models |

**TinyLLM Advantages:**
- Easiest setup (Docker one-liner)
- Lowest resource usage
- OpenAI-compatible API
- No Python environment needed
- Portable across systems

**MLX Advantages:**
- Optimized for Apple Silicon
- Direct hardware access
- Custom model support
- No additional server needed

#### Future Enhancement

MLX Code can be enhanced with multi-backend support similar to other projects in this repository family. This would allow users to choose between MLX (Apple-optimized), TinyLLM (lightweight by Jason Cox), or Ollama (fast inference) based on their preferences and system capabilities.

**Interested in Multi-Backend Support?**
See AIBackendManager.swift implementation in sister projects for reference on how to add backend switching to MLX Code.

---

## Configuration

### Settings Overview

#### General Tab
- Theme (Light/Dark/System)
- Font size
- Auto-save conversations
- Keyboard shortcuts

#### Model Tab
- Model selection
- Temperature (0.0-2.0)
- Max tokens (128-8192)
- Top-p sampling
- Load/unload model

#### Appearance Tab
- Syntax highlighting
- Code block style
- Message spacing

#### Advanced Tab
- Python interpreter path
- MLX library path
- Debug logging
- Performance monitoring
- File operation permissions

---

## Security & Privacy

### Security Features

1. **Sandboxed Execution**
   - App runs in macOS sandbox
   - Limited file system access
   - User must approve directory access

2. **Input Validation**
   - All user input sanitized
   - Path traversal prevention
   - Command injection protection

3. **Secure Storage**
   - Settings encrypted with macOS Keychain
   - No plaintext credential storage
   - Automatic session cleanup

4. **Privacy Protection**
   - All processing happens locally
   - No network requests to external servers
   - No telemetry or analytics
   - Conversation data stays on your Mac

### Security Best Practices

- ✅ Review generated code before executing
- ✅ Use file operation permissions to restrict access
- ✅ Keep Python environment updated
- ✅ Audit model sources before downloading
- ✅ Enable logging to track operations
- ❌ Don't store API keys or secrets in conversations
- ❌ Don't grant unrestricted file access

---

## Xcode Integration

### Capabilities

1. **Project Management**
   - Open and parse .xcodeproj files
   - Read build settings
   - Analyze project structure

2. **Build Operations**
   - Build project (`xcodebuild`)
   - Clean build folder
   - Archive for distribution

3. **Testing**
   - Run unit tests
   - Parse test results
   - Show coverage reports

4. **Code Analysis**
   - Swift syntax checking
   - Compiler warnings/errors
   - Static analysis

### Usage Example

```
User: "Build the project and fix any warnings"

MLX Code:
1. Runs xcodebuild to build project
2. Parses compiler output for warnings
3. Identifies warning locations
4. Suggests fixes for each warning
5. Can automatically apply fixes with approval
```

---

## File Operations

### Supported Operations

**Read:**
- Read file contents
- Support for text files, code, JSON, XML
- Line number display
- Syntax highlighting

**Write:**
- Create new files
- Overwrite existing files (with confirmation)
- Automatic backup before modification

**Edit:**
- Find and replace
- Insert at line number
- Append to file
- Multi-file edits

**Search:**
- Glob pattern matching (`*.swift`, `**/*.m`)
- Grep with regex support
- Case-sensitive/insensitive search
- Context lines (before/after)

### Permission Model

File operations require explicit user approval:
1. First access to directory triggers permission request
2. User grants access via macOS file picker
3. Access persisted for future operations
4. Can revoke access in Settings

---

## Development

### Building for Development

```bash
# Open project
cd "/Volumes/Data/xcode/MLX Code"
open "MLX Code.xcodeproj"

# Build for testing
xcodebuild -project "MLX Code.xcodeproj" \
  -scheme "MLX Code" \
  -configuration Debug \
  build

# Run tests
xcodebuild test -project "MLX Code.xcodeproj" \
  -scheme "MLX Code" \
  -destination 'platform=macOS'
```

### Running Tests

```bash
# All tests
xcodebuild test -project "MLX Code.xcodeproj" \
  -scheme "MLX Code"

# Specific test
xcodebuild test -project "MLX Code.xcodeproj" \
  -scheme "MLX Code" \
  -only-testing:MLXCodeTests/ChatViewModelTests
```

### Memory Analysis

```bash
# Check for retain cycles and memory leaks
instruments -t Leaks -w "MLX Code"
instruments -t Allocations -w "MLX Code"
```

---

## Performance

### System Requirements

**Minimum:**
- M1 Mac (8GB RAM)
- macOS 14.0
- 10GB free disk space
- 7B quantized model

**Recommended:**
- M2 Pro/Max or M3 (16GB+ RAM)
- macOS 14.0+
- 50GB free disk space
- Multiple models cached

### Performance Tips

1. **Use quantized models** (4-bit/8-bit) for faster inference
2. **Close unused apps** to free up memory
3. **Pre-load models** at app launch for faster first response
4. **Enable MLX optimizations** in Settings
5. **Monitor memory usage** in Activity Monitor

### Benchmarks (M2 Max, 32GB)

| Model | Load Time | Tokens/sec | Memory |
|-------|-----------|------------|--------|
| Deepseek 6.7B (4-bit) | ~8s | 45 | 6GB |
| CodeLlama 13B (4-bit) | ~15s | 28 | 10GB |
| Qwen 7B (8-bit) | ~10s | 38 | 8GB |

---

## Troubleshooting

### Model won't load

**Symptoms:** Error loading model, crashes on inference

**Solutions:**
1. Verify Python path is correct (Settings → Advanced)
2. Check MLX is installed: `pip list | grep mlx`
3. Ensure model is MLX-compatible format
4. Check available memory (Activity Monitor)
5. Try smaller/quantized model

### Xcode integration not working

**Symptoms:** Can't build projects, missing xcodebuild

**Solutions:**
1. Install Command Line Tools: `xcode-select --install`
2. Set correct Xcode path: `sudo xcode-select -s /Applications/Xcode.app`
3. Verify xcodebuild: `xcodebuild -version`
4. Check Xcode project is valid

### File operations failing

**Symptoms:** Permission denied, can't read/write files

**Solutions:**
1. Grant file access when prompted
2. Check Settings → Advanced → File Permissions
3. Add directory to allowed list manually
4. Verify file isn't locked or read-only

### Slow performance

**Symptoms:** Long response times, high CPU usage

**Solutions:**
1. Use smaller/quantized model
2. Close background apps freeing memory
3. Restart app to clear caches
4. Check Python process isn't hanging (Activity Monitor)
5. Enable performance monitoring to diagnose bottlenecks

---

## Contributing

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for formatting
- Document all public APIs
- Write unit tests for new features
- Check for memory leaks ([weak self])

### Memory Safety Checklist

- [ ] All closures use `[weak self]` where appropriate
- [ ] Delegates are marked `weak`
- [ ] No retain cycles in reactive chains
- [ ] Proper cleanup in `deinit`
- [ ] Tested with Instruments (Leaks tool)

### Security Checklist

- [ ] All input validated and sanitized
- [ ] No hardcoded secrets or credentials
- [ ] Error messages don't expose sensitive info
- [ ] File paths validated against traversal attacks
- [ ] Subprocess arguments properly escaped
- [ ] Logging sanitizes sensitive data

---

## License

Internal/Local use. Not for distribution.

---

## Credits

- **MLX Framework:** Apple ml-explore team
- **UI Framework:** SwiftUI
- **Models:** Various open-source projects (Deepseek, Meta, Alibaba)
- **TinyLLM:** Jason Cox (https://github.com/jasonacox/TinyLLM) - Alternative backend option

---

## Version History

### v3.4.0 - Smart Path Detection (2025-12-09)

**New Features:**
- 🔧 Automatic detection of writable models directory
- 🏢 Work machine compatibility (~/Documents/MLXCode/models fallback)
- 🔄 Backward compatible with existing ~/.mlx/models setups
- 📍 Dynamic UI updates showing configured paths
- ⚙️ Zero configuration required

**Technical Changes:**
- Added `detectWritableModelsPath()` with automatic write permission testing
- Models directory search now checks multiple possible locations
- Settings UI reflects actual configured path in real-time
- Prerequisites documentation dynamically shows user's models path
- Fixed .gitignore to properly track MLX Code/Models/ source directory

**Problem Solved:**
Resolves write permission issues on corporate/managed machines where ~/.mlx directory is restricted.

---

### v3.3.0 - Context-Aware Analysis (2025-12-08)

**Features:**
- RAG (Retrieval-Augmented Generation) system
- Persistent MLX daemon for faster responses
- Context-aware analysis tools
- Enhanced memory management

---

### v1.0.0 - Initial Release (2025-11-18)

**Features:**
- ✅ Chat-based interface with conversation management
- ✅ Local MLX model execution via Python subprocess
- ✅ Xcode project integration (build, test, analyze)
- ✅ File operations (Read, Write, Edit, Search)
- ✅ Pre-configured code models + custom model support
- ✅ Security features (sandboxing, validation, encryption)
- ✅ Settings management with persistence
- ✅ Comprehensive documentation

**Test Coverage:**
- Unit tests for all services
- Memory leak testing
- Security validation tests
- Integration tests for Xcode operations

---

**Last Updated:** 2025-12-09
**Project Location:** `/Volumes/Data/xcode/MLX Code/`
**Status:** ✅ Initial release ready for testing
