# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
