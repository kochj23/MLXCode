# FLUX User Guide - Photo-Realistic Images in MLX Code

**Quick Start Guide for Photo-Realistic Image Generation**

---

## 🚀 Quick Start (30 Seconds)

### **1. Launch MLX Code:**
```bash
open ~/Applications/MLX\ Code.app
```

### **2. Start a conversation and ask:**
```
"Generate a professional portrait photo using FLUX"
```

### **3. Wait 10-30 seconds** (first time downloads model)

### **4. Image opens automatically!**

---

## 🎨 Simple Examples

### **Portrait Photography:**
```
"Generate using FLUX: Professional headshot, studio lighting, sharp focus"
```

### **Landscape Photography:**
```
"Use FLUX to create: Mountain landscape at golden hour"
```

### **Product Photography:**
```
"Generate with FLUX-dev: White sneaker on clean background, studio lighting"
```

### **App Icon Design:**
```
"Use FLUX: Modern app icon, blue gradient, minimalist design"
```

---

## 🌟 Model Selection

### **Just mention the model in your request:**

**Fast (10-30s):**
```
"Generate with FLUX: [your prompt]"
"Use FLUX model: [your prompt]"
```

**Best Quality (30-60s):**
```
"Generate with FLUX-dev: [your prompt]"
"Use highest quality: [your prompt]"
```

**Quick (2-5s):**
```
"Generate quickly: [your prompt]"
(Uses SDXL-Turbo automatically)
```

---

## 💡 Prompt Tips for Photo-Realism

### **The Formula:**
```
[Subject] + [Photography Type] + [Lighting] + [Technical Details]
```

### **Examples:**

**Portrait:**
```
"Woman with brown hair, professional portrait photography,
natural window lighting, 85mm lens, shallow depth of field"
```

**Landscape:**
```
"Mountain valley at sunset, landscape photography,
golden hour, dramatic sky, wide angle lens, Nikon D850"
```

**Product:**
```
"Smartphone on marble surface, commercial product photography,
soft studio lighting, high key, sharp focus, clean background"
```

**Architecture:**
```
"Modern house exterior, architectural photography,
blue hour, professional real estate photo, wide angle"
```

**Food:**
```
"Gourmet burger on wooden table, food photography,
natural window light, shallow depth of field, Michelin style"
```

---

## 📊 Model Comparison

| Ask for... | Model Used | Speed | Quality | Best For |
|-----------|-----------|-------|---------|----------|
| "FLUX" | FLUX Schnell | 10-30s | Professional | Photo-realistic |
| "FLUX-dev" | FLUX Dev | 30-60s | Best | Final production |
| "High quality" | SD 2.1 | 5-15s | Excellent | General use |
| "Quick" | SDXL-Turbo | 2-5s | Good | Fast concepts |

---

## 🎯 Real-World Examples

### **App Icon Design:**
```
"Use FLUX: Modern weather app icon, blue sky gradient,
minimalist design, white clouds, flat style, 1024x1024"
```

### **Profile Picture:**
```
"Generate with FLUX: Professional LinkedIn profile photo,
business casual, studio lighting, plain background, headshot"
```

### **Website Hero Image:**
```
"Use FLUX-dev: Modern office workspace, professional photography,
natural lighting, MacBook on desk, plants, minimalist"
```

### **Marketing Material:**
```
"Generate with FLUX: Coffee cup on cafe table,
lifestyle photography, morning light, Instagram style"
```

### **Album Cover:**
```
"Use FLUX-dev: Abstract geometric shapes, vibrant colors,
album art style, high resolution, professional design"
```

---

## ⚡ First Time Setup (One-Time)

### **If you haven't installed MLX examples:**

```bash
# 1. Clone MLX examples (5 minutes)
git clone https://github.com/ml-explore/mlx-examples.git ~/mlx-examples

# 2. Install FLUX (2 minutes)
cd ~/mlx-examples/flux
pip3 install -r requirements.txt

# 3. Done! FLUX is ready
```

**First Image Generation:**
- Downloads FLUX model (~24GB, 5-15 minutes)
- Happens automatically
- Only happens once
- Subsequent images are fast

---

## 💰 Cost Comparison

### **Generate 100 Images:**
- **DALL-E 3:** $4-$8
- **FLUX (You):** $0 ✅

### **Generate 1,000 Images:**
- **DALL-E 3:** $40-$80
- **FLUX (You):** $0 ✅

### **Generate 10,000 Images:**
- **DALL-E 3:** $400-$800
- **FLUX (You):** $0 ✅

---

## 🔐 Privacy & Security

**Everything Stays on Your Mac:**
- ✅ Prompts never leave your computer
- ✅ Images generated locally
- ✅ No API keys needed
- ✅ No cloud services
- ✅ No tracking or telemetry
- ✅ Complete privacy

**Model Security:**
- ✅ SafeTensors format (no code execution)
- ✅ Official sources only (Hugging Face)
- ✅ Validated downloads
- ✅ No malware risk

---

## 🎬 Step-by-Step Example

### **Let's create a professional portrait:**

**1. Launch MLX Code**

**2. New conversation**

**3. Type:**
```
Generate a professional portrait photo using FLUX:
Young woman, business professional, studio lighting,
grey background, headshot, sharp focus, natural makeup,
professional photography
```

**4. Wait ~15 seconds**

**5. Image opens automatically in Preview**

**6. Save wherever you want!**

---

## 🔄 Reproducible Images

### **Want the same image again? Use a seed:**

```
"Generate with FLUX using seed 42:
[your exact prompt]"
```

**Same seed + same prompt = identical image**

---

## 📐 Size Options

### **Default:** 512×512 (fast)
```
"Generate with FLUX: [prompt]"
```

### **Large:** 1024×1024 (slower but better)
```
"Generate 1024x1024 image with FLUX: [prompt]"
```

### **Portrait:** 512×768
```
"Generate portrait-sized image with FLUX: [prompt]"
```

### **Landscape:** 768×512
```
"Generate landscape-sized image with FLUX: [prompt]"
```

---

## 🐛 Troubleshooting

### **"Downloading models..." (First Use)**
✅ Normal! FLUX is ~24GB. Takes 5-15 minutes once.

### **"Generation is slow"**
✅ First generation loads model. Subsequent ones are fast.

### **"Out of memory"**
Try:
- Use smaller resolution: "Generate 512x512..."
- Close other apps
- Use "FLUX" instead of "FLUX-dev"

### **"Image quality not good"**
Improve your prompt:
- Add photography keywords: "professional", "studio lighting"
- Specify technical details: "85mm lens", "shallow depth"
- Add quality terms: "sharp focus", "high resolution"

---

## 💎 Pro Tips

### **1. Be Specific:**
❌ "A person"
✅ "Woman in her 30s, professional business suit, confident expression"

### **2. Add Photography Terms:**
❌ "Nice lighting"
✅ "Studio lighting, softbox, high key, professional"

### **3. Specify Technical Details:**
❌ "Good camera"
✅ "Canon 5D Mark IV, 85mm lens, f/1.8, shallow depth of field"

### **4. Reference Styles:**
❌ "Make it look good"
✅ "National Geographic style, professional nature photography"

### **5. Quality Boosters:**
Add these to any prompt:
- "professional photography"
- "high resolution"
- "sharp focus"
- "detailed"
- "studio quality"

---

## 🎨 Style Keywords

### **Portrait Photography:**
- studio lighting, softbox, rim light
- 85mm lens, shallow depth of field
- professional headshot, business portrait
- natural skin tones, sharp focus

### **Landscape Photography:**
- golden hour, blue hour, dramatic sky
- wide angle lens, HDR, panoramic
- National Geographic style
- professional landscape photography

### **Product Photography:**
- studio lighting, clean background
- high key, commercial photography
- sharp details, product shot
- minimalist composition

### **Architectural Photography:**
- architectural photography, symmetrical
- wide angle, professional real estate
- blue hour, twilight, modern design

---

## 📱 Social Media Sizes

### **Instagram Post:** 1024×1024
```
"Generate 1024x1024 Instagram post with FLUX: [prompt]"
```

### **Instagram Story:** 1080×1920
```
"Generate 512x1024 vertical image with FLUX: [prompt]"
```

### **Twitter Header:** 1500×500
```
"Generate wide banner with FLUX: [prompt]"
```

### **LinkedIn Post:** 1200×627
```
"Generate 1024x512 professional image with FLUX: [prompt]"
```

---

## ⏱️ Expected Times (M3 Ultra)

| Resolution | Model | Steps | Time |
|-----------|-------|-------|------|
| 512×512 | FLUX | 4 | 10-15s |
| 512×512 | FLUX-dev | 50 | 30-40s |
| 1024×1024 | FLUX | 4 | 20-30s |
| 1024×1024 | FLUX-dev | 50 | 45-60s |

---

## 🎯 Use Cases

### **Personal:**
- Profile pictures
- Social media content
- Digital art
- Creative projects

### **Professional:**
- App icons and logos
- Marketing materials
- Website images
- Presentations
- Product mockups

### **Creative:**
- Concept art
- Storyboarding
- Character design
- Scene visualization

---

## 🌟 You're Ready!

**That's it! Just talk naturally to MLX Code:**

```
"Generate a professional portrait using FLUX"
"Create a landscape photo with highest quality"
"Make an app icon with FLUX model"
"Use FLUX-dev for a product photo"
```

**It's that simple!**

---

## 📞 Need Help?

- **In-app Help:** Cmd+? in MLX Code
- **Documentation:** `/Volumes/Data/xcode/MLX Code/FLUX_INTEGRATION_COMPLETE.md`
- **GitHub Issues:** https://github.com/kochj23/MLXCode/issues

---

**Enjoy unlimited photo-realistic image generation on your Mac!** 🎨

**Author:** Jordan Koch (@kochj23)
**Version:** MLX Code v3.5.4
