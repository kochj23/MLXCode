# MLX Code v6.3.0

![Build](https://github.com/kochj23/MLXCode/actions/workflows/build.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**Local AI coding assistant for macOS, powered by Apple MLX (Machine Learning eXtensions).**

MLX Code runs language models directly on your Mac using Apple Silicon. No cloud inference, no subscriptions, no data leaving your machine. Integrates directly into Xcode via a Source Editor Extension.

---

## What It Does

MLX Code is a chat-based coding assistant with tool calling and Xcode integration. You describe what you need, and the model reads files, searches code, runs commands, and builds your project — all locally.

**14 built-in tools:**

| Tool | What it does |
|------|-------------|
| **File Operations** | Read, write, edit, list, delete files |
| **Bash** | Run shell commands |
| **Grep** | Search file contents with regex |
| **Glob** | Find files by pattern |
| **Xcode** | Build, test, clean, archive, full deploy pipeline |
| **Git** | Status, diff, commit, branch, log, push, pull |
| **GitHub** | Issues, PRs, branches, credential scanning (calls GitHub API) |
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

## What's New in v6.3.0 (March 2026)

### Xcode Extension · Native Downloads · Polished UI

**Xcode Source Editor Extension** — MLX Code now lives inside Xcode. Select any code and invoke from the **Editor > MLX Code** menu:
- **Explain Selection** — understand what code does
- **Refactor Selection** — get an improved version
- **Generate Tests** — write unit tests for selected code
- **Fix Issues** — find and fix bugs
- **Ask MLX Code** — open with code pre-loaded, ask anything

**No Python required** — model downloads use the native Hub Swift API. Python is fully eliminated.

**Syntax highlighting** — Code blocks now highlight Swift, Python, JavaScript/TypeScript, Bash, JSON, and Objective-C (keywords, types, strings, comments, numbers).

**Collapsed tool calls** — The raw `<tool>JSON</tool>` message is now a clean "🔧 Called: tool_name" chip. Expand it if you want to see the JSON.

**Accurate context window bar** — Token bar shows real conversation usage against the actual model context window (e.g. 32,768 for Mistral, not a hardcoded 8,192).

**Resume generation** — A **Continue** button appears on the last assistant message after stopping. Click to pick up where it left off.

**Smarter tool calling** — JSON auto-repair fixes common model mistakes. Malformed tool calls retry with a correction prompt rather than silently failing.

**Lower default temperature** — Changed from 0.7 → 0.2 to significantly reduce hallucinations in code analysis tasks.

---

## Features

### Xcode Integration

MLX Code integrates with Xcode at two levels:

**Chat-based tools (built-in):**
- Build, test, clean, archive from chat
- Full deploy pipeline: version bump, build, archive, DMG, install
- Error diagnosis with context-aware analysis
- Code analysis: metrics, dependencies, linting, symbol inspection

**Xcode Source Editor Extension:**
- Select code in Xcode → **Editor > MLX Code** → choose a command
- Five commands: Explain Selection, Refactor Selection, Generate Tests, Fix Issues, Ask MLX Code
- Enable once in System Settings → Privacy & Security → Extensions → Xcode Source Editor

### GitHub Integration

The GitHub tool connects to the GitHub API to:
- View and create issues
- List and create pull requests
- Manage branches
- Scan for exposed credentials before pushing

### User Memories

- Persistent preferences that shape assistant behavior
- 50+ built-in coding standards across 8 categories
- Custom memories stored locally
- Categories: personality, code quality, security, Xcode, git, testing, docs, deployment
- User-specific settings injected at runtime — never hardcoded

### Context Management

- Token budgeting with automatic message compaction
- Real-time context window usage bar (synced to actual model context size)
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

Models download automatically on first use via the native Hub Swift API. You can also add custom models from any mlx-community repo.

---

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1, M2, M3, M4)
- **8 GB RAM** minimum (16 GB recommended for 7B models)
- **No Python required** — inference and downloads are pure Swift
- **Xcode 15+** — only required for the Source Editor Extension feature

---

## Installation

See **[INSTALLATION.md](INSTALLATION.md)** for the full setup guide, including model downloads, enabling the Xcode extension, and troubleshooting.

### Quick Start

1. Download `MLXCode-vX.Y.Z.dmg` from [Releases](https://github.com/kochj23/MLXCode/releases)
2. Drag **MLX Code** to `/Applications`
3. Launch the app → Settings → Models → download a model
4. Load the model and start chatting

---

## Architecture

```
MLX Code (SwiftUI macOS app)
  |
  |-- ChatViewModel         # Conversation management, tool execution loop
  |-- MLXService            # Native MLX Swift inference (mlx-swift-lm actor)
  |-- ContextManager        # Token budgeting, message compaction
  |-- ToolRegistry          # 14 registered tools (2 tiers)
  |-- SystemPrompts         # Compact prompt with tool descriptions + user memories
  |-- XcodeActionHandler    # Handles incoming requests from the Xcode extension
  |
  |-- Services/
  |   |-- GitHubService     # GitHub API: issues, PRs, branches, credential scan
  |   |-- ContextAnalysis   # Project structure and dependency analysis
  |   `-- UserMemories      # Built-in standards + custom memory persistence
  |
  |-- Views/
  |   |-- ChatView          # Main chat UI, input area, context bar
  |   |-- MessageRowView    # Per-message rendering with syntax highlighting
  |   |-- CodeBlockView     # Syntax-highlighted code blocks with copy button
  |   `-- CollapsibleToolResultView  # Collapsed tool call/result chips
  |
  |-- ViewModels/
  |   |-- ProjectViewModel  # Build operations and project management
  |   |-- GitHubViewModel   # GitHub panel state
  |   `-- CodeAnalysisViewModel  # Code metrics and analysis state
  |
  `-- MLX Code Extension/   # Xcode Source Editor Extension (5 commands)
```

**Key design decisions:**
- Inference via `mlx-swift-lm` Swift framework — no Python required
- Chat templates applied natively by the tokenizer; falls back to flat format for unsupported models
- Tool prompt is ~500 tokens (not 4000) — leaves room for actual conversation
- Context budget system allocates tokens: system prompt, messages, project context, output
- Two tool tiers: core (always available) and development (when project is open)
- User memories injected at runtime from AppSettings — no personal data in source code
- Xcode extension communicates via shared App Group container + `mlxcode://` URL scheme

---

## Security

### Shell Execution Safety
- **Command Validation**: All bash commands pass through `CommandValidator` with regex word-boundary matching before execution, blocking dangerous patterns (rm -rf /, fork bombs, etc.)
- **No Shell Interpolation**: Git and build tools use `process.currentDirectoryURL` instead of string interpolation, preventing directory traversal and injection attacks
- **Tool Approval Flow**: Write and execute tools (bash, file write, xcode build) require user confirmation before running
- **Read-Only Auto-Approve**: Only safe, read-only tools (grep, glob, file read) auto-approve without user interaction

### Data Privacy
- **100% Local Inference**: All model inference runs on-device via Apple MLX — no prompts or responses leave your machine
- **No Telemetry**: No analytics, crash reporting, or usage tracking of any kind
- **No Cloud AI**: No OpenAI, Anthropic, or other cloud AI services — the model runs on your GPU
- **GitHub API only**: The only external network calls are to the GitHub API (via the GitHub tool), which you explicitly invoke
- **Local Memory Storage**: User memories stored locally, never transmitted

### Thread Safety
- **Actor isolation**: `MLXService` is a Swift actor — all model state is automatically serialized
- **Streaming via AsyncStream**: Token generation uses `AsyncStream<Generation>`, delivered to `@MainActor` via `MainActor.run`
- **Task Cancellation**: All background loops use `while !Task.isCancelled` for clean shutdown

---

## Roadmap

- **Deeper Xcode integration** — write responses back into the editor buffer without switching apps
- **Structured output** — grammar-constrained generation to guarantee well-formed tool calls from smaller models
- **Streaming download progress** — real-time progress bar for model downloads

---

## What It Doesn't Do

Being honest about limitations:

- **No web browsing** — can't fetch arbitrary URLs or browse the internet
- **No image/video/audio generation** — this is a code assistant, not a media tool
- **Small model constraints** — 3-14B parameter models make mistakes, especially with complex multi-step reasoning
- **Tool calling is imperfect** — local models sometimes format tool calls incorrectly (auto-retry helps but isn't perfect)
- **Extension requires app switch** — the Xcode extension opens MLX Code in a separate window rather than responding inline

---

## Version History

### v6.3.0 build 7 (March 4, 2026) — Current
- **Xcode Source Editor Extension** — 5 commands in Editor > MLX Code menu (Explain, Refactor, Generate Tests, Fix Issues, Ask). Communicates via shared App Group + `mlxcode://` URL scheme
- **Native model downloads** — replaced Python downloader with `Hub.HubApi.snapshot()`. Python fully eliminated
- **Syntax highlighting** — Swift, Python, JS/TS, Bash, JSON, Objective-C in all code blocks
- **Collapsed tool calls** — raw `<tool>` assistant messages show as a compact chip; expand to inspect
- **Accurate context bar** — syncs to model's actual context window on load; tracks conversation totals
- **Resume generation** — Continue button on last assistant message after stopping
- **Tool call reliability** — JSON auto-repair, retry-on-failure loop, stricter system prompt rule
- **Default temperature 0.2** — reduced from 0.7 to cut hallucinations in code analysis
- **Jinja template fallback** — models with unsupported chat templates fall back to flat prompt format
- **Fixed: agentic tool calling loop** — resolved "inference already in progress" error that occurred when the model called a tool and the follow-up generation failed. Root cause was `PythonService.terminate()` being a no-op with native MLX, causing `chatCompletion()` to run until `maxTokens` before returning. Stream now exits immediately when `</tool>` is detected.

### v6.2.0 (March 4, 2026)
- Replaced Python subprocess daemon with native `mlx-swift-lm` framework for inference
- Model loading via `LLMModelFactory` + `ModelContainer` — no Python process
- Chat generation via `MLXLMCommon.UserInput` + `AsyncStream<Generation>`
- Removed 2,726 lines of dead code (`EthicalAIGuardian`, `AIBackendStatusMenu`, all `AIBackendManager` files)

### v6.1.x (March 4, 2026)
- Comprehensive security audit: 31 findings resolved
- API key storage migrated to macOS Keychain
- Dead code removal, debug artifact cleanup, force unwrap fixes
- Consistent logging via SecureLogger throughout

### v6.0.0 (February 20, 2026)
- GitHub integration: issues, PRs, branches, credential scanning
- Code analysis: metrics, dependencies, lint, symbols
- Xcode full deploy pipeline: build, archive, DMG, install
- User memories system — persistent coding standards and preferences
- 14 tools (up from 11)

### v5.0.0 (February 2026)
- Major simplification: deleted 41 files (~16,000 lines) of unused features
- Rewrote system prompt to be compact and honest
- Default model: Qwen 2.5 7B

### v4.0.0 (February 2026)
- Chat template support, structured message passing, tool tier system
- Context budget system, smart token estimation, project context auto-include
- Tool approval flow with auto-approve for read-only operations

### v1.x (January–February 2026)
- Initial release with MLX backend
- Desktop widget extension
- Basic chat interface

---

## License

MIT License — Copyright 2026 Jordan Koch

See [LICENSE](LICENSE) for details.

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
