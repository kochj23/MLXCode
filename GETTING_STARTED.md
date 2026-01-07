# MLX Code - Getting Started Guide

**Version:** 3.4.0
**Date:** January 6, 2026
**Author:** Jordan Koch

---

## 🚀 Quick Start (5 Minutes)

### **What Works Immediately (No Setup):**

✅ **Core Development Tools** (31 tools)
- File operations (read, write, edit)
- Bash commands
- Git integration
- Xcode build/test/analyze
- Grep, search, navigation
- Code generation
- Error diagnosis
- ALL WORK LOCALLY - No internet required

✅ **Native macOS TTS**
- Text-to-speech with built-in voices
- 40+ languages
- Zero setup required
- 100% local

✅ **Web Features**
- Fetch and summarize URLs/documentation
- Tech news headlines
- No API keys required (uses public APIs)

---

## 📦 Dependencies & Installation

### **TIER 1: Core Requirements (Already Installed)**

#### **1. Xcode** ✅
- Version 15.0 or later
- Command line tools
- You already have this!

#### **2. Python 3.10+** ✅
- Required for MLX models
- Check version: `python3 --version`
- macOS includes Python, but verify version

#### **3. MLX Framework**
- Apple's machine learning framework
- Install: `pip install mlx`
- Used for local LLM inference

**Installation:**
```bash
# Verify Python
python3 --version  # Should be 3.10 or higher

# Install MLX
pip3 install mlx mlx-lm

# Verify
python3 -c "import mlx; print(mlx.__version__)"
```

---

### **TIER 2: High-Quality TTS (Recommended - All LOCAL)**

#### **4. MLX-Audio** (Recommended) 🎙️
- **What:** High-quality text-to-speech
- **Where:** 100% LOCAL on your Mac
- **Cost:** FREE
- **Size:** ~500MB-2GB models
- **Speed:** 1-3 seconds per sentence on M3 Ultra
- **Security:** ✅ SafeTensors only

**Installation:**
```bash
pip install mlx-audio
```

**First run:** Downloads models automatically (2-5 minutes)
**Subsequent runs:** Instant - models cached locally

**Models Included:**
- Kokoro (fast, multilingual)
- CSM (voice cloning)
- Chatterbox (expressive, 16 languages)
- 4 more models

---

#### **5. F5-TTS-MLX** (For Voice Cloning) 🎤
- **What:** Clone any voice from 5-10 second sample
- **Where:** 100% LOCAL on your Mac
- **Cost:** FREE
- **Size:** ~2GB models
- **Speed:** ~4 seconds on M3 Ultra
- **Security:** ✅ SafeTensors only

**Installation:**
```bash
pip install f5-tts-mlx
```

**First run:** Downloads models automatically (5-10 minutes)
**Subsequent runs:** Fast - models cached locally

---

### **TIER 3: Local Image Generation (FREE Alternative to Cloud)**

#### **6. MLX Stable Diffusion** (For Local Image Generation) 🎨
- **What:** Generate images on your Mac (SDXL, SD 2.1, FLUX)
- **Where:** 🏠 100% LOCAL (no cloud)
- **Cost:** FREE
- **Speed:** 2-30 seconds on M3 Ultra
- **Quality:** Good to professional
- **Alternative to:** DALL-E 3 (no API key needed!)

**Setup:**
```bash
# Clone Apple's MLX examples
git clone https://github.com/ml-explore/mlx-examples.git ~/mlx-examples

# Install dependencies
cd ~/mlx-examples/stable_diffusion
pip3 install -r requirements.txt
```

**First use:** Downloads models (~7GB, 10 minutes)
**Subsequent uses:** Fast (models cached)

**See:** [LOCAL_IMAGE_GENERATION_SETUP.md](LOCAL_IMAGE_GENERATION_SETUP.md)

---

### **TIER 4: Optional Cloud Image Generation**

#### **7. OpenAI API** (Optional - Cloud Image Generation) 🎨
- **What:** DALL-E 3 image generation (cloud alternative)
- **Where:** ☁️ CLOUD (OpenAI servers)
- **Cost:** $0.04 per image (standard), $0.08 (HD)
- **Speed:** 10-30 seconds
- **Why use:** Slightly better quality than local
- **Why skip:** Local is free and nearly as good!

**Setup:**
```bash
export OPENAI_API_KEY="sk-your-key-here"
```

**Recommendation:** Use local image generation (TIER 3) - it's FREE!

---

#### **7. Other Model Providers** (Optional - For Model Comparison)
- **Ollama:** Local models (Llama, Mistral, etc.)
- **vLLM:** High-performance inference server
- **llama.cpp:** Lightweight inference

**These are OPTIONAL** - MLX already works great locally!

---

## 🎯 Feature Breakdown: Local vs Cloud

### **100% LOCAL FEATURES (No Internet, No API Keys):**

✅ **Development Tools (31 tools)**
- Code analysis, editing, generation
- Git, Xcode, Bash, File operations
- Grep, search, navigation
- ALL work offline

✅ **Native TTS**
- Built-in macOS voices
- 40+ languages
- Instant speech

✅ **MLX-Audio TTS** (after pip install)
- High-quality speech
- 7 models
- Voice cloning
- All models stored locally

✅ **F5-TTS Voice Cloning** (after pip install)
- Clone any voice
- Zero-shot (5-10 sec sample)
- All models stored locally

✅ **Intent Router**
- Auto tool selection
- Pattern matching
- No API needed

---

### **HYBRID FEATURES (Work Locally, Enhanced with Internet):**

🌐 **Web Fetch**
- Fetch documentation (needs internet)
- But works offline for local files
- No API key required

🌐 **News Tool**
- Fetch headlines (needs internet)
- Uses free public APIs
- No API key required

---

### **CLOUD-ONLY FEATURES (Optional):**

☁️ **Image Generation**
- DALL-E 3 via OpenAI
- Requires OPENAI_API_KEY
- Costs $0.04 per image
- **Skip this if you want 100% local!**

☁️ **Alternative LLM Providers**
- OpenAI GPT-4 (requires API key)
- Other cloud models
- **MLX local is recommended!**

---

## 📋 Complete Installation Checklist

### **Minimal Setup (Core Features Only):**

```bash
# 1. Install MLX
pip3 install mlx mlx-lm

# Done! Core features work now.
```

**Time:** 2 minutes
**Features:** All 31 development tools

---

### **Recommended Setup (Add High-Quality TTS):**

```bash
# 1. Install MLX (if not done)
pip3 install mlx mlx-lm

# 2. Install MLX-Audio
pip3 install mlx-audio

# Done! Core + TTS features work.
```

**Time:** 5-10 minutes (models download on first use)
**Features:** Core + MLX-Audio TTS

---

### **Full Setup (Everything Including Voice Cloning):**

```bash
# 1. Install MLX
pip3 install mlx mlx-lm

# 2. Install MLX-Audio
pip3 install mlx-audio

# 3. Install F5-TTS-MLX
pip3 install f5-tts-mlx

# Done! All local features work.
```

**Time:** 10-15 minutes (models download on first use)
**Features:** Core + TTS + Voice Cloning

---

### **Optional: Add Image Generation (Cloud):**

```bash
# Get OpenAI API key from: https://platform.openai.com/api-keys

# Set in terminal
export OPENAI_API_KEY="sk-your-key-here"

# Or add to ~/.zshrc permanently:
echo 'export OPENAI_API_KEY="sk-your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

**Cost:** $0.04 per image
**Features:** +Image generation with DALL-E 3

---

## 🔍 Verification Commands

### **Check Python:**
```bash
python3 --version
# Should show: Python 3.10.x or higher
```

### **Check MLX:**
```bash
python3 -c "import mlx; print('MLX version:', mlx.__version__)"
# Should print version number
```

### **Check MLX-Audio:**
```bash
python3 -c "import mlx_audio; print('MLX-Audio installed:', mlx_audio.__version__)"
# Should print version or error if not installed
```

### **Check F5-TTS:**
```bash
python3 -c "import f5_tts_mlx; print('F5-TTS installed:', f5_tts_mlx.__version__)"
# Should print version or error if not installed
```

### **Check OpenAI API (Optional):**
```bash
echo $OPENAI_API_KEY
# Should print: sk-... or empty if not set
```

---

## 🎮 Usage Examples

### **Text-to-Speech (Native - No Setup):**
```
"Read this code comment aloud"
"Speak: The build completed successfully"
```

### **High-Quality TTS (Requires MLX-Audio):**
```
"Use MLX-Audio to speak: Welcome to my application"
"Generate high-quality speech with Kokoro model"
```

### **Voice Cloning (Requires F5-TTS):**
```
"Clone voice from ~/my_voice.wav and say: Hello everyone"
"Use my voice sample to read this tutorial"
```

### **Web Research (No API Key):**
```
"Fetch and summarize https://developer.apple.com/documentation/swiftui"
"Get latest Swift news"
```

### **Image Generation (Requires OpenAI API):**
```
"Generate an app icon mockup for a weather app"
"Create a UI diagram showing the login flow"
```

### **Development (Built-in):**
```
"Build the project"
"Run tests"
"Search for TODO comments"
"Show git status"
```

---

## 💰 Cost Breakdown

| Feature | Setup Cost | Runtime Cost | Location |
|---------|------------|--------------|----------|
| **Core Tools** | Free | Free | LOCAL |
| **Native TTS** | Free | Free | LOCAL |
| **MLX-Audio** | Free | Free | LOCAL |
| **Voice Cloning** | Free | Free | LOCAL |
| **Web Fetch** | Free | Free | LOCAL + Internet |
| **News** | Free | Free | LOCAL + Internet |
| **Image Gen** | Free | $0.04/image | CLOUD |

**To run 100% free and local:** Skip image generation (everything else is free!)

---

## 🔒 Security Notes

### **All Features Are Secure:**

✅ **Model Loading:**
- Only SafeTensors format
- Pickle files blocked
- PyTorch .pt files blocked
- Source verification

✅ **Command Execution:**
- All commands validated
- Dangerous patterns blocked
- Injection prevention
- Audit logging

✅ **Network Access:**
- SSRF prevention
- Private IP blocking
- Localhost blocking
- URL validation

### **Audit Log Location:**
```
~/Library/Logs/MLXCode/security.log
```

View security events:
```bash
tail -f ~/Library/Logs/MLXCode/security.log
```

---

## ⚡ Performance (Your M3 Ultra)

### **Expected Performance:**

| Feature | Speed | Notes |
|---------|-------|-------|
| **Native TTS** | Instant | macOS built-in |
| **MLX-Audio** | 1-3s/sentence | Apple Silicon optimized |
| **Voice Clone** | 3-5s/sentence | Zero-shot, excellent quality |
| **Image Gen** | 10-30s | Cloud-based (DALL-E) |
| **Code Tools** | Instant | Local processing |
| **MLX Model** | 50-100 tokens/s | With your 192GB unified memory |

**Your M3 Ultra is PERFECT for all local features!**

---

## 🆘 Troubleshooting

### **"Module not found: mlx"**
```bash
pip3 install mlx mlx-lm
```

### **"Module not found: mlx_audio"**
```bash
pip3 install mlx-audio
```

### **"Module not found: f5_tts_mlx"**
```bash
pip3 install f5-tts-mlx
```

### **"OpenAI API key not configured"**
Two options:
1. Set environment variable: `export OPENAI_API_KEY="sk-..."`
2. **Or skip image generation** - everything else works!

### **"Models downloading..." (First Use)**
This is normal! Models download once:
- MLX-Audio: 500MB-2GB (5-10 minutes)
- F5-TTS: ~2GB (5-10 minutes)
- Subsequent uses are instant

### **"Command blocked by security validator"**
This is a security feature working correctly!
- Check security log: `~/Library/Logs/MLXCode/security.log`
- Only safe commands are allowed

---

## 📊 Storage Requirements

### **Minimum (Core Only):**
- MLX models: ~5GB
- Total: ~5GB

### **Recommended (Core + TTS):**
- MLX models: ~5GB
- MLX-Audio models: ~2GB
- F5-TTS models: ~2GB
- Total: ~9GB

### **Full (Core + TTS + Voice Cloning):**
- Same as recommended: ~9GB
- Your 512GB? No problem!

---

## 🎯 Recommended Setup Path

### **For Development Work Only:**
```bash
pip3 install mlx mlx-lm
```
**Time:** 2 minutes
**Features:** All code tools
**Storage:** 5GB

### **For Development + TTS:**
```bash
pip3 install mlx mlx-lm mlx-audio
```
**Time:** 10 minutes
**Features:** Code tools + high-quality speech
**Storage:** 7GB

### **For Everything (Except Images):**
```bash
pip3 install mlx mlx-lm mlx-audio f5-tts-mlx
```
**Time:** 15 minutes
**Features:** Code tools + TTS + voice cloning
**Storage:** 9GB
**Cost:** FREE

### **For Absolutely Everything:**
```bash
# Install all Python packages
pip3 install mlx mlx-lm mlx-audio f5-tts-mlx

# Get OpenAI API key (costs $0.04 per image)
export OPENAI_API_KEY="sk-your-key-here"
```
**Time:** 15 minutes
**Features:** Everything including image generation
**Storage:** 9GB
**Cost:** FREE (except images: $0.04 each)

---

## 🏃 Running MLX Code

### **First Launch:**

1. **Open MLX Code app**
2. **First prompt may be slow** (loading models)
3. **Subsequent prompts are fast** (models cached)

### **Model Download (First Use Only):**

If you installed MLX-Audio or F5-TTS, first use will download models:
- MLX-Audio: "Downloading Kokoro model..." (~5 minutes)
- F5-TTS: "Downloading F5-TTS model..." (~5-10 minutes)

**This only happens once!** Models are cached in:
- `~/.cache/huggingface/hub/`
- Subsequent uses are instant

---

## 🌟 Feature Availability Matrix

| Feature | Requires | Location | Cost | Speed |
|---------|----------|----------|------|-------|
| **Code Tools** | MLX | LOCAL | Free | Fast |
| **Native TTS** | None | LOCAL | Free | Instant |
| **MLX-Audio TTS** | pip install | LOCAL | Free | 1-3s |
| **Voice Cloning** | pip install | LOCAL | Free | 3-5s |
| **Web Fetch** | None | LOCAL | Free | Varies |
| **News** | None | LOCAL | Free | Fast |
| **Intent Router** | None | LOCAL | Free | Instant |
| **Multi-Model** | Optional | LOCAL/CLOUD | Free/Paid | Varies |
| **Image Gen (LOCAL)** | pip install | LOCAL | Free | 2-30s |
| **Image Gen (Cloud)** | API Key | CLOUD | $0.04 | 10-30s |

**✅ NEW: Image generation now available 100% locally with MLX Stable Diffusion!**

---

## 🎓 Learning Path

### **Day 1: Core Features**
1. ✅ Build project with Xcode tool
2. ✅ Search code with grep
3. ✅ Generate code
4. ✅ Use native TTS

### **Day 2: Advanced TTS**
1. ✅ Install mlx-audio
2. ✅ Try high-quality speech
3. ✅ Experiment with different models

### **Day 3: Voice Cloning**
1. ✅ Install f5-tts-mlx
2. ✅ Record voice sample
3. ✅ Clone and test

### **Day 4: Full Stack**
1. ✅ Try web fetch
2. ✅ Get news updates
3. ✅ Optional: Add OpenAI key for images

---

## 🚫 What You DON'T Need

❌ **Don't need:**
- Docker
- GPU (Apple Silicon built-in)
- CUDA
- Cloud credits
- Subscriptions
- Internet (except for web/news/images)

✅ **Everything runs on your Mac!**

---

## 💡 Pro Tips

### **1. Start Simple**
Use native TTS and core tools first. Add MLX-Audio later if you want better quality.

### **2. Model Caching**
Models download once and cache. First use is slow, everything after is fast.

### **3. Free Alternative to DALL-E**
Use Stable Diffusion locally (slower) or skip image generation.

### **4. Voice Samples**
For best voice cloning:
- Use QuickTime Player to record
- 5-10 seconds of clear speech
- Save as .wav (24kHz mono ideal)
- No background noise

### **5. Security Logs**
Check security log if tools are blocked:
```bash
tail ~/Library/Logs/MLXCode/security.log
```

---

## 📝 One-Command Install (Recommended Full Setup)

```bash
# Install everything for local use (no cloud)
pip3 install mlx mlx-lm mlx-audio f5-tts-mlx

# Verify
python3 -c "import mlx, mlx_audio, f5_tts_mlx; print('✅ All dependencies installed!')"
```

**Time:** 15 minutes
**Storage:** 9GB
**Features:** Everything except image generation
**Cost:** FREE
**Location:** 100% LOCAL

---

## 🔐 Security Verification

### **Check Security Systems:**

```bash
# View security log
tail ~/Library/Logs/MLXCode/security.log

# Should see entries like:
# [2026-01-06...] [SECURITY] [INFO] ✅ Model validated (SafeTensors)
# [2026-01-06...] [CommandValidator] [INFO] ✅ Validated bash command
```

### **Test Security:**

Try a dangerous command (it should be BLOCKED):
```
"Run: rm -rf /tmp/test"
```

Expected: `❌ Error: Dangerous pattern detected: rm -rf`

---

## 🎯 Summary

### **To Use MLX Code Fully (Recommended):**

**Step 1:** Install local dependencies (15 minutes)
```bash
pip3 install mlx mlx-lm mlx-audio f5-tts-mlx
```

**Step 2:** Launch MLX Code
- Everything works!
- All features are local
- No API keys needed
- 100% FREE

**Step 3 (Optional):** Add OpenAI for images
```bash
export OPENAI_API_KEY="sk-..."
```

---

## 📞 Support

### **Issues:**
- Check logs: `~/Library/Logs/MLXCode/security.log`
- Verify installations: Run verification commands above
- Check Python version: `python3 --version`

### **Model Downloads:**
- First use: 5-15 minutes (downloads models)
- Stored in: `~/.cache/huggingface/hub/`
- Only happens once!

### **Security:**
- All models are SafeTensors (secure)
- No pickle files (dangerous) are loaded
- Commands are validated before execution
- You're protected!

---

**Enjoy MLX Code with all features running locally on your M3 Ultra!** 🚀

**90% of features work with ZERO API keys, ZERO cloud services, and ZERO costs!**
