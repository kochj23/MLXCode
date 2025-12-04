# MLX Code - Quick Start Guide

**Version:** 2.0.0
**Date:** November 18, 2025

---

## 🚀 Get Started in 5 Minutes

### Step 1: Install Python Dependencies

Open Terminal and run:

```bash
cd "/Volumes/Data/xcode/MLX Code/Python"
./setup.sh
```

**What this does:**
- Installs MLX framework for Apple Silicon
- Installs HuggingFace tools for model downloads
- Installs RAG system dependencies (embeddings, vector search)

**Expected output:**
```
✅ All dependencies verified successfully!
🎉 MLX Code is ready to use!
```

---

### Step 2: Launch MLX Code

Open the app from Xcode or Finder:

```bash
open "/Users/kochj/Library/Developer/Xcode/DerivedData/MLX_Code-*/Build/Products/Debug/MLX Code.app"
```

---

### Step 3: Download a Model

1. Click the **Settings** button (gear icon in top-right)
2. You'll see 4 pre-configured models:
   - **Qwen 2.5 500M** - Fast, lightweight (1.2 GB)
   - **Llama 3.2 3B** - Balanced performance (1.6 GB) ⭐ Recommended
   - **Mistral 7B** - High quality (4.1 GB)
   - **Gemma 2 2B** - Google's model (1.4 GB)

3. Click **Download** on **Llama 3.2 3B** (recommended for first-time users)
4. Wait for download to complete (~2-5 minutes depending on internet speed)
5. Click **Load Model** button

**Expected behavior:**
- Progress bar shows download status
- Status changes to "Model loaded ✓"
- Green indicator appears

---

### Step 4: Start Chatting!

Type a message and press **Send** (or ⌘↩):

**Try these prompts:**

```
Write a Swift function to validate email addresses
```

```
Explain how closures work in Swift with examples
```

```
Create a SwiftUI view for a login screen
```

**What you'll see:**
- Tokens stream in real-time (like ChatGPT)
- Response appears character by character
- Code blocks with syntax highlighting

---

## ✨ Advanced Features

### Enable RAG (Code Understanding)

Make the AI understand YOUR codebase:

```bash
cd "/Volumes/Data/xcode/MLX Code/Python"

# Index your project
python3 rag_system.py index "/Volumes/Data/xcode/MLX Code" \
  --extensions .swift .h .m \
  --exclude Test Build DerivedData
```

**Now ask codebase-specific questions:**

```
How does the ChatViewModel manage conversations?
```

```
Show me how authentication is implemented
```

```
Where is the settings data persisted?
```

The AI will reference YOUR actual code in its answers!

---

## 🛠 Troubleshooting

### Error: "huggingface_hub not installed"

**Solution:** Run the setup script again:
```bash
cd "/Volumes/Data/xcode/MLX Code/Python"
./setup.sh
```

### Error: "Model not found"

**Cause:** Model download was interrupted

**Solution:**
1. Delete incomplete model:
   ```bash
   rm -rf /Volumes/Data/models/model-name
   ```
2. Download again from the app

### Error: "Python bridge failed to start"

**Cause:** Python script path incorrect

**Check:**
```bash
ls -la "/Volumes/Data/xcode/MLX Code/Python/mlx_inference.py"
```

Should show the file exists.

### Slow Performance

**Tips:**
- Use smaller models (Qwen 500M for speed)
- Close other memory-intensive apps
- Ensure running on Apple Silicon Mac

---

## 📊 Model Comparison

| Model | Size | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| **Qwen 2.5 500M** | 1.2 GB | ⚡⚡⚡ Fast | ⭐⭐ Good | Quick questions, testing |
| **Llama 3.2 3B** | 1.6 GB | ⚡⚡ Medium | ⭐⭐⭐ Excellent | General use, coding |
| **Mistral 7B** | 4.1 GB | ⚡ Slower | ⭐⭐⭐⭐ Best | Complex tasks, detailed explanations |
| **Gemma 2 2B** | 1.4 GB | ⚡⚡ Medium | ⭐⭐⭐ Very Good | Google-trained, versatile |

**Recommendation:** Start with **Llama 3.2 3B** - best balance of speed and quality.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘ + ↩** | Send message |
| **⌘ + ,** | Open Settings |
| **⌘ + N** | New conversation |
| **Esc** | Stop generation |

---

## 💡 Tips & Tricks

### 1. Streaming Generation
Watch tokens appear in real-time. Click **Stop** to interrupt if the response is going off-track.

### 2. Adjust Temperature
Lower temperature (0.3-0.5) for factual answers, higher (0.7-1.0) for creative responses.

Settings → Generation → Temperature slider

### 3. Use RAG for Project-Specific Help
Index your codebase once, then ask questions about YOUR code:

```bash
python3 rag_system.py index ~/my-project
```

### 4. Model Switching
Different models excel at different tasks:
- **Quick questions?** Use Qwen 500M
- **Code generation?** Use Llama 3.2 3B
- **Complex problems?** Use Mistral 7B

### 5. Context Matters
Provide context in your prompts:

```
I'm building a SwiftUI app with MVVM architecture.
Create a view model for managing user profiles.
```

---

## 🎯 Example Workflows

### Workflow 1: Code Generation

```
User: "Create a Swift function to parse JSON into a User model"

AI: [Generates code with struct User and parsing logic]

User: "Add error handling"

AI: [Adds try-catch blocks and proper error types]
```

### Workflow 2: Code Review

```
User: "Review this code for memory issues"

[Paste code]

AI: [Identifies potential retain cycles, suggests using [weak self]]
```

### Workflow 3: Learning

```
User: "Explain async/await in Swift"

AI: [Detailed explanation with examples]

User: "Show me a real-world example with network requests"

AI: [Complete example with URLSession and async/await]
```

---

## 🐛 Known Issues

1. **First model load is slow** (~5-10 seconds)
   - Expected: Models are large and need to load into memory
   - Subsequent loads are instant

2. **Download progress not updating**
   - Progress bar may appear stuck but download is happening
   - Check disk space: Models range from 1-5 GB

3. **Token generation pauses briefly**
   - Normal: Model is computing next tokens
   - Use smaller models for faster response

---

## 📚 Learn More

- **Full Documentation:** `PHASE_1_2_IMPLEMENTATION.md`
- **API Reference:** `API_DOCUMENTATION.md`
- **User Guide:** `USER_GUIDE.md`
- **Testing Guide:** `COMPREHENSIVE_TEST_DOCUMENTATION.md`

---

## 🆘 Need Help?

**Check logs:**
```bash
# View app logs
log show --predicate 'process == "MLX Code"' --last 5m
```

**Common log locations:**
- `~/Library/Logs/MLX Code/`
- Console.app → Search for "MLX Code"

**Verify Python environment:**
```bash
/usr/bin/python3 -c "import mlx.core; print('MLX OK')"
/usr/bin/python3 -c "import mlx_lm; print('mlx-lm OK')"
```

---

## ✅ Quick Checklist

Before reporting issues, verify:

- [ ] Python dependencies installed (`./setup.sh`)
- [ ] Model downloaded completely
- [ ] Model loaded (green indicator)
- [ ] Sufficient disk space (5+ GB free)
- [ ] Running on Apple Silicon Mac
- [ ] macOS 14.0 or later

---

**Happy Coding with AI! 🚀**
