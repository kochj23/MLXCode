# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [6.4.0] - 2026-11-06

### Changed
- **mlx-swift-lm 2.30 → 3.32.3** and **mlx-swift 0.30 → 0.32.3** (0.32.3 is the newest mlx-swift that mlx-swift-lm 3.32.3 accepts; it requires `upToNextMinor(0.32.3)`). Migrated per the upstream 3.x upgrade guide: `HubApi`/`defaultHubApi` → `HuggingFace.HubClient`, `loadContainer(hub:)` → `loadContainer(from: URL, using: #huggingFaceTokenizerLoader())`. Added the `MLXHuggingFace`, `HuggingFace` (swift-huggingface 0.13) and `Tokenizers` (swift-transformers 1.4) products
- `Package.resolved` is now committed so every build resolves the same dependency graph
- Default repetition penalty lowered from 1.8 to 1.1; persisted models still carrying the old 1.8 default are migrated on load
- `topK`, `minP` and `repetitionContextSize` are now passed to the sampler (previously only temperature/top-p/penalty were)
- Model catalog refreshed with current mlx-community 4-bit repos supported by mlx-swift-lm 3.x: Qwen3.5 9B (new default), Qwen3-Coder 30B-A3B, Devstral Small 2 24B, Qwen3.6 35B-A3B, Qwen3.6 27B, Gemma 4 E4B, Qwen3.5 2B (Qwen 2.5 7B kept as legacy)
- CI passes `-skipMacroValidation -skipPackagePluginValidation` (required for the MLXHuggingFace macros)

### Added
- **Native tool calling**: ToolRegistry tools are converted to `ToolSpec`s and passed to the chat template; `Generation.toolCall` events (including several per response) are mapped into the existing `<tool>` approval/execution flow. The text `</tool>` parser remains as a fallback
- **KV-cache settings** (Settings → Model): KV quantization none/8-bit/4-bit, max KV size (rotating cache), prefill step size — mapped into `GenerateParameters`
- `InferenceGenerator` protocol + `MLXContainerGenerator`, `GenerationParameterMapper`, `ToolSpecBuilder`, `NativeToolCallFormatter`, `ModelConfigInspector` (new `InferenceEngine.swift`)
- `InferenceEngineTests` and a rewritten `MLXServiceTests` (32 tests, mock generator, no model download) plus an opt-in real-model integration test (`MLXCODE_INTEGRATION=1`)
- Multi-model load balancing: optionally spread each chat across all installed local models (native MLX + Ollama), all frontier models (OpenRouter), and an optional Nova Gateway — health-gated and load-balanced — instead of a single pinned model
- Three independent, persisted toggles in **Settings → Balancer**: All local models, All frontier models (OpenRouter), Nova Gateway (with a configurable gateway URL and Keychain-stored OpenRouter key)
- `ModelRegistry` (model discovery + pool composition), `LoadBalancer` (round-robin / least-busy with health gating), `OpenRouterProvider` / `OpenAICompatibleRequest`, and `KeychainStore` — pure, network-free, unit-tested building blocks ported from AIStudio
- `LLMBalancer` service wiring discovery → health map → balanced dispatch into `ChatViewModel`
- Network-free `LoadBalancerTests` suite (24 tests) covering parsing, pool composition, and selection policies

### Changed
- `ChatViewModel` routes generation through the balancer when any toggle is on; falls back cleanly to the single pinned MLX model when the pool is empty or all toggles are off (existing behavior preserved)

### Fixed
- **Stop now stops generation.** Previously Stop only flipped UI flags while MLXService kept generating to `maxTokens`, so the next request failed with "inference already in progress". Generation now runs in a stored, cancellable Task; MLXService checks cancellation in the stream loop, terminates the mlx-swift-lm token stream, and always resets its busy flag. The agentic tool loop does not continue after Stop, and the load balancer no longer fails over on cancellation
- Repetition/length guards now actually stop the model instead of discarding tokens while generation continues
- Model downloads only fetched `*.safetensors` and `*.json`, silently dropping `chat_template.jinja`, `merges.txt`, `tokenizer.model` etc. Patterns now live in `MLXService.downloadPatterns` and include `*.jinja`, `*.txt`, `*.model`
- Context window is now read from nested `text_config` as well as top-level `config.json` keys (Qwen3.5/3.6, Gemma 4, Devstral 2 previously fell back to 8K); discovered and downloaded models record it too
- `Python/setup.sh`: version specifiers are quoted (unquoted `mlx>=…` was a shell redirect that created the stray `Python/=0.0.10`-style files)

### Removed
- Dead Python inference scripts (`mlx_inference.py`, `mlx_daemon.py`) and the unused `huggingface_downloader.py` / `rag_system.py`, their bundle Resources entries, and the junk `Python/=*` files
- `MLXServiceTests` cases that exercised the removed Python daemon protocol

### Notes
- Nova is never a hard requirement — the balancer works with zero Nova present; the Nova Gateway is one optional, health-probed entry that drops out if unavailable

## [5.0.0] - 2026-02-19

### Removed
- Image generation (DALL-E, Stable Diffusion, FLUX, local SD)
- Video generation
- Voice cloning and TTS (MLX-Audio, Native TTS)
- GitHub panel and GitHub tool
- MCP server tool
- Web fetch tool
- News tool
- Autonomous agent
- Multi-model comparison and multi-model provider
- RAG service
- Cost tracker
- Intent router
- Smart code actions
- Prompt library and prompt template manager
- Performance dashboard, gauges, and token metrics views
- AI Capabilities unified layer (5 files)
- 41 files deleted total (~16,000 lines removed)

### Changed
- Default model changed to Qwen 2.5 7B (from Llama 3.2 3B)
- System prompt rewritten — compact, honest about capabilities (~500 tokens)
- Tool count reduced from 40+ to 11 focused tools
- Few-shot examples rewritten to cover all core tools
- Performance metrics display simplified from gauges to text
- SettingsView simplified (removed image, GitHub tabs)
- Version bumped to 5.0.0 reflecting breaking scope change

### Fixed
- Tool prompt no longer consumes most of the context window
- System prompt no longer claims capabilities that don't work

## [4.0.0] - 2026-02-19

### Added
- Chat template support via Python daemon (ChatML, Llama, Mistral formats)
- Structured message passing (JSON arrays instead of flattened strings)
- Tool tier system (core + development)
- Tool approval flow (auto-approve read-only, ask for write/execute)
- Tool approval UI (inline approve/deny in chat)
- Context budget system with per-model token allocation
- Word-based token estimation (replaces character/4 heuristic)
- Smart context assembly with rule-based compaction
- Project context auto-include (file tree, recent files)
- Context window size detection from model config

### Changed
- maxTokens restored from 512 to 2048
- RepetitionDetector limits increased (16K chars, 4K tokens)

## [1.2.0] - 2026-02-04

### Added
- macOS WidgetKit widget extension (small, medium, large)
- Real-time model status monitoring in widget
- App Group data sharing for widget

## [1.1.0] - 2026-01-27

### Added
- MLX backend via mlx_lm CLI subprocess
- Model auto-detection
- Streaming token generation

## [1.0.0] - 2025-11-18

### Added
- Initial release
- Chat interface with SwiftUI
- Basic code generation
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/MLXCode/releases).*
