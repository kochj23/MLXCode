# Mistral Model Setup Guide

## Issue Resolved: Sentencepiece Error

**Error:** "Failed to load model: Text generation failed: Cannot instantiate this tokenizer from a slow version. If it's based on sentencepiece, make sure you have sentencepiece installed."

**Solution:** This has been fixed by adding sentencepiece to the dependencies.

---

## Prerequisites

### 1. Ensure All Dependencies Are Installed

The following packages are now required (sentencepiece was missing):

```bash
pip3 install mlx>=0.0.10
pip3 install mlx-lm>=0.0.10
pip3 install huggingface-hub>=0.19.0
pip3 install transformers>=4.35.0
pip3 install sentencepiece>=0.1.99    # ✅ ADDED - Required for Mistral
pip3 install protobuf>=3.20.0         # ✅ ADDED - Required for sentencepiece
pip3 install tokenizers>=0.15.0       # ✅ ADDED - Required for fast tokenizers
pip3 install sentence-transformers>=2.2.0
pip3 install chromadb>=0.4.0
pip3 install numpy>=1.24.0
pip3 install tqdm>=4.65.0
```

Or install from requirements.txt:

```bash
cd "/Volumes/Data/xcode/MLX Code/Python"
pip3 install -r requirements.txt
```

### 2. Verify Sentencepiece Installation

```bash
python3 -c "import sentencepiece; print(f'sentencepiece version: {sentencepiece.__version__}')"
```

Expected output: `sentencepiece version: 0.2.1` (or newer)

---

## Downloading Mistral Models

Mistral has several model variants. Here are the recommended ones for MLX Code:

### Option 1: Mistral 7B Instruct v0.3 (Recommended)

**Size:** ~14 GB
**Quality:** ⭐️⭐️⭐️⭐️⭐️ Excellent
**Speed:** ⚡️⚡️⚡️ Moderate
**RAM Required:** 16 GB minimum

```bash
mkdir -p ~/.mlx/models/
cd ~/.mlx/models/

# Download MLX-compatible Mistral 7B
huggingface-cli download mlx-community/Mistral-7B-Instruct-v0.3-4bit --local-dir mistral-7b-instruct-v0.3
```

### Option 2: Mistral 7B Instruct v0.2

```bash
mkdir -p ~/.mlx/models/
cd ~/.mlx/models/

huggingface-cli download mlx-community/Mistral-7B-Instruct-v0.2-4bit --local-dir mistral-7b-instruct-v0.2
```

### Option 3: Mistral Nemo (12B)

**Size:** ~24 GB
**Quality:** ⭐️⭐️⭐️⭐️⭐️⭐️ Outstanding
**Speed:** ⚡️⚡️ Slower
**RAM Required:** 24 GB minimum

```bash
mkdir -p ~/.mlx/models/
cd ~/.mlx/models/

huggingface-cli download mlx-community/Mistral-Nemo-Instruct-2407-4bit --local-dir mistral-nemo-instruct
```

---

## Why MLX-Community Models?

The `mlx-community` models are **pre-converted for MLX** and optimized for Apple Silicon. They include:

- ✅ Correct model architecture for MLX
- ✅ Quantized weights (4-bit) for faster inference
- ✅ Pre-configured tokenizer
- ✅ All required files (config.json, tokenizer.json, etc.)

---

## Loading Mistral in MLX Code

### Method 1: Via UI

1. Launch MLX Code
2. Click "Models" in the sidebar
3. Click "Browse" or "Select Model Directory"
4. Navigate to `~/.mlx/models/mistral-7b-instruct-v0.3`
5. Click "Load Model"
6. Wait for model to load (progress shown in logs)
7. Start chatting!

### Method 2: Via Settings

1. Open Settings (⌘,)
2. Go to "Paths" tab
3. Set model path to: `/Users/[your-username]/.mlx/models/mistral-7b-instruct-v0.3`
4. Restart MLX Code
5. Model will auto-load on startup

---

## Troubleshooting

### Issue 1: "sentencepiece not installed"

**Solution:** Already fixed! Run:
```bash
pip3 install sentencepiece protobuf tokenizers
```

### Issue 2: "Model files not found"

**Check model directory:**
```bash
ls -lh ~/.mlx/models/mistral-7b-instruct-v0.3/
```

Should contain:
- `config.json`
- `tokenizer.json` or `tokenizer.model`
- `model.safetensors` or `weights.00.safetensors`

If missing, re-download the model.

### Issue 3: "Cannot load tokenizer"

The model might not be MLX-compatible. Ensure you downloaded from `mlx-community`:

```bash
# Correct (MLX-compatible):
huggingface-cli download mlx-community/Mistral-7B-Instruct-v0.3-4bit --local-dir mistral-7b

# Incorrect (PyTorch format, won't work):
huggingface-cli download mistralai/Mistral-7B-Instruct-v0.3 --local-dir mistral-7b
```

### Issue 4: Model loads but generates garbage

**Possible causes:**
1. Wrong model format (not MLX)
2. Corrupted download
3. Incompatible quantization

**Solution:** Delete and re-download:
```bash
rm -rf ~/.mlx/models/mistral-7b-instruct-v0.3
huggingface-cli download mlx-community/Mistral-7B-Instruct-v0.3-4bit --local-dir ~/.mlx/models/mistral-7b-instruct-v0.3
```

### Issue 5: Out of memory

Mistral 7B needs ~12-16 GB RAM. If you have less:

**Option A:** Use quantized 4-bit version (what we recommended above)

**Option B:** Use a smaller model like Phi-3.5 Mini (3.8 GB)

**Option C:** Close other applications to free RAM

---

## Verifying Your Setup

### Test 1: Import Check
```bash
python3 -c "
import mlx.core as mx
import sentencepiece
import transformers
print('✅ All packages installed')
"
```

### Test 2: Tokenizer Check
```bash
python3 -c "
from transformers import AutoTokenizer
tokenizer = AutoTokenizer.from_pretrained('mistralai/Mistral-7B-Instruct-v0.2')
print('✅ Mistral tokenizer loaded')
"
```

### Test 3: Model Check
```bash
cd ~/.mlx/models/mistral-7b-instruct-v0.3
ls -1 | grep -E "(config.json|tokenizer|safetensors)"
```

Expected output:
```
config.json
tokenizer.json
weights.00.safetensors
```

---

## Performance Expectations

### Mistral 7B on Different Hardware

| Hardware | Speed (t/s) | Experience |
|----------|-------------|------------|
| M1 8GB | 15-25 | Slow but usable |
| M1 Pro 16GB | 30-45 | Good |
| M1 Max 32GB | 50-70 | Excellent |
| M2 8GB | 20-30 | Moderate |
| M2 Pro 16GB | 35-50 | Good |
| M2 Max 32GB | 55-75 | Excellent |
| M3 8GB | 25-35 | Moderate |
| M3 Pro 18GB | 40-60 | Very Good |
| M3 Max 36GB | 60-80 | Excellent |

*Speeds are approximate for 4-bit quantized models*

---

## Recommended Settings for Mistral

When using Mistral in MLX Code, these settings work well:

### Generation Settings
- **Temperature:** 0.7 (balanced creativity/accuracy)
- **Top-P:** 0.9 (good diversity)
- **Max Tokens:** 512-2048 (depending on use case)
- **Repetition Penalty:** 1.1 (prevents loops)

### Context Settings
- **Context Window:** 8192 tokens (Mistral's native context)
- **System Prompt:** Use clear, specific instructions

---

## Model Comparison

### Phi-3.5 Mini vs Mistral 7B

| Feature | Phi-3.5 Mini | Mistral 7B |
|---------|--------------|------------|
| Size | 3.8 GB | 14 GB |
| RAM | 8 GB min | 16 GB min |
| Speed | ⚡️⚡️⚡️ Fast | ⚡️⚡️ Moderate |
| Quality | ⭐️⭐️⭐️ Good | ⭐️⭐️⭐️⭐️⭐️ Excellent |
| Code Tasks | ✅ Good | ✅ Excellent |
| Reasoning | ✅ Good | ✅ Superior |
| Long Context | ✅ 4K | ✅ 8K |

**Recommendation:**
- Use **Phi-3.5 Mini** for: Quick tasks, limited RAM, faster responses
- Use **Mistral 7B** for: Complex reasoning, code reviews, better quality

---

## Advanced: Converting Other Mistral Models to MLX

If you want to use a different Mistral variant:

```bash
# Install MLX conversion tools
pip3 install mlx-lm

# Convert a HuggingFace model to MLX
python3 -m mlx_lm.convert \
    --hf-path mistralai/Mistral-7B-Instruct-v0.3 \
    --mlx-path ~/.mlx/models/mistral-7b-custom \
    --quantize
```

---

## Quick Setup Script

Copy and paste this entire script to set up Mistral:

```bash
#!/bin/bash

echo "🚀 Setting up Mistral for MLX Code..."

# Install dependencies
echo "📦 Installing Python dependencies..."
pip3 install sentencepiece protobuf tokenizers transformers huggingface-hub

# Create directory
echo "📁 Creating models directory..."
mkdir -p ~/.mlx/models/

# Download Mistral
echo "⬇️  Downloading Mistral 7B Instruct v0.3 (this may take 10-30 minutes)..."
cd ~/.mlx/models/
huggingface-cli download mlx-community/Mistral-7B-Instruct-v0.3-4bit --local-dir mistral-7b-instruct-v0.3

# Verify
echo "✅ Verifying installation..."
if [ -f ~/.mlx/models/mistral-7b-instruct-v0.3/config.json ]; then
    echo "✅ Mistral model downloaded successfully!"
    echo ""
    echo "📍 Model location: ~/.mlx/models/mistral-7b-instruct-v0.3"
    echo ""
    echo "🎯 Next steps:"
    echo "1. Launch MLX Code"
    echo "2. Click 'Models' in sidebar"
    echo "3. Browse to ~/.mlx/models/mistral-7b-instruct-v0.3"
    echo "4. Click 'Load Model'"
    echo "5. Start chatting!"
else
    echo "❌ Model download may have failed. Check your internet connection."
fi
```

Save as `setup_mistral.sh`, make executable, and run:
```bash
chmod +x setup_mistral.sh
./setup_mistral.sh
```

---

## Support

If you still encounter issues:

1. Check the logs in MLX Code (View → Logs or ⌘L)
2. Verify Python dependencies: `pip3 list | grep -E "(mlx|sentencepiece|transformers)"`
3. Ensure model files are complete: `ls -lh ~/.mlx/models/mistral-7b-instruct-v0.3/`
4. Try a different model variant
5. Report the issue with logs

---

**Created by:** Jordan Koch & Claude (Anthropic)
**Date:** November 19, 2025
**Status:** ✅ Issue Resolved
