# Local Image Generation Setup - Zero API Keys, 100% Free

**Run Stable Diffusion on Your M3 Ultra - No Cloud, No Costs**

---

## 🎯 Goal

Generate images entirely on your Mac using Apple's MLX framework:
- ✅ No API keys
- ✅ No cloud services
- ✅ No per-image costs
- ✅ 100% private
- ✅ Runs on Apple Silicon (M1/M2/M3)

---

## ⚡ Quick Start (10 Minutes)

```bash
# 1. Clone Apple's MLX examples
git clone https://github.com/ml-explore/mlx-examples.git ~/mlx-examples

# 2. Install Stable Diffusion dependencies
cd ~/mlx-examples/stable_diffusion
pip3 install -r requirements.txt

# 3. Test generation
python3 txt2image.py "A photo of an astronaut riding a horse on Mars"
```

**First run:** Downloads models (~3-7GB, 5-15 minutes)
**Subsequent runs:** Fast (models cached)

---

## 🎨 Available Models

### **1. SDXL-Turbo** (Recommended) ⭐⭐⭐⭐⭐

**Speed:** 2-5 seconds on M3 Ultra
**Quality:** Good, fast results
**Size:** ~7GB
**Best for:** Quick iterations, concept art, mockups
**Model:** `stabilityai/sdxl-turbo`

**Command:**
```bash
python3 txt2image.py "your prompt" --model stabilityai/sdxl-turbo
```

---

### **2. Stable Diffusion 2.1** ⭐⭐⭐⭐

**Speed:** 5-15 seconds on M3 Ultra
**Quality:** Excellent, detailed
**Size:** ~5GB
**Best for:** High-quality images, detailed scenes
**Model:** `stabilityai/stable-diffusion-2-1`

**Command:**
```bash
python3 txt2image.py "your prompt" --model stabilityai/stable-diffusion-2-1
```

---

### **3. FLUX** ⭐⭐⭐⭐⭐ (Best Quality)

**Speed:** 10-30 seconds on M3 Ultra
**Quality:** Professional, state-of-the-art
**Size:** ~24GB
**Best for:** Production images, professional work
**Model:** `black-forest-labs/FLUX.1-schnell`

**Command:**
```bash
cd ~/mlx-examples/flux
python3 flux.py "your prompt"
```

---

## 🚀 Performance on Your M3 Ultra

**Your Hardware:**
- 60-76 GPU cores
- 192GB unified memory
- Neural Engine

**Expected Speed:**

| Model | Resolution | Speed | Quality |
|-------|------------|-------|---------|
| SDXL-Turbo | 512×512 | 2-5s | Good |
| SDXL-Turbo | 1024×1024 | 5-10s | Good |
| SD 2.1 | 512×512 | 5-10s | Excellent |
| SD 2.1 | 768×768 | 10-15s | Excellent |
| FLUX | 512×512 | 10-15s | Professional |
| FLUX | 1024×1024 | 20-30s | Professional |

**Comparison to DALL-E 3:**
- DALL-E: 10-30s (cloud) + $0.04/image
- MLX Local: 2-30s (local) + $0.00/image
- **Similar speed, ZERO cost!**

---

## 📦 Installation Steps

### **Step 1: Clone MLX Examples**
```bash
cd ~
git clone https://github.com/ml-explore/mlx-examples.git
```

### **Step 2: Install Stable Diffusion**
```bash
cd ~/mlx-examples/stable_diffusion
pip3 install -r requirements.txt
```

**Dependencies installed:**
- huggingface-hub (model downloads)
- PIL (image processing)
- numpy
- mlx (if not already installed)

### **Step 3: Test Generation**
```bash
python3 txt2image.py "A cute cat wearing a wizard hat"
```

**First run:**
- Downloads SDXL-Turbo model (~7GB)
- Takes 5-15 minutes
- Shows progress: "Downloading model..."

**Output:**
- Generates image: `out.png`
- Opens automatically

### **Step 4: (Optional) Install FLUX**
```bash
cd ~/mlx-examples/flux
pip3 install -r requirements.txt
```

**Model size:** ~24GB (highest quality)

---

## 🎮 Usage in MLX Code

Once installed, use in MLX Code:

### **Generate Image:**
```
"Generate image locally: A modern app icon for a weather app"
"Use SDXL-Turbo to create: Mountain landscape at sunset"
"Generate with FLUX: Professional headshot of a developer"
```

### **With Specific Parameters:**
```
"Generate 1024x1024 image with 20 steps: Futuristic city skyline"
"Use SD 2.1 model at high quality: Detailed character portrait"
```

### **Save to Specific Location:**
```
"Generate image and save to ~/Desktop/icon.png: App icon design"
```

---

## 📋 Model Comparison

### **SDXL-Turbo (Fast):**
**Pros:**
- ✅ Very fast (2-5 seconds)
- ✅ Good quality
- ✅ Smaller model (7GB)
- ✅ Great for iteration

**Cons:**
- ⚠️ Lower detail than SD 2.1
- ⚠️ Limited steps (optimized for 4)

**Best for:** Quick mockups, concept art, UI ideas

---

### **SD 2.1 (Balanced):**
**Pros:**
- ✅ Excellent quality
- ✅ More steps = better detail
- ✅ Versatile
- ✅ 5GB model

**Cons:**
- ⚠️ Slower than Turbo (5-15s)
- ⚠️ Not as cutting-edge as FLUX

**Best for:** Production images, detailed scenes

---

### **FLUX (Best):**
**Pros:**
- ✅ State-of-the-art quality
- ✅ Professional results
- ✅ Best text rendering
- ✅ Best prompt adherence

**Cons:**
- ⚠️ Slowest (10-30s)
- ⚠️ Largest model (24GB)
- ⚠️ Requires more RAM

**Best for:** Final production images, professional work

---

## 💾 Storage Requirements

**Per Model:**
- SDXL-Turbo: ~7GB
- SD 2.1: ~5GB
- FLUX: ~24GB

**Recommendations:**
- **Start with:** SDXL-Turbo (7GB, fast)
- **Add later:** SD 2.1 (5GB, quality)
- **If space allows:** FLUX (24GB, best)

**Your 512GB SSD:**
- ✅ Can fit all three models
- ✅ Still have 470GB+ free
- ✅ No storage concerns!

---

## 🔧 Advanced Options

### **Higher Resolution:**
```bash
python3 txt2image.py "your prompt" --w 1024 --h 1024 --n_steps 20
```

### **Batch Generation:**
```bash
python3 txt2image.py "your prompt" --n_images 4 --n_rows 2
```

### **Reproducible Results:**
```bash
python3 txt2image.py "your prompt" --seed 42
```

### **Image-to-Image (Variations):**
```bash
python3 img2img.py input.png "enhance this image" --strength 0.8
```

---

## 🔄 Model Management

### **Download Models Manually:**
```bash
cd ~/mlx-examples/stable_diffusion

# Download SDXL-Turbo
python3 txt2image.py "test" --model stabilityai/sdxl-turbo

# Download SD 2.1
python3 txt2image.py "test" --model stabilityai/stable-diffusion-2-1
```

### **Check Downloaded Models:**
```bash
ls -lh ~/.cache/huggingface/hub/models--stabilityai--*
```

### **Remove Models (Free Space):**
```bash
rm -rf ~/.cache/huggingface/hub/models--stabilityai--*
```

---

## 💡 Pro Tips

### **1. Prompt Engineering:**
**Good prompts:**
- "Professional app icon, minimalist design, blue and white color scheme, flat design, 4k"
- "Modern UI mockup, clean interface, iOS style, light mode, sharp"

**Better than:**
- "app icon" (too vague)

### **2. Speed vs Quality:**
- **Fast iteration:** Use SDXL-Turbo with 4 steps
- **Final output:** Use SD 2.1 with 20-30 steps
- **Best quality:** Use FLUX with 20-30 steps

### **3. Consistent Results:**
- Use same seed for similar outputs
- Adjust guidance_scale for prompt adherence
- More steps = better quality but slower

### **4. Memory Optimization:**
- Use `--quantize` flag for faster inference
- Reduce resolution if running low on memory
- Your M3 Ultra: Won't have issues!

---

## 🆚 Comparison: Local vs Cloud

### **MLX Stable Diffusion (Local):**
- **Speed:** 2-30 seconds (depending on model)
- **Cost:** $0.00 (FREE)
- **Privacy:** ✅ 100% local
- **Quality:** Good to professional
- **Limits:** None (unlimited generations)
- **Setup:** 10 minutes one-time
- **Storage:** 5-24GB per model

### **DALL-E 3 (Cloud):**
- **Speed:** 10-30 seconds
- **Cost:** $0.04 per standard, $0.08 per HD
- **Privacy:** ⚠️ Sent to OpenAI
- **Quality:** Excellent
- **Limits:** Based on API quota
- **Setup:** Get API key
- **Storage:** 0GB (cloud-based)

### **Your Savings:**
Generate 100 images:
- **DALL-E:** $4.00
- **MLX Local:** $0.00

Generate 1,000 images:
- **DALL-E:** $40.00
- **MLX Local:** $0.00

---

## 🔐 Security

**SafeTensors Models:**
- ✅ All models from Hugging Face use SafeTensors
- ✅ No pickle files
- ✅ No code execution risk
- ✅ Validated by ModelSecurityValidator

**Privacy:**
- ✅ Prompts stay on your Mac
- ✅ Images generated locally
- ✅ No telemetry
- ✅ No tracking

---

## 🐛 Troubleshooting

### **"MLX Stable Diffusion not installed"**
```bash
git clone https://github.com/ml-explore/mlx-examples.git ~/mlx-examples
cd ~/mlx-examples/stable_diffusion
pip3 install -r requirements.txt
```

### **"Models downloading..." (First Use)**
Normal! Models are large:
- SDXL-Turbo: ~7GB
- Takes 5-15 minutes
- Only happens once

### **"Out of memory"**
Try:
- Use `--quantize` flag
- Reduce resolution: `--w 512 --h 512`
- Your M3 Ultra: This shouldn't happen!

### **"Generation is slow"**
First generation is slower (model loading).
Subsequent generations are fast.

Your M3 Ultra with 192GB:
- SDXL-Turbo: 2-5s
- SD 2.1: 5-15s
- FLUX: 10-30s

---

## ✅ Verification

```bash
# 1. Check MLX examples installed
ls ~/mlx-examples/stable_diffusion/txt2image.py

# 2. Check dependencies
cd ~/mlx-examples/stable_diffusion
python3 -c "import mlx.core; print('✅ MLX ready')"

# 3. Generate test image
python3 txt2image.py "test image"

# 4. Check models cached
ls -lh ~/.cache/huggingface/hub/models--stabilityai--*
```

---

## 🎉 Benefits

### **Cost Savings:**
- **DALL-E:** $0.04 per image
- **MLX Local:** $0.00 per image
- **Your savings:** $4 per 100 images, $40 per 1,000 images

### **Performance:**
- **DALL-E:** 10-30s + network latency
- **MLX on M3 Ultra:** 2-30s (no network)
- **Similar or faster!**

### **Privacy:**
- **DALL-E:** Prompts sent to OpenAI
- **MLX Local:** Everything stays on your Mac

### **Unlimited:**
- **DALL-E:** Rate limits, quotas
- **MLX Local:** Generate as many as you want!

---

## 🚀 You're Ready!

**Once installed:**
```
"Generate image locally: A beautiful sunset over mountains"
"Use SD 2.1 to create: App icon for a weather app"
"Generate with FLUX at highest quality: Professional headshot"
```

**All images:**
- ✅ Generated on your Mac
- ✅ Zero costs
- ✅ Complete privacy
- ✅ Unlimited generations

---

## 🔗 Resources

**Apple MLX Examples:**
- Stable Diffusion: https://github.com/ml-explore/mlx-examples/tree/main/stable_diffusion
- FLUX: https://github.com/ml-explore/mlx-examples/tree/main/flux

**Model Sources:**
- Hugging Face: https://huggingface.co/stabilityai
- All models are SafeTensors format (secure)

**Alternative UIs:**
- ComfyUI (if you prefer node-based UI)
- Stable Diffusion WebUI (web interface)
- MLX Code (integrated, this tool!)

---

**LOCAL IMAGE GENERATION = No API keys + No costs + Complete privacy!** 🎨
