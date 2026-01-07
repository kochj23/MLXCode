# MLX Code - Complete Capabilities Reference

**Version:** 3.7.0
**Author:** Jordan Koch
**Platform:** macOS (Apple Silicon optimized)

This file provides a complete reference of MLX Code's capabilities for the local LLM to understand what it can do.

---

## 📋 COMPLETE FEATURE LIST

### 1. LANGUAGE MODEL (LLM) CHAT
- 9 pre-configured models (Qwen 2.5 7B, Mistral 7B, CodeLlama, DeepSeek Coder, etc.)
- Download models from Hugging Face
- Load/unload models
- Streaming responses
- Token counting
- Model parameters (temperature, max tokens, etc.)

### 2. IMAGE GENERATION (LOCAL, FREE)
- 5 built-in models: SDXL-Turbo, SD 2.1, FLUX, SDXL Base, SD 1.5
- Add custom Stable Diffusion models from Hugging Face
- 3 quality presets: Fast (4 steps), Balanced (20 steps), High (50 steps)
- Real-time progress tracking
- Auto-opens in Preview
- 2-30 second generation time
- SafeTensors only (secure)

### 3. VIDEO GENERATION (LOCAL, FREE)
- Image sequence method (30-120 frames)
- FFmpeg combines frames to MP4
- Progress tracking per frame
- Quality settings apply to all frames
- 24/30/60 FPS output
- 1-15 minute generation time
- Auto-opens in QuickTime

### 4. SPEECH & AUDIO
- Native macOS TTS (40+ languages, instant)
- MLX-Audio TTS (7 high-quality models)
- Voice cloning (F5-TTS) from 5-10 second samples
- Multiple voices per model
- Speed control
- Save to file support

### 5. DEVELOPMENT TOOLS
- Xcode integration (build, test, analyze)
- Git operations (commits, branches, diffs)
- GitHub CLI integration (PRs, issues)
- File operations (read, write, search, edit)
- Bash command execution
- Code templates (20 built-in)
- Error diagnosis
- Test generation
- Code refactoring

### 6. ADVANCED FEATURES
- RAG/Vector DB (ChromaDB)
- Web fetching
- News aggregation
- Context memory
- Multi-file operations
- Code navigation
- Keyboard shortcuts
- Command palette

### 7. NO LLM REQUIRED FOR:
- Image generation (purple button)
- Video generation (purple button)
- Speech synthesis (purple button)
- Bash commands
- File operations

---

## 🎯 WHAT MLX CODE IS

MLX Code is a **macOS native AI development assistant** with:
- Local LLM inference via Apple's MLX framework
- Local image/video generation via Stable Diffusion
- Local speech synthesis via MLX-Audio
- Xcode and Git integration
- 100% private, free, and local operation

**NOT:**
- A cloud service
- A web app
- A generic chatbot

**IS:**
- A development tool for macOS
- An AI-powered code assistant
- A local media generation studio
- A secure, private AI environment

---

## 📊 PERFORMANCE (M3 Ultra)

- Images: 2-30 seconds
- Videos: 1-15 minutes
- Speech: Instant to 3 seconds
- LLM responses: Fast, streaming
- All running locally on device

---

## 💾 STORAGE

- LLM models: ~4GB each
- Image models: 4-24GB
- Speech models: ~2-4GB
- Total: ~20-50GB depending on what's installed

---

## 🔐 SECURITY

- SafeTensors models only
- No pickle files
- Input validation
- Sandbox compliant
- Audit logging
- No telemetry

---

When asked about capabilities, reference this document.
