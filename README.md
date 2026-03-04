# MLX Code v6.2.0

![Build](https://github.com/kochj23/MLXCode/actions/workflows/build.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**Local AI coding assistant for macOS, powered by Apple MLX (Machine Learning eXtensions).**

MLX Code runs language models directly on your Mac using Apple Silicon. No cloud, no API keys, no subscriptions. Your code stays on your machine.

---

## What It Does

MLX Code is a chat-based coding assistant with tool calling. You describe what you need, and the model reads files, searches code, runs commands, and builds your project — all locally.

**14 built-in tools:**

| Tool | What it does |
|------|-------------|
| **File Operations** | Read, write, edit, list, delete files |
| **Bash** | Run shell commands |
| **Grep** | Search file contents with regex |
| **Glob** | Find files by pattern |
| **Xcode** | Build, test, clean, archive, full deploy pipeline |
| **Git** | Status, diff, commit, branch, log, push, pull |
| **GitHub** | Issues, PRs (Pull Requests), branches, credential scanning |
| **Code Navigation** | Jump to definitions, find symbols |
| **Code Analysis** | Metrics, dependencies, lint, symbols, full analysis |
| **Error Diagnosis** | Analyze and explain build errors |
| **Test Generation** | Create unit tests from source files |
| **Diff Preview** | Show before/after file changes |
| **Context Analysis** | Analyze project structure and dependencies |
| **Help** | List available commands and usage |

**Slash commands:** `/commit`, `/review`, `/test`, `/docs`, `/refactor`, `/explain`, `/optimize`, `/fix`, `/search`, `/plan`, `/help`, `/clear`

---

## How It Works

1. You type a message (e.g., "Find all TODO comments in the project")
2. The model generates a tool call: `<tool>{"name": "grep", "args": {"pattern": "TODO", "path": "."}}</tool>`
3. MLX Code executes the tool and feeds results back to the model
4. The model responds with findings or takes the next action

Read-only tools (grep, glob, file read, code navigation) auto-approve. Write/execute tools (bash, file write, xcode build) ask for confirmation.

---

## What's New in v6.2.0 (March 2026)

### Native MLX Swift — Python No Longer Required for Inference

The biggest change since v1.0: inference now runs entirely in Swift using `mlx-swift-lm`. The Python daemon subprocess has been removed.

**What changed:**
- **No Python for inference** — `mlx_daemon.py` is gone. Models load and run natively via `LLMModelFactory` + `ModelContainer`
- **Faster startup** — no subprocess spawn, no pipe handshake, no JSON-RPC overhead
- **Cleaner streaming** — tokens delivered via `AsyncStream<Generation>`, tokenizer chat templates applied natively
- **Python still used for downloads only** — `huggingface_downloader.py` runs once when you first pull a model
- **2,726 lines of dead code removed** — `EthicalAIGuardian`, `AIBackendStatusMenu`, and all 4 `AIBackendManager` files deleted (none were called by the live app)
- **Code quality cleanup** — removed debug file writes from production, fixed force unwraps, replaced polling sleeps with proper event handling

---

## Features

### Xcode Integration
- Build, test, clean, archive from chat
- Full deploy pipeline: version bump, build, archive, DMG (Disk Image), install
- Error diagnosis with context-aware analysis
- GitHub integration: issues, PRs, branches, credential scanning
- Code analysis: metrics, dependencies, linting, symbol inspection

### User Memories
- Persistent preferences that shape assistant behavior
- 50+ built-in coding standards across 8 categories
- Custom memories stored locally (~/.mlxcode/memories.json)
- Categories: personality, code quality, security, Xcode, git, testing, docs, deployment
- User-specific settings (name, paths) injected at runtime — never hardcoded

### Context Management
- Token budgeting with automatic message compaction
- Project context auto-include when workspace is open
- Two tool tiers: core (always available) and development (when project is open)

---

## Models

MLX Code uses [mlx-community](https://huggingface.co/mlx-community) models from Hugging Face, quantized for Apple Silicon.

**Recommended:**

| Model | Size | Context | Best for |
|-------|------|---------|----------|
| **Qwen 2.5 7B** (default) | ~4 GB | 32K | General coding, tool calling |
| Mistral 7B v0.3 | ~4 GB | 32K | Versatile, good at instructions |
| DeepSeek Coder 6.7B | ~4 GB | 16K | Code-specific tasks |
| Qwen 2.5 14B | ~8 GB | 32K | Best quality (needs 16GB+ RAM) |

Models download automatically on first use. You can also add custom models from any mlx-community repo.

---

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1, M2, M3, M4)
- **8 GB RAM** minimum (16 GB recommended for 7B models)
- **Python 3.9+** with `huggingface-hub` installed (only for model downloads)

---

## Installation

### From DMG

Download the latest release from [Releases](https://github.com/kochj23/MLXCode/releases), open the DMG, and drag to Applications.

### From Source

```bash
git clone https://github.com/kochj23/MLXCode.git
cd MLXCode
open "MLX Code.xcodeproj"
# Build and run (Cmd+R)
```

### Python Setup (for model downloads only)

```bash
pip install huggingface-hub
```

MLX Code uses `mlx-swift-lm` natively for inference — no Python required to run the model. Python is only needed to download models from HuggingFace on first use.

---

## Architecture

```
MLX Code (SwiftUI)
  |
  |-- ChatViewModel         # Conversation management, tool execution loop
  |-- MLXService            # Native MLX Swift inference via mlx-swift-lm
  |-- ContextManager        # Token budgeting, message compaction
  |-- ToolRegistry          # 14 registered tools (2 tiers)
  |-- SystemPrompts         # Compact prompt with few-shot examples + user memories
  |-- UserMemories          # Persistent coding standards and preferences
  |
  |-- Services/
  |   |-- GitHubService     # GitHub API: issues, PRs, branches, credentials scan
  |   |-- ContextAnalysis   # Project structure and dependency analysis
  |   `-- UserMemories      # Configurable standards, custom memory persistence
  |
  |-- ViewModels/
  |   |-- ProjectViewModel  # Build operations and project management
  |   |-- GitHubViewModel   # GitHub panel state
  |   `-- CodeAnalysis VM   # Code metrics and analysis state
  |
  `-- Python/huggingface_downloader.py  # Model download from HuggingFace Hub
```

**Key design decisions:**
- Chat templates applied natively by `mlx-swift-lm` tokenizer — no Python required for inference
- Tool prompt is ~500 tokens (not 4000) — leaves room for actual conversation
- Context budget system allocates tokens: system prompt, messages, project context, output reservation
- Two tool tiers: core (always available) and development (when project is open)
- User memories injected at runtime from AppSettings — no personal data in source code

---

## Security

### Shell Execution Safety
- **Command Validation**: All bash commands pass through `CommandValidator` with regex word-boundary matching before execution, blocking dangerous patterns (rm -rf /, fork bombs, etc.)
- **Python Import Validation (v6.1.0)**: Regex-based validation with comment filtering prevents bypass via inline comments
- **No Shell Interpolation**: Git and build tools use `process.currentDirectoryURL` instead of `cd` string interpolation, preventing directory traversal and injection attacks
- **Tool Approval Flow**: Write and execute tools (bash, file write, xcode build) require user confirmation before running
- **Read-Only Auto-Approve**: Only safe, read-only tools (grep, glob, file read) auto-approve without user interaction
- **Permission Checks (v6.1.0)**: File permission validation before script execution in CommandValidator

### Credential Security (v6.1.0)
- **macOS Keychain Storage**: All API keys (OpenAI, Anthropic, Google, AWS, Azure, IBM) stored in macOS Keychain using `SecItemAdd`/`SecItemCopyMatching`
- **Automatic Migration**: Existing UserDefaults-stored keys automatically migrated to Keychain on first launch
- **No Plaintext Secrets**: Non-secret config only (region, model names) stored in UserDefaults

### Model Security (v6.1.0)
- **SHA256 Hash Verification**: Downloaded models verified against expected hashes using CryptoKit
- **Secure Logging**: All debug output routed through `SecureLogger` instead of `print()` — no sensitive data in console

### Data Privacy
- **100% Local**: All model inference runs on-device via Apple MLX -- no data leaves your machine
- **No Telemetry**: No analytics, crash reporting, or usage tracking
- **No API Keys Required**: No cloud services, no subscriptions, no accounts
- **Local Memory Storage**: User memories stored in `~/.mlxcode/memories.json`, never transmitted

### Thread Safety
- **Actor isolation**: `MLXService` is a Swift actor — all model state is automatically serialized
- **Streaming via AsyncStream**: Token generation uses `AsyncStream<Generation>`, delivered to `@MainActor` via `MainActor.run`
- **Task Cancellation**: All background loops use `while !Task.isCancelled` for clean shutdown

---

## What It Doesn't Do

Being honest about limitations:

- **No web browsing** — can't fetch arbitrary URLs or browse the internet (GitHub API is the exception)
- **No image/video/audio generation** — this is a code assistant, not a media tool
- **Small model constraints** — 3-14B parameter models make mistakes, especially with complex multi-step reasoning
- **No IDE integration** — standalone app, not an Xcode plugin (yet)
- **Tool calling is imperfect** — local models sometimes format tool calls incorrectly

---

## Version History

### v6.2.0 (March 4, 2026) — Current
**Native MLX Swift — Python dependency eliminated for inference**

- Replaced Python subprocess daemon (`mlx_daemon.py`) with native `mlx-swift-lm` framework
- Model loading now uses `LLMModelFactory` + `ModelContainer` directly in Swift — no Python process
- Chat generation uses `MLXLMCommon.UserInput` + `AsyncStream<Generation>` for streaming
- Tokenizer chat templates applied natively (Llama, Qwen, Mistral, etc.)
- Python still used only for initial model download (`huggingface_downloader.py`)
- Removed 2,726 lines of dead code: `EthicalAIGuardian`, `AIBackendStatusMenu`, all 4 `AIBackendManager` files
- `mlx_daemon.py` no longer bundled in the app

### v6.1.1 (March 4, 2026)
- Removed dead `ContentView.swift` (deprecated stub, never referenced anywhere)
- Removed dead `MLXSwiftBackend.swift` (class was never instantiated — entire file was unused)
- Removed `handleDirectToolInvocation()` in ChatViewModel, which always returned `false`
- Removed debug code that was writing to `/tmp/mlx_debug.log` on every message send in production
- Fixed force unwrap on `FileManager.urls().first!` in ChatViewModel and ConversationManager
- Replaced bare `print()` with `LogManager` in ConversationManager for consistent error logging
- Stripped ~15 noisy trace-level log calls from `generateResponse()` (per-token logging, emoji-prefixed step tracing)
- Removed redundant inline comments that restated what the adjacent code already said

### v6.1.0 (February 26, 2026)
- Comprehensive security audit: 31 findings resolved (2 CRITICAL, 8 HIGH, 10 MEDIUM, 9 LOW, 1 INFO)
- API keys migrated from UserDefaults to macOS Keychain with automatic migration
- Command validator hardened with NSRegularExpression word-boundary matching
- Python import validator hardened with regex matching and comment filtering
- SHA256 model hash verification using CryptoKit
- Buffered 4096-byte I/O replacing byte-by-byte daemon communication
- Task cancellation (`while !Task.isCancelled`) replacing infinite loops
- Bundle-relative paths replacing hardcoded file paths
- Multi-version Python path lookup (3.13 down to 3.9)
- Serial queues for thread-safe MLX service operations
- SecureLogger replacing all `print()` statements
- Async logging via serial queue in CommandValidator
- `localizedCaseInsensitiveContains()` for proper Unicode search
- O(n) context management replacing O(n^2) insert-at-zero pattern
- 1MB file content cap for memory management in codebase indexer
- Implemented Clear Conversations confirmation dialog in Settings
- Force unwrap elimination in MLXService
- NSString cast chains replaced with URL API across 3 files
- Named constants for context budget ratios

### v6.0.0 (February 20, 2026)
- GitHub integration: issues, PRs, branches, credential scanning
- Code analysis: metrics, dependencies, lint, symbols
- Xcode full deploy pipeline: build, archive, DMG, install
- User memories system — persistent coding standards and preferences
- Context analysis service for project structure inspection
- Project dashboard, GitHub panel, code analysis panel, build panel views
- 14 tools (up from 11)

### v5.0.0 (February 2026)
- Major simplification: deleted 41 files (~16,000 lines) of unused features
- Rewrote system prompt to be honest and compact
- Default model: Qwen 2.5 7B
- 11 focused tools

### v4.0.0 (February 2026)
- Phase 1: Chat template support, structured message passing, tool tier system
- Phase 2: Context budget system, smart token estimation, project context auto-include
- Tool approval flow with auto-approve for read-only operations

### v1.x (January-February 2026)
- Initial release with MLX backend
- Desktop widget extension
- Basic chat interface

---

## License

MIT License - Copyright 2026 Jordan Koch

See [LICENSE](LICENSE) for details.

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
