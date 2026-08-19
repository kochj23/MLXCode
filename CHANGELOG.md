# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Multi-model load balancing: optionally spread each chat across all installed local models (native MLX + Ollama), all frontier models (OpenRouter), and an optional Nova Gateway — health-gated and load-balanced — instead of a single pinned model
- Three independent, persisted toggles in **Settings → Balancer**: All local models, All frontier models (OpenRouter), Nova Gateway (with a configurable gateway URL and Keychain-stored OpenRouter key)
- `ModelRegistry` (model discovery + pool composition), `LoadBalancer` (round-robin / least-busy with health gating), `OpenRouterProvider` / `OpenAICompatibleRequest`, and `KeychainStore` — pure, network-free, unit-tested building blocks ported from AIStudio
- `LLMBalancer` service wiring discovery → health map → balanced dispatch into `ChatViewModel`
- Network-free `LoadBalancerTests` suite (24 tests) covering parsing, pool composition, and selection policies

### Changed
- `ChatViewModel` routes generation through the balancer when any toggle is on; falls back cleanly to the single pinned MLX model when the pool is empty or all toggles are off (existing behavior preserved)

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
