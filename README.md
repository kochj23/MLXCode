# MLX Code

> **Comprehensive AI-powered development assistant for macOS** - Local LLM execution with 26+ integrated tools, multi-backend support, and complete privacy

![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Version](https://img.shields.io/badge/version-1.0-brightgreen)

---

## Overview

**MLX Code** is a feature-rich native macOS application that brings professional AI-assisted development capabilities to your local machine. Built on Apple's MLX framework with support for multiple AI backends (Ollama, TinyLLM, OpenWebUI), it provides Claude Code / Cursor-like functionality while keeping all processing private and local.

### 🎯 Core Philosophy

- **🔒 Privacy First** - All AI processing happens locally, zero cloud dependencies
- **⚡ Apple Silicon Optimized** - Leverages M-series chip capabilities via MLX
- **🔧 Comprehensive Toolset** - 26+ integrated tools for every development task
- **🎨 Multi-Backend Flexibility** - Choose Ollama, MLX, TinyLLM, or OpenWebUI
- **🛡️ Security Focused** - Sandboxed, validated, encrypted

---

## 🚀 Key Features

### AI & Backend Support
- **5 AI Backends:** Ollama, MLX Toolkit, TinyLLM (Jason Cox), TinyChat, OpenWebUI
- **Model Selection:** Choose from dozens of models (deepseek, mistral, llama, codellama, etc.)
- **Real-time Switching:** Change backend/model without restarting
- **Auto-Detection:** Automatically finds available backends
- **Performance Monitoring:** Tokens/sec tracking (optional)

### Code Development Tools (26 Integrated Tools)
1. **File Operations** - Read, write, edit, search files
2. **Bash Execution** - Run terminal commands with timeout
3. **Glob Matching** - Pattern-based file finding (`**/*.swift`)
4. **Grep Search** - Regex search with context
5. **Code Navigation** - Jump to definitions, find references
6. **Xcode Integration** - Build, test, analyze, archive
7. **Advanced Xcode** - Schemes, build settings, configurations
8. **Test Generation** - Auto-generate unit tests
9. **Diff Preview** - Show changes before applying
10. **Git Integration** - Commits, branches, diffs, blame
11. **GitHub Integration** - Issues, PRs, releases, API access
12. **Error Diagnosis** - Analyze compiler errors with fixes
13. **Context Memory** - RAG system for codebase understanding
14. **Help System** - Interactive tool documentation

### AI Content Generation
15. **Image Generation** - AI art via ComfyUI/Automatic1111/SwarmUI
16. **Local Image Gen** - On-device image generation
17. **Video Generation** - AI video creation
18. **Voice Cloning** - Text-to-speech with voice cloning
19. **Native TTS** - macOS text-to-speech
20. **MLX Audio** - Audio processing and generation

### Information & Utilities
21. **Web Fetch** - Fetch and analyze web pages
22. **News Tool** - Real-time news aggregation
23. **MCP Server** - Model Context Protocol support
24. **Tool Registry** - Dynamic tool discovery
25. **System Prompts** - Context-aware system instructions
26. **Claude Code Advanced** - Claude Code feature parity

---

## 📦 Installation

### Prerequisites

**System Requirements:**
- macOS 14.0+ (Sonoma or later)
- Apple Silicon Mac (M1/M2/M3/M4 series)
- 16GB RAM recommended (8GB minimum)
- 50GB free disk space

**Software:**
- Xcode 15.0+
- Command Line Tools (`xcode-select --install`)
- Python 3.10+ (for MLX backend)

### Python Environment (MLX Backend)

```bash
# Create virtual environment
python3 -m venv ~/mlx-env

# Activate
source ~/mlx-env/bin/activate

# Install MLX
pip install mlx mlx-lm numpy transformers

# Verify
python -c "import mlx.core as mx; print('MLX version:', mx.__version__)"
```

### Alternative Backends (Easier Setup)

**Ollama (Recommended):**
```bash
brew install ollama
ollama serve
ollama pull codellama
ollama pull deepseek-coder
```

**TinyLLM by Jason Cox:**
```bash
git clone https://github.com/jasonacox/TinyLLM
cd TinyLLM
docker-compose up -d
```

**OpenWebUI:**
```bash
docker run -d -p 8080:8080 ghcr.io/open-webui/open-webui:main
```

### Building MLX Code

```bash
cd "/Volumes/Data/xcode/MLX Code"
xcodebuild -scheme "MLX Code" -configuration Release build

# Install
cp -R build/Release/MLX\ Code.app ~/Applications/
open ~/Applications/MLX\ Code.app
```

---

## 💡 Usage Guide

### First Launch

1. **Select AI Backend:**
   - Settings (⌘,) → Backend dropdown
   - Choose: Ollama / MLX / TinyLLM / TinyChat / OpenWebUI
   - Green dot = Available, Gray dot = Offline

2. **Select Model** (for Ollama/MLX):
   - Model dropdown appears when backend selected
   - Choose from available models
   - Or add custom model

3. **Start Coding:**
   - Type your request
   - MLX Code uses appropriate tools automatically
   - Results appear in chat

### Example Workflows

**Code Analysis:**
```
"Read MyViewController.swift and explain what it does"
→ FileOperationsTool reads file
→ AI analyzes code structure
→ Provides detailed explanation
```

**Project Building:**
```
"Build the project and fix any warnings"
→ XcodeTool executes build
→ ErrorDiagnosisTool analyzes warnings
→ Suggests fixes with code
→ Can apply fixes automatically
```

**Image Generation:**
```
"Generate an app icon showing a mail envelope"
→ LocalImageGenerationTool creates image
→ Saves to project
→ Shows preview
```

**Git Operations:**
```
"Show me what changed in the last commit"
→ GitIntegrationTool runs git diff
→ DiffPreviewTool formats output
→ Shows side-by-side comparison
```

**Voice Features:**
```
"Read this documentation aloud"
→ NativeTTSTool converts text to speech
→ Plays audio
→ Optional: VoiceCloningTool for custom voices
```

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘N** | New conversation |
| **⌘,** | Settings |
| **⌘R** | Reload conversation |
| **⌘K** | Clear conversation |
| **⌘⌃S** | Toggle sidebar |
| **⌘⌥M** | Change model |
| **⌘⌥B** | Change backend |

---

## 🛠️ Complete Tool Reference

### File & Code Operations

**FileOperationsTool**
- Read, write, edit files
- Multi-file operations
- Backup before modifications
- Undo support

**GlobTool**
- Pattern matching (`**/*.swift`, `**/Tests/*.m`)
- Recursive directory search
- Fast file discovery

**GrepTool**
- Regex search with context
- Case-sensitive/insensitive
- Multi-file search
- Line number display

**CodeNavigationTool**
- Jump to definition
- Find references
- Symbol search
- LSP integration

**DiffPreviewTool**
- Show changes before applying
- Side-by-side comparison
- Accept/reject hunks
- Syntax highlighted

### Build & Development

**XcodeTool**
- Build projects (`xcodebuild`)
- Clean build folder
- Archive for distribution
- Show build settings

**AdvancedXcodeTools**
- Manage schemes
- Build configurations
- Target management
- Project analysis

**TestGenerationTool**
- Generate unit tests automatically
- XCTest framework
- Code coverage
- Test templates

**ErrorDiagnosisTool**
- Parse compiler errors
- Suggest fixes
- Show error context
- Auto-fix common issues

### Version Control

**GitIntegrationTool**
- Commits, branches, tags
- Git diff, log, blame
- Stash, rebase, merge
- Status checking

**GitHubTool**
- Create/manage issues
- Pull requests
- Releases
- API integration
- Repository management

### AI Content Creation

**LocalImageGenerationTool**
- On-device image generation
- Multiple art styles
- Custom prompts
- Batch generation

**ImageGenerationTool**
- External service integration (ComfyUI, Automatic1111, SwarmUI)
- High-quality AI art
- Style presets
- Resolution control

**VideoGenerationTool**
- AI video creation
- Script-to-video
- Animation generation
- Export formats

**VoiceCloningTool**
- Clone voices from samples
- Text-to-speech with cloned voice
- Multiple voice profiles
- High-quality audio

**NativeTTSTool**
- macOS built-in text-to-speech
- Multiple voices
- Speed/pitch control
- Background playback

**MLXAudioTool**
- Audio processing
- Format conversion
- Audio analysis
- Effects

### Information & Integration

**WebFetchTool**
- Fetch web pages
- Extract content
- API calls
- HTML parsing

**NewsTool**
- Real-time news aggregation
- Topic filtering
- Source credibility
- Summarization

**MCPServerTool**
- Model Context Protocol support
- Server management
- Context sharing
- Protocol compliance

**HelpTool**
- Interactive documentation
- Tool discovery
- Usage examples
- Keyboard shortcuts

### Advanced Features

**MemorySystem**
- Persistent context memory
- Codebase indexing
- RAG (Retrieval-Augmented Generation)
- Semantic search

**ClaudeCodeAdvancedFeatures**
- Feature parity with Claude Code
- Enterprise capabilities
- Advanced workflows
- Power user features

**SystemPrompts**
- Context-aware instructions
- Role-based prompts
- Dynamic system messages
- Optimization

**ToolRegistry**
- Dynamic tool loading
- Tool discovery
- Capability reporting
- Extensibility

---

## 🎨 UI Features

### Main Interface
- **Chat View** - Clean conversation interface
- **Syntax Highlighting** - Code blocks with theme support
- **File Tree** - Project navigation
- **Model Selector** - Quick model switching
- **Backend Indicator** - Status with green/red dots

### Settings
- **Backend Selection** - Choose AI provider
- **Model Configuration** - Parameters, temperature, tokens
- **Appearance** - Theme, font size, syntax colors
- **Python Setup** - Interpreter path, MLX verification
- **File Permissions** - Grant/revoke directory access
- **Performance** - Monitoring, optimization options

### Design
- **Modern** - SwiftUI with glass card effects
- **Responsive** - Adaptive layouts
- **Dark Mode** - Full support
- **Icons** - SF Symbols throughout
- **Animations** - Smooth transitions

---

## 🔧 Configuration

### AI Backend Settings

**Ollama Configuration:**
- Server URL (localhost:11434)
- Model selection from installed models
- Pull new models from Ollama library

**MLX Configuration:**
- Python interpreter path
- MLX library verification
- Model directory configuration
- Memory optimization

**TinyLLM/TinyChat Configuration:**
- Server URL (localhost:8000)
- OpenAI-compatible API
- Docker container management

**OpenWebUI Configuration:**
- Server URL (localhost:8080 or 3000)
- Multi-modal support
- Web interface integration

### Model Parameters

| Parameter | Range | Default | Purpose |
|-----------|-------|---------|---------|
| Temperature | 0.0-2.0 | 0.7 | Creativity vs consistency |
| Max Tokens | 128-8192 | 2048 | Response length |
| Top-p | 0.0-1.0 | 0.9 | Sampling diversity |
| Top-k | 1-100 | 40 | Token selection |

---

## 📊 Backend Comparison

| Backend | Speed | Setup | Resource | Best For |
|---------|-------|-------|----------|----------|
| **Ollama** | ⚡⚡⚡ Fast | ✅ Easy | Medium | Quick start, many models |
| **MLX** | ⚡⚡ Fast | 🔧 Moderate | Medium | Apple Silicon optimization |
| **TinyLLM** | ⚡ Medium | ✅✅ Easiest | Low | Lightweight, Docker |
| **TinyChat** | ⚡ Medium | ✅✅ Easiest | Low | Chat-focused |
| **OpenWebUI** | ⚡⚡ Fast | ✅ Easy | Low | Web interface, multi-model |

**Recommendation:** Start with **Ollama** for easiest setup and best model selection.

---

## 🔒 Security & Privacy

### Security Features

1. **App Sandboxing** - macOS sandbox with limited permissions
2. **Input Validation** - All user input sanitized
3. **Command Injection Protection** - Subprocess arguments escaped
4. **Path Traversal Prevention** - File operations validated
5. **Secure Logging** - Sensitive data redacted
6. **Encrypted Storage** - Settings stored in Keychain

### Privacy Guarantees

✅ **100% Local Processing** - No cloud AI services
✅ **No Telemetry** - No usage analytics collected
✅ **No Network Calls** - Except for optional web fetch/GitHub tools
✅ **Data Stays Local** - Code never leaves your Mac
✅ **Open Source Friendly** - Review all code, no hidden behavior

### Best Practices

- ✅ Review AI-generated code before executing
- ✅ Use file permissions to restrict access
- ✅ Keep Python/AI backend updated
- ✅ Audit model sources before downloading
- ✅ Enable logging to track operations
- ❌ Don't store API keys in conversations
- ❌ Don't grant unrestricted file access
- ❌ Don't run untrusted generated scripts

---

## 📋 Complete Feature List

### Code Intelligence
- File reading/writing/editing
- Multi-file operations
- Pattern matching (glob)
- Regex search (grep)
- Code navigation (LSP)
- Syntax highlighting
- Diff preview
- Auto-formatting

### Build & Test
- Xcode project building
- Scheme management
- Test execution
- Test generation
- Coverage reports
- Build settings analysis
- Clean operations
- Archive/export

### Version Control
- Git operations (commit, push, pull, etc.)
- GitHub integration (issues, PRs, releases)
- Diff viewing
- Blame annotations
- Branch management
- Stash operations

### AI Content Creation
- Image generation (local + remote)
- Video generation
- Voice cloning
- Text-to-speech
- Audio processing
- Art style presets

### Information & Web
- Web page fetching
- News aggregation
- API integration
- Content extraction
- HTML parsing

### Development Workflow
- Error diagnosis with fixes
- Context memory (RAG)
- Tool help system
- Bash scripting
- MCP server support

---

## 🎓 Advanced Usage

### Multi-File Refactoring

```
"Rename all instances of UserManager to AccountManager across the project"
→ GlobTool finds all files
→ GrepTool locates occurrences
→ FileOperationsTool edits each file
→ DiffPreviewTool shows changes
→ You approve
→ Changes applied
```

### Test-Driven Development

```
"Generate tests for AuthenticationService"
→ FileOperationsTool reads AuthenticationService.swift
→ TestGenerationTool creates test cases
→ XcodeTool runs tests
→ Shows results with coverage
```

### GitHub Workflow

```
"Create a GitHub release for v1.2.0"
→ GitHubTool creates release
→ Uploads artifacts
→ Generates release notes
→ Tags repository
```

### Image Generation

```
"Generate app icon: gradient background, code symbol"
→ LocalImageGenerationTool generates image
→ Multiple variations
→ Exports at different sizes
→ Ready for Assets.xcassets
```

### Voice Features

```
"Read this README aloud in a professional voice"
→ VoiceCloningTool or NativeTTSTool
→ Converts text to speech
→ Plays audio
→ Can save to file
```

---

## 🏗️ Architecture

### Technology Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (declarative UI)
- **ML Framework:** MLX via Python subprocess
- **Pattern:** MVVM with Combine reactive
- **Backends:** Ollama, MLX, TinyLLM, TinyChat, OpenWebUI
- **Tools:** 26 integrated tool classes
- **Storage:** UserDefaults + Keychain
- **Security:** App Sandbox + Hardened Runtime

### Project Structure

```
MLX Code/
├── MLX Code/
│   ├── MLXCodeApp.swift              # App entry point
│   ├── Models/
│   │   ├── Message.swift             # Chat messages
│   │   ├── Conversation.swift        # Threads
│   │   ├── AppSettings.swift         # Settings + AI backend
│   │   └── MLXModel.swift            # Model configurations
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift       # Main chat logic
│   │   └── ChatViewModel+Tools.swift # Tool integration
│   ├── Views/
│   │   ├── ChatView.swift            # Main interface
│   │   ├── MessageRowView.swift      # Message display
│   │   ├── SettingsView.swift        # Settings panel
│   │   ├── ModelSelectorView.swift   # Model picker
│   │   └── BackendSelectorView.swift # Backend chooser
│   ├── Services/
│   │   ├── MLXService.swift          # MLX execution
│   │   ├── PythonService.swift       # Python subprocess
│   │   ├── XcodeService.swift        # Xcode integration
│   │   └── FileService.swift         # File I/O
│   ├── Tools/ (26 tools)
│   │   ├── FileOperationsTool.swift
│   │   ├── BashTool.swift
│   │   ├── XcodeTool.swift
│   │   ├── GitHubTool.swift
│   │   ├── ImageGenerationTool.swift
│   │   ├── VoiceCloningTool.swift
│   │   └── ... (20 more)
│   ├── Utilities/
│   │   ├── AIBackendManager.swift    # Multi-backend support
│   │   ├── SecureLogger.swift        # Logging
│   │   └── SecurityUtils.swift       # Security helpers
│   └── Design/
│       └── ModernDesign.swift        # Glass card UI system
├── MLX Code Tests/                   # Unit tests
└── Documentation/                    # Guides & screenshots
```

---

## 🎯 Tool Categories

### Essential Development (8 tools)
- FileOperationsTool, BashTool, GlobTool, GrepTool
- CodeNavigationTool, DiffPreviewTool, HelpTool, ErrorDiagnosisTool

### Build & Test (3 tools)
- XcodeTool, AdvancedXcodeTools, TestGenerationTool

### Version Control (2 tools)
- GitIntegrationTool, GitHubTool

### AI Content (6 tools)
- LocalImageGenerationTool, ImageGenerationTool, VideoGenerationTool
- VoiceCloningTool, NativeTTSTool, MLXAudioTool

### Information (2 tools)
- WebFetchTool, NewsTool

### Advanced (5 tools)
- ContextMemoryTool, MCPServerTool, SystemPrompts
- ClaudeCodeAdvancedFeatures, ToolRegistry

---

## 🔥 What's New

### Latest Updates

**v1.0 (Current):**
- ✅ 26 integrated tools
- ✅ 5 AI backend support
- ✅ Voice cloning
- ✅ Local image generation
- ✅ Video generation
- ✅ GitHub integration
- ✅ Context memory (RAG)
- ✅ MCP server support

**Recent Additions:**
- Multi-backend switching (Ollama, MLX, TinyLLM, etc.)
- Green dot availability indicators
- Voice cloning tool
- Local image generation
- Video generation
- Enhanced error diagnosis
- Test generation
- Context memory system

---

## 📈 Performance

### Benchmarks (M2 Max, 32GB)

**Model Loading:**
| Model | Load Time | Memory |
|-------|-----------|--------|
| Deepseek Coder 6.7B (4-bit) | ~8s | 6GB |
| CodeLlama 13B (4-bit) | ~15s | 10GB |
| Mistral 7B (4-bit) | ~10s | 7GB |

**Inference Speed:**
| Backend | Tokens/sec | Latency |
|---------|------------|---------|
| Ollama | 40-60 | Low |
| MLX | 35-50 | Low |
| TinyLLM | 20-30 | Low |

**Tool Execution:**
- File operations: <50ms
- Grep search (1000 files): <200ms
- Xcode build: ~30s (project dependent)
- Git operations: <100ms

---

## 🐛 Troubleshooting

### "No AI backend available"
1. Check if Ollama is running: `ollama serve`
2. Or install: `brew install ollama`
3. Pull a model: `ollama pull codellama`
4. Restart MLX Code
5. Check Settings → Backend shows green dot

### "Model won't load" (MLX backend)
1. Verify Python path: Settings → Advanced
2. Check MLX installed: `pip list | grep mlx`
3. Try smaller model
4. Check available memory
5. Use Ollama instead (easier)

### "File operations failing"
1. Grant directory access when prompted
2. Check Settings → File Permissions
3. Add directories manually if needed
4. Verify files aren't locked

### "Xcode build fails"
1. Install Command Line Tools: `xcode-select --install`
2. Set Xcode path: `sudo xcode-select -s /Applications/Xcode.app`
3. Verify xcodebuild works: `xcodebuild -version`
4. Check project is valid

### "Image generation not working"
1. Install ComfyUI/Automatic1111/SwarmUI
2. Or use LocalImageGenerationTool (on-device)
3. Check server URLs in Settings
4. Verify services are running

---

## 💻 System Requirements

### Minimum
- macOS 14.0 (Sonoma)
- Apple Silicon M1
- 8GB RAM
- 20GB free disk
- Python 3.10+ (for MLX)

### Recommended
- macOS 14.0+
- M2 Pro/Max or M3
- 16GB+ RAM
- 50GB+ free disk
- Ollama installed

### Optimal
- macOS 14.0+
- M3 Max/Ultra
- 32GB+ RAM
- 100GB+ SSD
- Multiple AI backends installed

---

## 🤝 Credits

### Third-Party Software

**TinyLLM** by Jason Cox
- Project: https://github.com/jasonacox/TinyLLM
- Lightweight OpenAI-compatible LLM server
- Used as alternative AI backend
- MIT License

**TinyChat** by Jason Cox
- Project: https://github.com/jasonacox/tinychat
- Fast chatbot interface
- Alternative backend option
- MIT License

**MLX Framework** by Apple ml-explore
- Project: https://github.com/ml-explore/mlx
- Apple Silicon ML framework
- Primary backend for local execution
- Apache 2.0 License

**Ollama**
- Project: https://ollama.com
- Easy LLM management
- Popular backend choice
- MIT License

**OpenWebUI**
- Project: https://github.com/open-webui/open-webui
- Self-hosted AI platform
- Web-based interface
- MIT License

### Models
- Deepseek Coder (Deepseek AI)
- CodeLlama (Meta)
- Mistral (Mistral AI)
- Qwen Coder (Alibaba)
- And many more via Ollama

---

## 📝 License

MIT License

---

## 👤 Author

**Jordan Koch**
- GitHub: [@kochj23](https://github.com/kochj23)

### Related Projects
- [URL-Analysis](https://github.com/kochj23/URL-Analysis) - AI web performance tool
- [GTNW](https://github.com/kochj23/GTNW) - Nuclear war strategy game
- [Mail Summary](https://github.com/kochj23/MailSummary) - AI email assistant
- [TopGUI](https://github.com/kochj23/TopGUI) - System monitor
- [MBox Explorer](https://github.com/kochj23/MBox-Explorer) - Email viewer

---

## 🚀 Getting Started (Quick)

**Fastest Way to Start:**

1. **Install Ollama:**
   ```bash
   brew install ollama
   ollama serve
   ollama pull codellama
   ```

2. **Launch MLX Code:**
   ```bash
   open "/Users/kochj/Applications/MLX Code.app"
   ```

3. **Select Backend:**
   - Settings (⌘,)
   - Backend: Ollama
   - Model: codellama
   - Green dot appears = ready!

4. **Start Coding:**
   - Type: "Read my Swift files and explain the architecture"
   - MLX Code analyzes your project
   - Provides insights and suggestions

---

## 📞 Support

**Issues:** Open issue on GitHub
**Questions:** Check Documentation/ folder
**Updates:** Watch repository for releases

---

**MLX Code - The most comprehensive local AI coding assistant for macOS.**

Built with ❤️ for developers who value privacy and local AI processing.

**Last Updated:** January 22, 2026
**Version:** 1.0
**Status:** ✅ Production Ready
