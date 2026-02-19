# MLX Code

![Build](https://github.com/kochj23/MLXCode/actions/workflows/build.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**Local AI coding assistant for macOS, powered by Apple MLX.**

MLX Code runs language models directly on your Mac using Apple Silicon. No cloud, no API keys, no subscriptions. Your code stays on your machine.

---

## What It Does

MLX Code is a chat-based coding assistant with tool calling. You describe what you need, and the model reads files, searches code, runs commands, and builds your project — all locally.

**11 built-in tools:**

| Tool | What it does |
|------|-------------|
| **File Operations** | Read, write, edit, list, delete files |
| **Bash** | Run shell commands |
| **Grep** | Search file contents with regex |
| **Glob** | Find files by pattern |
| **Xcode** | Build, test, clean Xcode projects |
| **Git** | Status, diff, commit, branch, log |
| **Code Navigation** | Jump to definitions, find symbols |
| **Error Diagnosis** | Analyze and explain build errors |
| **Test Generation** | Create unit tests from source files |
| **Diff Preview** | Show before/after file changes |
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
  |-- ToolRegistry          # 11 registered tools
  |-- SystemPrompts         # Compact prompt with few-shot examples
  |
  `-- Python/mlx_daemon.py  # mlx-lm model loading, chat_generate with templates
```

**Key design decisions:**
- Chat templates applied by the Python tokenizer (not hand-rolled in Swift)
- Tool prompt is ~500 tokens (not 4000) — leaves room for actual conversation
- Context budget system allocates tokens: system prompt, messages, project context, output reservation
- Two tool tiers: core (always available) and development (when project is open)

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

### v5.0.0 (February 2026) — Current
- Major simplification: deleted 41 files (~16,000 lines) of unused features
- Removed image generation, video generation, voice cloning, TTS, GitHub panel, RAG, autonomous agent, multi-model comparison, cost tracker, prompt library, performance dashboard
- Rewrote system prompt to be honest and compact
- Default model: Qwen 2.5 7B
- 11 focused tools instead of 40+

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
