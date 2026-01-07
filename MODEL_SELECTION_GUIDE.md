# MLX Code - Model Selection Guide

**Version:** 3.5.2
**Date:** January 6, 2026

---

## 🎯 Quick Recommendation

**Use:** **Qwen 2.5 7B** or **Mistral 7B**

These are the best models for coding tasks and won't cause infinite loops.

---

## 📊 All 9 Available Models

### **⭐ RECOMMENDED (Start Here)**

#### **1. Qwen 2.5 7B ⭐⭐⭐⭐⭐**
- **Best for:** General coding, instruction following
- **Quality:** Excellent
- **Speed:** Fast on M3 Ultra
- **Size:** ~4GB
- **Loops:** No
- **HuggingFace:** mlx-community/Qwen2.5-7B-Instruct-4bit

**Why recommended:** Best balance of quality, speed, and reliability.

---

#### **2. Mistral 7B v0.3 ⭐⭐⭐⭐⭐**
- **Best for:** General coding, versatile
- **Quality:** Excellent
- **Speed:** Fast
- **Size:** ~4GB
- **Loops:** No
- **HuggingFace:** mlx-community/Mistral-7B-Instruct-v0.3-4bit

**Why recommended:** Very popular, well-tested, reliable.

---

### **🏆 BEST QUALITY (If You Have Storage)**

#### **3. Qwen 2.5 14B**
- **Best for:** Complex tasks, highest quality
- **Quality:** Best available
- **Speed:** Slower (but fast enough on M3 Ultra)
- **Size:** ~8GB
- **Loops:** No
- **HuggingFace:** mlx-community/Qwen2.5-14B-Instruct-4bit

**Use if:** You want the absolute best quality and have storage space.

---

#### **4. Gemma 2 9B**
- **Best for:** General coding, Google's model
- **Quality:** Excellent
- **Speed:** Medium
- **Size:** ~5GB
- **Loops:** No
- **HuggingFace:** mlx-community/gemma-2-9b-it-4bit

**Use if:** You prefer Google's models or want diversity.

---

### **💻 CODE-SPECIALIZED (For Programming)**

#### **5. DeepSeek Coder 6.7B**
- **Best for:** Code generation, programming tasks
- **Quality:** Excellent for code
- **Speed:** Fast
- **Size:** ~4GB
- **Loops:** No
- **HuggingFace:** mlx-community/deepseek-coder-6.7b-instruct

**Use if:** You primarily do coding tasks (not general chat).

---

#### **6. CodeLlama 7B**
- **Best for:** Code generation, Meta's code model
- **Quality:** Very good for code
- **Speed:** Fast
- **Size:** ~4GB
- **Loops:** No
- **HuggingFace:** mlx-community/CodeLlama-7b-Instruct-hf-4bit-MLX

**Use if:** You want Meta's code-specialized model.

---

### **⚡ FAST & COMPACT**

#### **7. Phi-3.5 Mini**
- **Best for:** Quick responses, low memory
- **Quality:** Good (smaller model)
- **Speed:** Very fast
- **Size:** ~2GB
- **Loops:** Unlikely
- **HuggingFace:** mlx-community/Phi-3.5-mini-instruct-4bit

**Use if:** You want fastest possible responses.

---

#### **8. Llama 3.1 8B**
- **Best for:** General use, Meta's model
- **Quality:** Good
- **Speed:** Fast
- **Size:** ~5GB
- **Loops:** No
- **HuggingFace:** mlx-community/Meta-Llama-3.1-8B-Instruct-4bit

**Use if:** You prefer Meta's models.

---

### **❌ NOT RECOMMENDED**

#### **9. Llama 3.2 3B**
- **Issues:** Too small, causes infinite loops
- **Quality:** Poor
- **Loops:** YES - generates fake conversations
- **Size:** ~2GB
- **Status:** Kept for backwards compatibility only

**DO NOT USE** - This is the broken model causing loops.

---

## 🔄 How to Switch Models

### **In MLX Code:**

1. **Click Settings** (gear icon)
2. **Go to Models tab**
3. **Select from dropdown:**
   - Qwen 2.5 7B (recommended)
   - Mistral 7B (popular)
   - Or any other model
4. **Click Download** (if not downloaded)
5. **Wait 5-15 minutes** (one-time per model)
6. **Start new conversation**

---

## 💾 Storage Requirements

**Your 512GB SSD:**
- ✅ Can fit ALL 9 models (total: ~42GB)
- ✅ Still have 470GB free
- ✅ No storage concerns

**Recommended to download:**
- Qwen 2.5 7B (~4GB)
- Mistral 7B (~4GB)
- Total: ~8GB

**Try larger if needed:**
- Qwen 2.5 14B (~8GB) for best quality

---

## ⚡ Performance on M3 Ultra

| Model | Size | Speed | Quality | Recommended |
|-------|------|-------|---------|-------------|
| **Qwen 2.5 7B** | 4GB | Fast | Excellent | ⭐⭐⭐⭐⭐ |
| **Mistral 7B** | 4GB | Fast | Excellent | ⭐⭐⭐⭐⭐ |
| **Qwen 2.5 14B** | 8GB | Medium | Best | ⭐⭐⭐⭐ |
| **DeepSeek Coder** | 4GB | Fast | Excellent (code) | ⭐⭐⭐⭐ |
| **CodeLlama** | 4GB | Fast | Very Good (code) | ⭐⭐⭐⭐ |
| **Gemma 2 9B** | 5GB | Medium | Excellent | ⭐⭐⭐⭐ |
| **Llama 3.1 8B** | 5GB | Fast | Good | ⭐⭐⭐ |
| **Phi-3.5 Mini** | 2GB | Very Fast | Good | ⭐⭐⭐ |
| **Llama 3.2 3B** | 2GB | Fast | Poor | ❌ |

---

## 🎯 My Recommendations

### **For Most Users:**
Start with **Qwen 2.5 7B**
- Best quality/speed balance
- Excellent instruction following
- Won't loop
- 4GB (reasonable size)

### **If You Want Popular:**
Use **Mistral 7B**
- Very popular model
- Well-tested
- Reliable
- 4GB

### **If You Want Best Quality:**
Use **Qwen 2.5 14B**
- Highest quality
- Worth the extra storage
- 8GB

### **If You Primarily Code:**
Use **DeepSeek Coder 6.7B**
- Specialized for programming
- Best for code generation
- 4GB

---

## 🚀 Getting Started

**Step 1:** Open MLX Code (already running)

**Step 2:** Go to Settings → Models

**Step 3:** Select "Qwen 2.5 7B ⭐ RECOMMENDED"

**Step 4:** Click "Download Model"

**Step 5:** Wait 10-15 minutes (grabs coffee ☕)

**Step 6:** Start chatting!

---

## 🐛 Known Issues

**Llama 3.2 3B:**
- ❌ Generates infinite fake conversations
- ❌ Loops on simple questions
- ❌ DO NOT USE

**Fix:** Use any 7B+ model instead!

---

**All models are properly configured, all have HuggingFace IDs, all will work!**

**Default is now Qwen 2.5 7B - much better than Llama 3.2 3B!**
