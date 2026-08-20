# MLX Code

![Build](https://github.com/kochj23/MLXCode/actions/workflows/build.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%7C%20M2%20%7C%20M3%20%7C%20M4-silver)
![Tests](https://img.shields.io/badge/tests-618-brightgreen)

A local AI coding assistant for macOS, powered by Apple MLX. No cloud. No subscriptions. No data leaving your machine.

MLX Code runs language models directly on Apple Silicon using the [mlx-swift](https://github.com/ml-explore/mlx-swift) framework. It provides a chat interface with 14 built-in tools that can read files, search code, run shell commands, build Xcode projects, manage Git repos, and interact with GitHub -- all driven by a local model running on your GPU.

Written by Jordan Koch.

---

## Architecture

```mermaid
graph TB
    subgraph Views["SwiftUI Views"]
        ChatView
        SettingsView
        PromptTemplatesView
        GitHubPanelView
        CodeAnalysisPanelView
        OnboardingView
    end

    subgraph ViewModels
        ChatVM["ChatViewModel"]
        ProjectVM["ProjectViewModel"]
        GitHubVM["GitHubViewModel"]
        CodeAnalysisVM["CodeAnalysisViewModel"]
    end

    subgraph Tools["Tool Execution Layer - 14 tools"]
        direction LR
        subgraph Core["Core (always available)"]
            FileOps["File Operations"]
            Bash
            Grep
            Glob
            Edit
        end
        subgraph Dev["Development (project open)"]
            Xcode
            Git
            GitHub
            CodeNav["Code Navigation"]
            CodeAnalysis
            ErrorDiag["Error Diagnosis"]
            TestGen["Test Generation"]
            DiffPreview
            Help
        end
    end

    subgraph Engine["Inference Engine"]
        MLXService["MLXService (actor)"]
        ContextManager["ContextManager (actor)"]
        ContextBudget["70% messages / 20% project / 10% summary"]
        UserMemories["UserMemories (actor)"]
    end

    subgraph Security
        CommandValidator
        ModelSecurityValidator["SafeTensors-only Validator"]
        KeychainManager
        SecureLogger
        RepDetector["RepetitionDetector"]
    end

    subgraph External["Extensions"]
        XcodeExt["Xcode Extension - 5 commands"]
        Widget["Desktop Widget - 3 sizes"]
        NovaAPI["Nova API - port 37422"]
    end

    Views --> ViewModels
    ViewModels --> Tools
    Tools --> Engine
    Engine --> Security
    Views -.-> External
```

### Data Flow

```mermaid
sequenceDiagram
    participant User
    participant ChatView
    participant ChatViewModel
    participant ToolRegistry
    participant MLXService
    participant ContextManager

    User->>ChatView: Type message or slash command
    ChatView->>ChatViewModel: Send message
    ChatViewModel->>ContextManager: Assemble context (budget-aware)
    ContextManager-->>ChatViewModel: System prompt + history + project context
    ChatViewModel->>MLXService: Generate (AsyncStream)
    MLXService-->>ChatViewModel: Stream tokens
    ChatViewModel->>ChatViewModel: Detect tool call in output
    ChatViewModel->>ToolRegistry: Execute tool
    ToolRegistry-->>ChatViewModel: Tool result
    ChatViewModel->>MLXService: Continue generation with result
    MLXService-->>ChatView: Final response
```

---

## Features

### 14 Built-in Tools

| Tool | Purpose | Tier |
|---|---|---|
| **File Operations** | Read, write, edit, list, delete files | Core |
| **Bash** | Run shell commands | Core |
| **Grep** | Search file contents with regex | Core |
| **Glob** | Find files by pattern | Core |
| **Edit** | Apply targeted file edits | Core |
| **Xcode** | Build, test, clean, archive, deploy | Dev |
| **Git** | Status, diff, commit, branch, log, push, pull | Dev |
| **GitHub** | Issues, PRs, branches, credential scanning | Dev |
| **Code Navigation** | Jump to definitions, find symbols | Dev |
| **Code Analysis** | Metrics, dependencies, lint | Dev |
| **Error Diagnosis** | Analyze and explain build errors | Dev |
| **Test Generation** | Create unit tests from source files | Dev |
| **Diff Preview** | Show before/after file changes | Dev |
| **Help** | List available commands and usage | Dev |

Read-only tools auto-approve. Write and execute tools require confirmation.

### Slash Commands

```
/commit    /review    /test      /docs
/refactor  /explain   /optimize  /fix
/search    /plan      /help      /clear
```

### Prompt Engineering Toolkit

15 curated prompt templates across 9 categories (Review, Debug, Generate, Refactor, Test, Document, Security, Performance, Deploy). Browse templates, fill variables, preview rendered prompts, and send -- all in-app.

### Xcode Source Editor Extension

Select code in Xcode and invoke from **Editor > MLX Code**:

- Explain Selection
- Refactor Selection
- Generate Tests
- Fix Issues
- Ask MLX Code (opens with code pre-loaded)

Communicates via shared App Group container and `mlxcode://` URL scheme.

### Desktop Widget (WidgetKit)

Three sizes (small, medium, large) showing model status, token speed, memory usage, and quick-action deep links.

### GitHub Integration

View and create issues, list and create PRs, manage branches, scan for exposed credentials before pushing.

### User Memories

50+ built-in coding standards across 8 categories injected into the system prompt at runtime. Custom memories stored locally.

### Context Management

- Token budgeting: 70% messages, 20% project context, 10% summary
- Automatic message compaction when context fills up
- Real-time context window usage bar synced to model size
- Project context auto-included when a workspace is open

### Syntax Highlighting

Code blocks render with highlighting for Swift, Python, JavaScript, TypeScript, Bash, JSON, and Objective-C.

---

## Models

Uses [mlx-community](https://huggingface.co/mlx-community) models from Hugging Face, quantized for Apple Silicon.

| Model | Size | Context | Best for |
|---|---|---|---|
| **Qwen 2.5 7B** (default) | ~4 GB | 32K | General coding, tool calling |
| Mistral 7B v0.3 | ~4 GB | 32K | Versatile, instructions |
| DeepSeek Coder 6.7B | ~4 GB | 16K | Code-specific tasks |
| Qwen 2.5 14B | ~8 GB | 32K | Best quality (16GB+ RAM) |

Models download automatically via native Hub Swift API. Custom models from any mlx-community repository are supported. All models must be **SafeTensors** format -- PyTorch pickle files are rejected.

---

## Multi-model load balancing

By default MLX Code talks to a single pinned MLX model. Optionally, it can spread each chat across **every** model available to the machine -- all installed local models (native MLX + a local Ollama, if present), all frontier models via an OpenRouter key, and an optional Nova Gateway -- health-gated and load-balanced. This is off by default; when every toggle is off, behavior is exactly as before.

Three independent toggles live in **Settings → Balancer**:

| Toggle | Adds to the pool | Requires |
|---|---|---|
| **All local models** | Every installed SafeTensors MLX model + any models served by a local Ollama | Nothing (Ollama optional) |
| **All frontier models** | Frontier models via OpenRouter | An OpenRouter API key (stored in the Keychain) |
| **Nova Gateway** | One entry that routes to Nova's OpenAI-compatible gateway | Nothing -- **entirely optional** |

**Nova is never a hard requirement.** With zero Nova present the balancer still works over local MLX/Ollama models and/or OpenRouter. The Nova Gateway is just one optional entry: if its health probe (`GET <url>/v1/models`) fails, that entry is marked unavailable and every other model keeps working.

Selection is **health-gated then balanced**: each distinct backend is probed once (MLX = a model is loaded; Ollama = `/api/tags` 200; OpenRouter = a key is present; Nova = `/v1/models` 200), unhealthy models are dropped, and the `LoadBalancer` picks the next model by **least-busy** (fewest in-flight requests) or **round-robin**. A model that fails mid-request is removed and the next healthy one is tried; if the pool is empty it falls back cleanly to the single pinned MLX model.

```mermaid
flowchart TB
    subgraph Discovery["Discovery (ModelRegistry, network-free parsing)"]
        MLXd["Local MLX models<br/>MLXService.discoverModels()"]
        Ollama["Ollama /api/tags"]
        OR["OpenRouter /models"]
        Nova["Nova Gateway entry"]
    end

    subgraph Toggles["AppSettings toggles"]
        T1["useAllLocalModels"]
        T2["enableAllFrontierModels"]
        T3["useNovaGateway"]
    end

    MLXd --> Pool
    Ollama --> Pool
    OR --> Pool
    Nova --> Pool
    T1 -.gates.-> Pool
    T2 -.gates.-> Pool
    T3 -.gates.-> Pool

    Pool["assemblePool()<br/>[DiscoveredModel] (deduped)"] --> Health["healthMap()<br/>probe each backend once"]
    Health --> Balancer["LoadBalancer.next()<br/>least-busy / round-robin"]
    Balancer --> Dispatch{"dispatchBalanced"}
    Dispatch -->|mlx| InProc["MLXService.chatCompletion<br/>(in-process, streamed)"]
    Dispatch -->|ollama / openRouter / novaGateway| HTTP["OpenAI-compatible POST"]
    Dispatch -->|all fail / empty pool| Fallback["Single pinned MLX model"]
```

Implemented by `ModelRegistry` / `LoadBalancer` / `OpenRouterProvider` / `KeychainStore` (the pure, network-free, unit-tested pieces) wired together by `LLMBalancer` and invoked from `ChatViewModel`. Covered by the network-free `LoadBalancerTests` suite.

---

## Nova API Server

Local HTTP API on port **37422** (loopback only).

| Method | Endpoint | Description |
|---|---|---|
| GET | /api/status | App status, model state, uptime |
| GET | /api/ping | Health check |
| GET | /api/conversations | List all conversations |
| POST | /api/chat | Send message, get response |
| GET | /api/model | Current model info |
| POST | /api/model/load | Load a model |
| GET | /api/metrics | Performance metrics (tokens/sec, memory) |
| POST | /api/cancel | Cancel current generation |
| GET | /api/prompts | List prompt templates |
| POST | /api/prompts/render | Render template with variables |

---

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1, M2, M3, M4)
- **8 GB RAM** minimum (16 GB recommended)
- **No Python required** -- inference and downloads are pure Swift
- **Xcode 15+** -- only needed for the Source Editor Extension

## Installation

### From DMG (recommended for most users)

1. Download the latest `.dmg` from [Releases](https://github.com/kochj23/MLXCode/releases).
2. Open it and drag **MLX Code** into your **Applications** folder.
3. Launch it from Applications and download a model from Settings. That's it — no Xcode, no toolchains, nothing else to install.

> **See "MLX Code can't be opened because the developer cannot be verified"?**
> That means you have a build that isn't yet Developer-ID-signed **and** notarized. To open it anyway:
> - **macOS 14 and earlier:** Control-click (right-click) the app → **Open** → **Open**.
> - **macOS 15 (Sequoia) / 26 and later:** double-click it, dismiss the dialog, then open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.
> - Or from Terminal: `xattr -dr com.apple.quarantine "/Applications/MLX Code.app"`
>
> **Notarized releases open with no prompt at all** — maintainers, see [RELEASE.md](RELEASE.md).

### From Source

Requires **Xcode 15 or later**. Because the app bundles **MLX** for on-device LLM inference, the build
compiles Metal GPU shaders, which needs Apple's **Metal Toolchain** — a component recent Xcode versions
no longer ship by default. Install it once:

```bash
xcodebuild -downloadComponent MetalToolchain
# (or in Xcode: Settings → Components → Metal Toolchain → Get)
```

Then build:

```bash
git clone git@github.com:kochj23/MLXCode.git
cd MLXCode
open "MLX Code.xcodeproj"   # Xcode resolves Swift packages on first open (mlx-swift, mlx-swift-examples, …)
# Build & run: Cmd+R (Xcode 15+, macOS 14.0+ target)
```

> Skipping the Metal Toolchain step produces a wall of `CompileMetalFile … cannot execute tool 'metal'
> due to missing Metal Toolchain` errors from the `mlx-swift` dependency. That's the missing component,
> not a problem with the project.

### Enabling the Xcode Extension

1. System Settings > Privacy & Security > Extensions > Xcode Source Editor
2. Enable **MLX Code**
3. Restart Xcode
4. Select code, then Editor > MLX Code

---

## Security

- **100% local inference** -- no prompts or responses leave your machine
- **CommandValidator** blocks dangerous shell patterns (rm -rf, fork bombs, sudo, eval, curl|sh)
- **ModelSecurityValidator** enforces SafeTensors-only, verifies hashes via CryptoKit
- **KeychainManager** stores API keys in macOS Keychain
- **SecureLogger** with category-based logging, no PII in logs
- **RepetitionDetector** breaks inference loops automatically
- No telemetry, analytics, or crash reporting

---

## What It Does Not Do

- No web browsing or URL fetching
- No image/video/audio generation
- Small model constraints (3-14B parameters) mean imperfect multi-step reasoning
- Tool calling from local models is sometimes malformed (JSON auto-repair helps)
- Xcode extension opens a separate window rather than responding inline

---

## Test Suite

618 tests across 27 test files covering models, services, security, context budgeting, build parsing, Keychain, tool registry, JSON repair, prompt templates, and source-level security scanning.

```bash
xcodebuild -project "MLX Code.xcodeproj" -scheme "MLX Code" \
  -destination "platform=macOS" test
```

---

## License

MIT License -- Copyright 2025-2026 Jordan Koch

See [LICENSE](LICENSE) for the full text.

---

Written by Jordan Koch ([@kochj23](https://github.com/kochj23))
