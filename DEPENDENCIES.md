# MLX Code - Complete Dependencies Reference

**Version:** 3.4.0
**Last Updated:** January 6, 2026

---

## 🎯 Quick Reference

### **What's Required:**
✅ Python 3.10+
✅ MLX Framework (`pip install mlx mlx-lm`)

### **What's Optional:**
⚪ mlx-audio (for high-quality TTS)
⚪ f5-tts-mlx (for voice cloning)
⚪ OpenAI API key (for image generation ONLY)

### **What's NOT Required:**
❌ Docker
❌ CUDA/NVIDIA GPU
❌ Cloud subscriptions
❌ Internet (except web/news/images features)

---

## 📦 Complete Dependency List

### **TIER 1: REQUIRED (Core Functionality)**

#### **1. Xcode**
- **Version:** 15.0 or later
- **Why:** macOS development environment
- **Size:** ~15GB
- **Location:** `/Applications/Xcode.app`
- **Install:** Mac App Store or developer.apple.com
- **Verification:** `xcodebuild -version`

#### **2. Python 3**
- **Version:** 3.10 or higher
- **Why:** MLX models run on Python
- **Size:** ~100MB
- **Location:** `/usr/bin/python3` or `/opt/homebrew/bin/python3`
- **Install:** Usually pre-installed on macOS, or `brew install python3`
- **Verification:** `python3 --version`

#### **3. MLX Framework**
- **Package:** `mlx, mlx-lm`
- **Version:** Latest
- **Why:** Apple Silicon ML framework for local LLM inference
- **Size:** ~50MB package + models
- **Location:** `~/.cache/pip/` (package), `~/.cache/huggingface/` (models)
- **Install:** `pip3 install mlx mlx-lm`
- **Verification:** `python3 -c "import mlx; print(mlx.__version__)"`
- **Models:** ~3-5GB downloaded on first use

---

### **TIER 2: RECOMMENDED (Enhanced Features)**

#### **4. MLX-Audio**
- **Package:** `mlx-audio`
- **Version:** Latest
- **Why:** High-quality text-to-speech, voice cloning
- **Size:** ~50MB package + 500MB-2GB models
- **Location:** `~/.cache/huggingface/hub/models--lucasnewman--*`
- **Install:** `pip3 install mlx-audio`
- **Verification:** `python3 -c "import mlx_audio; print(mlx_audio.__version__)"`
- **Models Downloaded:** Kokoro, CSM, Chatterbox, etc.
- **Download Time:** 5-10 minutes (first use only)
- **Features Enabled:** High-quality TTS, multiple models, voice customization

#### **5. F5-TTS-MLX**
- **Package:** `f5-tts-mlx`
- **Version:** Latest
- **Why:** Zero-shot voice cloning
- **Size:** ~30MB package + ~2GB models
- **Location:** `~/.cache/huggingface/hub/models--SWivid--*`
- **Install:** `pip3 install f5-tts-mlx`
- **Verification:** `python3 -c "import f5_tts_mlx; print(f5_tts_mlx.__version__)"`
- **Models Downloaded:** F5-TTS base model, voice encoder
- **Download Time:** 5-10 minutes (first use only)
- **Features Enabled:** Voice cloning from 5-10 second samples

---

### **TIER 3: OPTIONAL (Cloud Features)**

#### **6. OpenAI API Key**
- **Service:** OpenAI Platform
- **Why:** Image generation with DALL-E 3
- **Cost:** $0.04 per standard image, $0.08 per HD image
- **Setup:** Get key from https://platform.openai.com/api-keys
- **Install:** `export OPENAI_API_KEY="sk-..."`
- **Verification:** `echo $OPENAI_API_KEY`
- **Features Enabled:** Image generation ONLY
- **Alternative:** Skip this - everything else is free and local!

#### **7. Alternative Model Providers** (Optional)
- **Ollama:** Local models (Llama, Mistral)
  - Install: `brew install ollama`
  - Why: Alternative local LLM backend
  - Cost: Free

- **vLLM:** High-performance inference
  - Install: `pip install vllm`
  - Why: Faster inference for some models
  - Cost: Free

- **llama.cpp:** Lightweight inference
  - Install: `brew install llama.cpp`
  - Why: Low-resource alternative
  - Cost: Free

**Note:** These are alternatives to MLX. You don't need them if MLX works well for you!

---

## 💾 Disk Space Requirements

### **Minimal Install:**
- Python + MLX: ~5GB
- **Enough for:** Core development tools

### **Recommended Install:**
- Python + MLX + MLX-Audio: ~7GB
- **Enough for:** Core tools + high-quality TTS

### **Full Install:**
- Python + MLX + MLX-Audio + F5-TTS: ~9GB
- **Enough for:** Everything except image generation

### **Your 512GB SSD:**
- ✅ Plenty of space!
- Models take ~9GB total
- Less than 2% of your storage

---

## 🔄 Update Instructions

### **Update MLX:**
```bash
pip3 install --upgrade mlx mlx-lm
```

### **Update MLX-Audio:**
```bash
pip3 install --upgrade mlx-audio
```

### **Update F5-TTS:**
```bash
pip3 install --upgrade f5-tts-mlx
```

### **Update All:**
```bash
pip3 install --upgrade mlx mlx-lm mlx-audio f5-tts-mlx
```

---

## 🌐 Network Dependencies

### **NO Internet Required For:**
- Core development tools
- Native TTS
- MLX-Audio TTS (after initial model download)
- Voice cloning (after initial model download)
- Code generation
- File operations
- Git operations
- Xcode integration

### **Internet Required For:**
- Initial model downloads (one-time)
- Web fetch tool (fetching URLs)
- News tool (fetching headlines)
- Image generation (DALL-E API)

### **Offline Mode:**
Once models are downloaded, you can work 100% offline except:
- Web fetch (needs internet to fetch URLs)
- News (needs internet for headlines)
- Image generation (cloud API)

---

## 🔐 Security Dependencies

### **SafeTensors Library**
- **Included in:** mlx-audio, f5-tts-mlx
- **Why:** Secure model format (no code execution)
- **Alternative formats blocked:** Pickle, PyTorch .pt files

### **Command Validator**
- **Built into MLX Code**
- **Why:** Prevents command injection
- **Validates:** All bash commands, Python code, URLs

### **Model Security Validator**
- **Built into MLX Code**
- **Why:** Validates model files before loading
- **Checks:** File format, pickle detection, source verification

---

## 📱 System Requirements

### **Hardware:**
- **CPU:** Apple Silicon (M1/M2/M3) or Intel
- **RAM:** 16GB minimum, 32GB+ recommended
- **Storage:** 10GB free space for models
- **Your M3 Ultra:** ✅ PERFECT! (192GB RAM, 60-76 GPU cores)

### **Software:**
- **OS:** macOS 13.0 (Ventura) or later
- **Xcode:** 15.0 or later
- **Python:** 3.10 or higher

---

## 🆘 Common Issues

### **"pip: command not found"**
```bash
# Install Python 3
brew install python3

# Or use python3 -m pip instead
python3 -m pip install mlx
```

### **"Permission denied" during pip install**
```bash
# Use user install (no sudo needed)
pip3 install --user mlx mlx-lm mlx-audio f5-tts-mlx
```

### **"No module named 'mlx'"**
```bash
# Verify Python can find packages
python3 -c "import sys; print(sys.path)"

# Reinstall
pip3 install mlx mlx-lm
```

### **Models downloading slowly**
- This is normal for first use
- Models are large (500MB-2GB each)
- Only happens once
- Grab coffee, wait 5-15 minutes

### **"Out of memory" during model loading**
- Close other apps
- Your M3 Ultra with 192GB: This shouldn't happen!
- Contact support if it does

---

## 🔄 Uninstall Instructions

### **Remove Python Packages:**
```bash
pip3 uninstall mlx mlx-lm mlx-audio f5-tts-mlx
```

### **Remove Cached Models:**
```bash
rm -rf ~/.cache/huggingface/hub/models--*mlx*
rm -rf ~/.cache/huggingface/hub/models--lucasnewman--*
rm -rf ~/.cache/huggingface/hub/models--SWivid--*
```

**Frees:** ~9GB

---

## 📊 Dependency Tree

```
MLX Code
├── Xcode (Required)
├── Python 3.10+ (Required)
│   └── MLX Framework (Required)
│       ├── mlx (Required)
│       └── mlx-lm (Required)
├── MLX-Audio (Optional - Recommended)
│   ├── Kokoro Model (~500MB)
│   ├── CSM Model (~800MB)
│   ├── Chatterbox Model (~1GB)
│   └── 4 more models
├── F5-TTS-MLX (Optional - For Voice Cloning)
│   ├── F5-TTS Base (~1.5GB)
│   └── Voice Encoder (~500MB)
└── OpenAI API Key (Optional - Images Only)
    └── DALL-E 3 (Cloud service)
```

---

## ✅ Installation Verification Script

Save as `verify_mlx_setup.sh`:

```bash
#!/bin/bash

echo "🔍 Verifying MLX Code Dependencies..."
echo ""

# Check Python
echo "1. Python:"
python3 --version && echo "   ✅ Python OK" || echo "   ❌ Python missing"

# Check MLX
echo "2. MLX:"
python3 -c "import mlx; print('   ✅ MLX version:', mlx.__version__)" 2>/dev/null || echo "   ❌ MLX not installed (pip3 install mlx)"

# Check MLX-LM
echo "3. MLX-LM:"
python3 -c "import mlx_lm; print('   ✅ MLX-LM installed')" 2>/dev/null || echo "   ⚪ MLX-LM not installed (optional)"

# Check MLX-Audio
echo "4. MLX-Audio:"
python3 -c "import mlx_audio; print('   ✅ MLX-Audio version:', mlx_audio.__version__)" 2>/dev/null || echo "   ⚪ MLX-Audio not installed (pip3 install mlx-audio for TTS)"

# Check F5-TTS
echo "5. F5-TTS-MLX:"
python3 -c "import f5_tts_mlx; print('   ✅ F5-TTS version:', f5_tts_mlx.__version__)" 2>/dev/null || echo "   ⚪ F5-TTS not installed (pip3 install f5-tts-mlx for voice cloning)"

# Check OpenAI Key
echo "6. OpenAI API Key:"
if [ -n "$OPENAI_API_KEY" ]; then
    echo "   ✅ API key configured (image generation enabled)"
else
    echo "   ⚪ API key not set (image generation disabled - everything else works)"
fi

echo ""
echo "✅ Verification complete!"
```

Run with: `chmod +x verify_mlx_setup.sh && ./verify_mlx_setup.sh`

---

## 🎉 Ready to Go!

**Recommended command:**
```bash
pip3 install mlx mlx-lm mlx-audio f5-tts-mlx
```

**Then launch MLX Code and start coding with AI assistance!**

**Everything runs locally. Everything is secure. Everything is FREE (except optional image generation).**
