# Getting Started with MLX Code

Welcome to MLX Code! This guide will help you set up everything you need to start chatting with local AI language models.

## What is MLX Code?

MLX Code is a macOS application that lets you chat with AI language models running **locally on your Mac**. This means:
- ✅ Your conversations stay private on your computer
- ✅ No internet required after setup
- ✅ Fast responses using Apple Silicon
- ✅ Free to use with no API costs

## System Requirements

Before you begin, make sure you have:
- **macOS 14.0 (Sonoma) or later**
- **Apple Silicon Mac** (M1, M2, M3, or M4)
- **At least 8GB RAM** (16GB recommended)
- **10GB+ free disk space** (for models)
- **Internet connection** (for initial setup only)

---

## Step-by-Step Setup Guide

### Step 1: Install Python and MLX (One-Time Setup)

MLX Code uses Python with the MLX library to run AI models. Don't worry if you're not familiar with Python - just follow these exact steps:

#### 1.1 Open Terminal

1. Click the **Spotlight search** icon (magnifying glass) in the top-right corner of your screen
2. Type: `Terminal`
3. Press **Enter** (or click the Terminal app)

A window with black or white background will open. This is the Terminal.

#### 1.2 Check if Python is Installed

In the Terminal window, type this command and press **Enter**:

```bash
python3 --version
```

You should see something like: `Python 3.9.6` or similar.

- ✅ If you see a version number, Python is installed - continue to Step 1.3
- ❌ If you see "command not found", you need to install Python first:
  1. Visit https://www.python.org/downloads/
  2. Click "Download Python"
  3. Open the downloaded file and follow the installer
  4. After installation, close and reopen Terminal, then try again

#### 1.3 Install MLX Toolkit

Now we'll install the MLX toolkit. Copy and paste this command into Terminal and press **Enter**:

```bash
pip3 install mlx mlx-lm
```

**What you'll see:**
- The Terminal will show downloading progress
- Lots of text will scroll by (this is normal!)
- It may take 2-5 minutes depending on your internet speed
- When it's done, you'll see your command prompt again

**Note:** If you see "permission denied", try this command instead:

```bash
pip3 install --user mlx mlx-lm
```

#### 1.4 Verify Installation

Let's make sure everything installed correctly. Type this and press **Enter**:

```bash
python3 -c "import mlx.core; print('MLX installed successfully!')"
```

✅ If you see "MLX installed successfully!" - Perfect! You're done with setup.

❌ If you see an error, try running the install command from Step 1.3 again.

---

### Step 2: Download Your First AI Model

Now that MLX is installed, you need to download an AI model to chat with.

#### 2.1 Launch MLX Code

1. Open the **MLX Code** app (double-click the app icon)
2. The main chat window will appear

#### 2.2 Open Settings

1. Click the **Settings** button (gear icon) in the top-right corner
2. The Settings panel will open on the right side

#### 2.3 Go to Models Tab

1. In the Settings panel, click the **"Models"** tab
2. You'll see a list of available models

#### 2.4 Choose a Model

**For beginners, we recommend:**

**Phi-3.5 Mini** (Best for first-time users)
- Size: 2GB download
- Speed: Very fast
- Quality: Good for most tasks
- Best for: General chat, coding help, questions

**How to select it:**
1. Look for "Phi-3.5 Mini" in the models list
2. Click the dropdown next to it

#### 2.5 Download the Model

1. Click the **"Download"** button next to your chosen model
2. **Be patient!** This will download 2GB of data
   - Progress will show in the status area
   - On fast internet: 5-10 minutes
   - On slow internet: 20-30 minutes
3. ✅ When complete, the button will change to **"Load"**

**Important:** Keep your Mac awake during download!
- Don't close the laptop lid
- Don't let it go to sleep
- You can minimize the app and do other things

#### 2.6 Load the Model

1. After download completes, click the **"Load"** button
2. Wait 3-5 seconds while the model loads into memory
3. ✅ The status bar will show "Model loaded: Phi-3.5 Mini"

**Congratulations!** You're ready to chat! 🎉

---

### Step 3: Start Chatting

#### 3.1 Type Your First Message

1. Click in the **text box** at the bottom of the chat window
2. Type a question, like: `Hello! Can you help me learn Python?`
3. Press **Enter** (or click the Send button)

#### 3.2 Watch the Magic Happen

- You'll see the AI's response appear **in real-time**, word by word
- The status bar shows:
  - Token count (number of words generated)
  - Speed (tokens per second)
- Responses typically take 5-30 seconds depending on length

#### 3.3 Continue the Conversation

- Just keep typing and pressing Enter!
- The AI remembers your conversation history
- You can ask follow-up questions
- Each conversation is saved automatically

---

## Quick Reference

### Common Tasks

**Start a New Conversation:**
- Press `⌘N` (Command + N)
- Or click the "New" button in the sidebar

**Clear Current Conversation:**
- Press `⌘K` (Command + K)
- Or click the trash icon

**Open Settings:**
- Press `⌘,` (Command + Comma)
- Or click the gear icon

**See All Keyboard Shortcuts:**
- Go to Help menu → Keyboard Shortcuts

---

## Troubleshooting

### "No model is loaded" Error

**Problem:** You click Send but nothing happens.

**Solution:**
1. Open Settings (gear icon)
2. Go to Models tab
3. Select a model from the dropdown
4. Click "Download" (if not downloaded)
5. Click "Load" after download completes

### Model Download Fails

**Problem:** Download stops or shows error.

**Solutions:**
- Check your internet connection
- Try downloading again (click Download button)
- Try a smaller model (Phi-3.5 Mini is recommended)
- Make sure you have 10GB+ free disk space

### Slow Response Speed

**Problem:** The AI is very slow.

**Solutions:**
- Close other apps to free up memory
- Try a smaller model (Phi-3.5 Mini is fastest)
- Check if your Mac is running on battery (plug in for best performance)
- Make sure you have an Apple Silicon Mac (M1/M2/M3/M4)

### "MLX not installed" Error

**Problem:** App says MLX toolkit not found.

**Solution:**
1. Open Terminal (Spotlight → search "Terminal")
2. Run: `pip3 install mlx mlx-lm`
3. Wait for installation to complete
4. Restart MLX Code app

---

## Next Steps

Now that you're set up, explore these features:

1. **Try Different Models** - Each has different strengths
2. **Use Prompt Templates** - Press `⌘⇧T` for quick prompts
3. **Save Conversations** - All chats are automatically saved
4. **Customize Settings** - Adjust font size, theme, and more

---

## Need More Help?

- **Features Guide**: Help menu → Features & Capabilities
- **Keyboard Shortcuts**: Help menu → Keyboard Shortcuts
- **Troubleshooting**: Help menu → Troubleshooting Guide
- **Advanced Topics**: Help menu → Advanced Usage

---

**Welcome to MLX Code! Happy chatting! 🚀**
