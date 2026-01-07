# Text-to-Speech & Voice Cloning - User Guide

**MLX Code v3.4.0**
**Date:** January 6, 2026
**Author:** Jordan Koch

---

## 🎙️ Overview

MLX Code now includes three powerful TTS (Text-to-Speech) tools:
1. **Native macOS TTS** - Fast, built-in, zero setup
2. **MLX-Audio TTS** - High-quality, Apple Silicon optimized
3. **Voice Cloning** - Clone any voice from 5-10 second sample

**All tools follow strict security protocols:**
- ✅ SafeTensors models only
- ✅ No pickle/unsafe formats
- ✅ No arbitrary code execution
- ✅ Validated inputs
- ✅ Audit logging

---

## 🔊 Tool 1: Native macOS TTS

### **Overview:**
- Uses built-in macOS AVSpeechSynthesizer
- 40+ languages supported
- Multiple voices per language
- **Setup:** None required!
- **Security:** 100% safe (no external code)
- **Speed:** Instant
- **Cost:** Free

### **Usage:**

Ask naturally:
```
"Read this error message aloud"
"Speak: Hello World"
"Convert this text to speech in Spanish"
```

Or specify parameters:
```
"Use native TTS to speak 'Welcome to my app' in Japanese"
"Read this slowly with voice Samantha"
```

### **Parameters:**
- `text` (required) - Text to speak
- `language` (optional) - Language code (e.g., 'en-US', 'es-ES', 'ja-JP')
- `rate` (optional) - Speed 0.0-1.0 (default: 0.5)
- `voice_name` (optional) - Specific voice (e.g., 'Samantha', 'Alex', 'Daniel')
- `save_to` (optional) - Save to file path

### **Examples:**

**Basic speech:**
```
"Speak: The quick brown fox jumps over the lazy dog"
```

**Specific language:**
```
"Read this in French: Bonjour le monde"
```

**Save to file:**
```
"Generate speech and save to ~/audio/welcome.aiff"
```

### **Available Voices:**

**English:** Alex, Samantha, Victoria, Fred, Daniel, Karen, Moira, Tessa
**Spanish:** Monica, Paulina, Juan
**French:** Thomas, Amelie
**German:** Anna, Markus
**Japanese:** Kyoko, Otoya
**Many more...** (40+ languages total)

---

## 🎨 Tool 2: MLX-Audio TTS (High Quality)

### **Overview:**
- Apple Silicon optimized (M1/M2/M3)
- 7 TTS models included
- Voice cloning support (CSM model)
- **Setup:** `pip install mlx-audio`
- **Security:** SafeTensors only, validated
- **Speed:** 1-3 seconds per sentence (on M3 Ultra)
- **Cost:** Free

### **Installation:**

```bash
pip install mlx-audio
```

First use will download models (~500MB-2GB depending on model).
All models are SafeTensors format (security validated).

### **Models:**

1. **Kokoro** - Fast, high-quality, multilingual (8 languages)
2. **CSM** - Supports voice cloning
3. **Chatterbox** - Expressive, 16 languages
4. **Dia** - Dialogue-focused
5. **OuteTTS** - Efficient
6. **SparkTTS** - English & Chinese
7. **Soprano** - High quality

### **Usage:**

```
"Use MLX-Audio to speak: Welcome to my application"
"Generate high-quality speech with Kokoro model"
"Use Chatterbox model for expressive narration"
```

### **Parameters:**
- `text` (required) - Text to speak
- `model` (optional) - Model name (default: 'kokoro')
- `voice` (optional) - Voice ID (model-specific)
- `speed` (optional) - 0.5-2.0 (default: 1.0)
- `reference_audio` (optional) - For voice cloning (CSM model)
- `save_to` (optional) - Save to file path

### **Examples:**

**Basic usage:**
```
"Use MLX-Audio to read this documentation"
```

**Specific model:**
```
"Use Chatterbox model to speak with emotion: I'm so excited about this feature!"
```

**Adjust speed:**
```
"Speak this slowly at 0.7 speed using MLX-Audio"
```

**Save to file:**
```
"Generate audio with Kokoro and save to ~/tutorial.wav"
```

---

## 🎤 Tool 3: Voice Cloning (F5-TTS-MLX)

### **Overview:**
- Zero-shot voice cloning
- Requires only 5-10 seconds of reference audio
- Excellent quality
- **Setup:** `pip install f5-tts-mlx`
- **Security:** SafeTensors only, validated
- **Speed:** ~4 seconds on M3 Max (faster on M3 Ultra)
- **Cost:** Free

### **Installation:**

```bash
pip install f5-tts-mlx
```

First use will download models (~2GB SafeTensors).

### **Voice Cloning Process:**

**Step 1: Record Reference Audio (5-10 seconds)**
- Use QuickTime Player → File → New Audio Recording
- Speak clearly in a quiet environment
- Save as .wav file (recommended) or .mp3
- Example text: "The quick brown fox jumps over the lazy dog. This is a sample of my voice for cloning purposes."

**Step 2: Clone Voice**
```
"Clone voice from ~/my_voice.wav and say: Welcome to my app"
```

### **Parameters:**
- `text` (required) - Text to speak in cloned voice
- `reference_audio` (required) - Path to 5-10 second audio sample
- `reference_text` (optional) - Transcript of reference audio (improves quality)
- `speed` (optional) - 0.5-2.0 (default: 1.0)
- `save_to` (optional) - Save to file path

### **Examples:**

**Basic cloning:**
```
"Clone my voice from ~/voice_sample.wav and read this tutorial"
```

**With transcript (better quality):**
```
"Clone voice from ~/sample.wav with transcript 'Hello world' and say: This is a test"
```

**Adjust speed:**
```
"Clone voice and speak faster at 1.5x speed"
```

**Save output:**
```
"Clone voice and save to ~/voiceover.wav"
```

### **Tips for Best Quality:**

1. **Reference Audio:**
   - 5-10 seconds duration
   - Clear, no background noise
   - Natural speaking pace
   - Single speaker only
   - 24kHz WAV format ideal

2. **Reference Text:**
   - Provide exact transcript
   - Improves pronunciation
   - Optional but recommended

3. **Output:**
   - Will sound very similar to reference
   - Works best with clear source audio
   - Can clone any voice (accent, tone, style)

---

## 🔒 Security Features

### **All TTS Tools Include:**

1. **Model Validation**
   - Only SafeTensors format loaded
   - Pickle/PyTorch files blocked
   - Source verification

2. **Input Validation**
   - Text length limits
   - Audio file format checking
   - Path validation

3. **Audit Logging**
   - All operations logged
   - Security events tracked
   - Log location: `~/Library/Logs/MLXCode/security.log`

4. **No Code Execution**
   - No eval/exec
   - No arbitrary imports
   - Controlled subprocess only

---

## 💡 Use Cases

### **Development:**
- Listen to code comments
- Hear error messages read aloud
- Audio documentation
- Accessibility testing

### **Content Creation:**
- Voiceovers for app tutorials
- Demo videos with narration
- UI sound effects
- Accessibility features

### **Prototyping:**
- Quick voice UI mockups
- Audio feedback testing
- Voice command responses

### **Voice Cloning:**
- Consistent voice for series
- Client voice for demos
- Personal assistant voice
- Brand voice identity

---

## ⚙️ Configuration

### **Native TTS:**
No configuration needed!

### **MLX-Audio:**
```bash
# Install
pip install mlx-audio

# Verify
python3 -c "import mlx_audio; print(mlx_audio.__version__)"
```

### **F5-TTS-MLX:**
```bash
# Install
pip install f5-tts-mlx

# Verify
python3 -c "import f5_tts_mlx; print(f5_tts_mlx.__version__)"
```

### **For Image Generation (DALL-E):**
```bash
# Set API key
export OPENAI_API_KEY="sk-..."

# Or add to MLXCode settings
```

---

## 🐛 Troubleshooting

### **"mlx-audio not installed"**
Run: `pip install mlx-audio`

### **"F5-TTS-MLX not installed"**
Run: `pip install f5-tts-mlx`

### **"Models downloading..."**
First use downloads models (2-5 minutes). Subsequent uses are fast.

### **"Reference audio file not found"**
Use full path: `~/voice.wav` or `/Users/username/voice.wav`

### **"Unsafe model format detected"**
Only SafeTensors models are allowed. This is a security feature working correctly.

---

## 📊 Performance

### **On M3 Ultra (Your Hardware):**

| Tool | Speed | Quality | Cost |
|------|-------|---------|------|
| Native TTS | Instant | Good | Free |
| MLX-Audio | 1-3s/sentence | Excellent | Free |
| Voice Clone | 3-5s/sentence | Excellent | Free |
| DALL-E (comparison) | 10-30s | Excellent | $0.04/image |

**TTS is faster than image generation!**

---

## 🎯 Quick Reference

### **Simple Speech:**
```
"Speak: [your text]"
```

### **High Quality:**
```
"Use MLX-Audio to speak: [your text]"
```

### **Voice Cloning:**
```
"Clone voice from ~/voice.wav and say: [your text]"
```

### **Specific Language:**
```
"Speak in Japanese: [your text]"
```

### **Save to File:**
```
"Generate speech and save to ~/audio.wav"
```

---

**Enjoy secure, high-quality text-to-speech in MLX Code!** 🎉
