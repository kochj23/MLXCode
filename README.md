# MLX Code

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
- **8 GB RAM (Random Access Memory)** minimum (16 GB recommended for 7B models)
- **Python 3.9+** with `mlx-lm` installed

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

### Python Setup

```bash
pip install mlx-lm
```

MLX Code uses a Python daemon (`mlx_daemon.py`) for model inference. It applies the model's native chat template automatically (ChatML for Qwen, Llama format for Llama, etc.).

---

## Architecture

```
MLX Code (SwiftUI)
  |
  |-- ChatViewModel         # Conversation management, tool execution loop
  |-- MLXService            # Talks to Python daemon via stdin/stdout JSON
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
  `-- Python/mlx_daemon.py  # mlx-lm model loading, chat_generate with templates
```

**Key design decisions:**
- Chat templates applied by the Python tokenizer (not hand-rolled in Swift)
- Tool prompt is ~500 tokens (not 4000) — leaves room for actual conversation
- Context budget system allocates tokens: system prompt, messages, project context, output reservation
- Two tool tiers: core (always available) and development (when project is open)
- User memories injected at runtime from AppSettings — no personal data in source code

---

## Security

### Shell Execution Safety
- **Command Validation**: All bash commands pass through `CommandValidator` before execution, blocking dangerous patterns (rm -rf /, fork bombs, etc.)
- **No Shell Interpolation**: Git and build tools use `process.currentDirectoryURL` instead of `cd` string interpolation, preventing directory traversal and injection attacks
- **Tool Approval Flow**: Write and execute tools (bash, file write, xcode build) require user confirmation before running
- **Read-Only Auto-Approve**: Only safe, read-only tools (grep, glob, file read) auto-approve without user interaction

### Data Privacy
- **100% Local**: All model inference runs on-device via Apple MLX -- no data leaves your machine
- **No Telemetry**: No analytics, crash reporting, or usage tracking
- **No API Keys Required**: No cloud services, no subscriptions, no accounts
- **Local Memory Storage**: User memories stored in `~/.mlxcode/memories.json`, never transmitted

---

## What It Doesn't Do

Being honest about limitations:

- **No internet access** — can't browse, fetch URLs, or call APIs
- **No image/video/audio generation** — this is a code assistant, not a media tool
- **Small model constraints** — 3-8B parameter models make mistakes, especially with complex multi-step reasoning
- **No IDE integration** — standalone app, not an Xcode plugin (yet)
- **Tool calling is imperfect** — local models sometimes format tool calls incorrectly

---

## Version History

### v6.0.0 (February 20, 2026) — Current
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
