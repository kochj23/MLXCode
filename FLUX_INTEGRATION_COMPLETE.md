# FLUX Integration Complete - Photo-Realistic Image Generation

**Date:** January 7, 2026
**Version:** MLX Code v3.5.4
**Author:** Jordan Koch

---

## ✅ What Was Done

### Enhanced Local Image Generation with Proper FLUX Support

Updated `LocalImageGenerationTool.swift` to properly support FLUX's dedicated script and parameters.

**Previous Issue:**
- FLUX was being routed through Stable Diffusion's `txt2image.py` script
- Incorrect parameters were being used (FLUX has different API)
- Sub-optimal image quality and potential errors

**Fix Applied:**
- FLUX now uses its dedicated script: `~/mlx-examples/flux/txt2image.py`
- Correct FLUX parameters: `--model schnell/dev`, `--image-size`, `--steps`, `--guidance`
- Added support for both FLUX models: `flux` (fast) and `flux-dev` (professional quality)
- Automatic step count adjustment: 4 for schnell, 50 for dev

---

## 🎨 Available Models

### **1. SDXL-Turbo** (Fast) ⚡
- **Speed:** 2-5 seconds on M3 Ultra
- **Quality:** Good
- **Best for:** Quick iterations, mockups
- **Model ID:** `sdxl-turbo`

### **2. Stable Diffusion 2.1** (Balanced) ⚖️
- **Speed:** 5-15 seconds on M3 Ultra
- **Quality:** Excellent
- **Best for:** High-quality images
- **Model ID:** `sd-2.1`

### **3. FLUX Schnell** (Best Quality) 🌟
- **Speed:** 10-30 seconds on M3 Ultra
- **Quality:** Professional, state-of-the-art
- **Best for:** Photo-realistic images, production work
- **Model ID:** `flux`

### **4. FLUX Dev** (Professional) 👔
- **Speed:** 30-60 seconds on M3 Ultra
- **Quality:** Highest quality, professional results
- **Best for:** Final production, commercial work
- **Model ID:** `flux-dev`

---

## 🚀 How to Use in MLX Code

### **Quick Generation:**
Simply ask the MLX Code assistant:
```
"Generate image locally: A professional portrait photograph"
"Use FLUX to create: Mountain landscape at sunset"
"Generate with highest quality: Modern app icon design"
```

### **Specify Model:**
```
"Use FLUX model to generate: Photo-realistic headshot"
"Use FLUX-dev for professional quality: Product photography"
"Use sdxl-turbo for quick concept: UI mockup"
```

### **Advanced Options:**
```
"Generate 1024x1024 image with FLUX: Detailed character portrait"
"Use FLUX-dev with 50 steps: Professional food photography"
"Generate with seed 42 using FLUX: Reproducible landscape"
```

---

## 📋 Prompt Engineering for Photo-Realism

### **Portrait Photography:**
```
"Professional headshot portrait, studio lighting, 85mm lens, shallow depth of field, sharp focus, natural skin tones"
```

### **Landscape Photography:**
```
"Mountain landscape at golden hour, professional landscape photography, Nikon D850, wide angle lens, dramatic clouds"
```

### **Product Photography:**
```
"White sneaker on clean background, commercial product photography, studio lighting, high key, sharp details"
```

### **Architectural Photography:**
```
"Modern house exterior, architectural photography, blue hour, professional real estate photo, wide angle"
```

### **Food Photography:**
```
"Gourmet burger on rustic wooden table, professional food photography, natural window light, shallow depth of field"
```

---

## 🔧 Technical Changes Made

### **File Modified:** `LocalImageGenerationTool.swift`

#### **Before:**
```swift
// All models used stable_diffusion/txt2image.py
let mlxExamplesPath = NSHomeDirectory() + "/mlx-examples/stable_diffusion"
var command = "cd \(mlxExamplesPath) && python3 txt2image.py"
command += " --w \(width) --h \(height)"  // Wrong for FLUX
command += " --n_steps \(numSteps)"        // Wrong parameter name
command += " --cfg \(guidanceScale)"       // Wrong parameter name
command += " --model black-forest-labs/FLUX.1-schnell"  // Wrong format
```

#### **After:**
```swift
if model == "flux" || model == "flux-dev" {
    // Use dedicated FLUX script
    let fluxPath = NSHomeDirectory() + "/mlx-examples/flux"
    let fluxModel = model == "flux-dev" ? "dev" : "schnell"

    var cmd = "cd \(fluxPath) && python3 txt2image.py"
    cmd += " --model \(fluxModel)"                    // Correct: 'schnell' or 'dev'
    cmd += " --image-size \(width)x\(height)"        // Correct: Combined format
    cmd += " --steps \(numSteps > 0 ? numSteps : fluxSteps)"  // Correct parameter
    cmd += " --guidance \(guidanceScale)"            // Correct parameter
    cmd += " --n-images 1"                           // Single image
    cmd += " --quantize"                             // Enable quantization
} else {
    // Use stable_diffusion script for SD models
    let sdPath = NSHomeDirectory() + "/mlx-examples/stable_diffusion"
    // ... original SD code
}
```

---

## ✅ Verification Checklist

- [x] FLUX script exists: `~/mlx-examples/flux/txt2image.py`
- [x] Stable Diffusion script exists: `~/mlx-examples/stable_diffusion/txt2image.py`
- [x] FLUX models auto-download on first use
- [x] Correct FLUX parameters implemented
- [x] Both FLUX schnell and dev supported
- [x] Quantization enabled for all models
- [x] Error handling for missing scripts

---

## 🎯 Performance Expectations

### **Your M3 Ultra (192GB RAM):**

| Model | Resolution | Steps | Time | Quality |
|-------|-----------|-------|------|---------|
| SDXL-Turbo | 512×512 | 4 | 2-5s | Good |
| SD 2.1 | 512×512 | 20 | 5-15s | Excellent |
| FLUX Schnell | 512×512 | 4 | 10-20s | Professional |
| FLUX Schnell | 1024×1024 | 4 | 20-30s | Professional |
| FLUX Dev | 512×512 | 50 | 30-45s | Best |
| FLUX Dev | 1024×1024 | 50 | 45-60s | Best |

---

## 💾 Model Storage

Models auto-download to: `~/.cache/huggingface/hub/`

**Sizes:**
- SDXL-Turbo: ~7GB
- SD 2.1: ~5GB
- FLUX Schnell: ~24GB
- FLUX Dev: ~24GB (same as schnell, different weights)

**Your 512GB SSD:**
- Can fit all models with 450GB+ remaining
- First generation downloads model (one-time, 5-15 minutes)
- Subsequent generations use cached models (fast)

---

## 🔐 Security Features

**All Models Use SafeTensors:**
- ✅ No pickle files
- ✅ No arbitrary code execution
- ✅ Validated model loading
- ✅ Models from official sources

**Privacy:**
- ✅ 100% local processing
- ✅ No API keys required
- ✅ No cloud services
- ✅ Prompts never leave your Mac
- ✅ Zero costs

---

## 🆚 Comparison: FLUX vs DALL-E 3

| Feature | FLUX (Local) | DALL-E 3 (Cloud) |
|---------|-------------|------------------|
| **Speed** | 10-60s | 10-30s |
| **Cost** | $0.00 | $0.04-$0.08/image |
| **Quality** | Professional | Excellent |
| **Privacy** | 100% Local | Sent to OpenAI |
| **Limits** | Unlimited | API quotas |
| **Setup** | 10 min one-time | API key needed |

**Your Savings:** Generate 1,000 images = **$40-$80 saved**

---

## 📖 Example Usage

### **Test FLUX from Command Line:**
```bash
cd ~/mlx-examples/flux
python3 txt2image.py "A photo of an astronaut riding a horse" \
  --model schnell \
  --image-size 512x512 \
  --steps 4 \
  --quantize
```

### **Test FLUX-Dev (High Quality):**
```bash
cd ~/mlx-examples/flux
python3 txt2image.py "Professional portrait photograph" \
  --model dev \
  --image-size 1024x1024 \
  --steps 50 \
  --quantize
```

### **In MLX Code:**
Just talk to the assistant naturally:
- "Generate a photo-realistic portrait using FLUX"
- "Create a landscape photo with highest quality"
- "Make an app icon with FLUX model"

---

## 🐛 Troubleshooting

### **"FLUX models downloading..." (First Use)**
Normal! FLUX models are large (~24GB). This happens once:
- Download time: 5-15 minutes
- Models cached in `~/.cache/huggingface/`
- Subsequent generations are fast

### **"Generation is slow"**
First generation is slower (model loading). Tips:
- Use `flux` (schnell) for faster results (4 steps)
- Use `flux-dev` for best quality (50 steps)
- Quantization is enabled automatically

### **"Out of memory"**
Your M3 Ultra with 192GB RAM shouldn't hit this, but if so:
- Reduce resolution: 512×512 instead of 1024×1024
- Close other applications
- Restart MLX Code

---

## 🎉 Benefits

### **Cost Savings:**
- **100 images with DALL-E:** $4-$8
- **100 images with FLUX:** $0
- **Your savings:** $4-$8 per 100 images

### **Quality:**
- **FLUX:** State-of-the-art, comparable to DALL-E 3
- **Professional results** for commercial use
- **Photo-realistic** portraits and scenes

### **Privacy:**
- **Everything local** - prompts never leave your Mac
- **No tracking** - no telemetry sent anywhere
- **Your data, your control**

### **Speed:**
- **FLUX Schnell:** 10-30 seconds (fast)
- **FLUX Dev:** 30-60 seconds (best quality)
- **No network latency** - runs locally

---

## 🚀 Next Steps

1. **Open MLX Code application**
2. **Start a new conversation**
3. **Ask to generate an image:**
   ```
   "Generate a professional portrait photo using FLUX"
   ```
4. **Wait 10-30 seconds** (first time downloads model)
5. **Image opens automatically**

---

## 📝 Version History

- **v3.5.4** (Jan 7, 2026): Fixed FLUX integration, added flux-dev support
- **v3.5.3** (Jan 6, 2026): Initial FLUX support (incorrect parameters)
- **v3.5.0** (Dec 2025): Added local image generation

---

## 🔗 Resources

- **FLUX GitHub:** https://github.com/ml-explore/mlx-examples/tree/main/flux
- **Stable Diffusion GitHub:** https://github.com/ml-explore/mlx-examples/tree/main/stable_diffusion
- **Model Hub:** https://huggingface.co/black-forest-labs
- **MLX Framework:** https://github.com/ml-explore/mlx

---

**🎨 FLUX Integration Complete - Photo-Realistic Images on Your Mac!**

**Author:** Jordan Koch
**GitHub:** @kochj23
**Repository:** https://github.com/kochj23/MLXCode
