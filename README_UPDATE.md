# MLX Code v3.4.0 - Quick Links

## 📚 Documentation

### **New User? Start Here:**
1. 📖 **[GETTING_STARTED.md](GETTING_STARTED.md)** - Complete setup guide with examples
2. 🏠 **[LOCAL_ONLY_SETUP.md](LOCAL_ONLY_SETUP.md)** - 100% local, zero cloud setup
3. 📦 **[DEPENDENCIES.md](DEPENDENCIES.md)** - Complete dependency reference

### **Feature Guides:**
- 🎙️ **[TTS_FEATURES_GUIDE.md](TTS_FEATURES_GUIDE.md)** - Text-to-speech & voice cloning

### **Security:**
- 🔒 **[SECURITY_AUDIT_REPORT.md](SECURITY_AUDIT_REPORT.md)** - Security audit results

---

## ⚡ Quick Start

### **Minimal (Core Features):**
```bash
pip3 install mlx mlx-lm
```

### **Recommended (Core + TTS):**
```bash
pip3 install mlx mlx-lm mlx-audio f5-tts-mlx
```

### **Optional (Add Image Generation):**
```bash
export OPENAI_API_KEY="sk-..."  # Costs $0.04/image
```

---

## 🎯 What's Included

### **37 Tools Total:**
- 31 Development tools (code, git, xcode, bash, etc.)
- 3 TTS tools (native, MLX-Audio, voice cloning)
- 3 External data tools (web, news, images*)

*Image generation requires OpenAI API key (optional)

### **100% Local Features:**
- ✅ All development tools
- ✅ All TTS features
- ✅ Intent router
- ✅ Multi-model support (for local providers)

### **Optional Cloud Features:**
- ⚪ Web fetch (fetches URLs - free, no key)
- ⚪ News (fetches headlines - free, no key)
- ⚪ Image generation (DALL-E - requires API key, $0.04/image)

---

## 🔐 Security

- ✅ SafeTensors only (no pickle)
- ✅ Command injection prevention
- ✅ Input validation
- ✅ Audit logging
- ✅ No arbitrary code execution

---

## 🎉 Credits

**Features inspired by:**
- TinyLLM by Jason Cox - https://github.com/jasonacox/TinyLLM

**Built by:**
- Jordan Koch

**Powered by:**
- Apple MLX Framework
- MLX-Audio (lucasnewman)
- F5-TTS-MLX (lucasnewman)

---

See full documentation in the links above!
