# MLX Code — Installation & Setup Guide

Everything you need to go from zero to using MLX Code as a standalone app and as an Xcode extension.

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Install the App](#2-install-the-app)
3. [Download Your First Model](#3-download-your-first-model)
4. [Load a Model and Start Chatting](#4-load-a-model-and-start-chatting)
5. [Enable the Xcode Extension](#5-enable-the-xcode-extension)
6. [Using the Xcode Extension](#6-using-the-xcode-extension)
7. [Set a Project Directory](#7-set-a-project-directory)
8. [Build from Source](#8-build-from-source)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| macOS | 14.0 Sonoma | 15.0 Sequoia |
| Chip | Apple Silicon (M1) | M2 Pro / M3 / M4 |
| RAM | 8 GB | 16 GB |
| Storage | 5 GB free | 20 GB free (for models) |
| Xcode | Not required for chat | 15.0+ for Xcode Extension |
| Python | **Not required** | — |

No Python, no pip, no conda. MLX Code is fully self-contained.

---

## 2. Install the App

### Option A — DMG (Recommended)

1. Download `MLXCode-vX.Y.Z-buildN.dmg` from [Releases](https://github.com/kochj23/MLXCode/releases)
2. Double-click the DMG to mount it
3. Drag **MLX Code** to your **Applications** folder
4. Eject the DMG
5. Open **MLX Code** from Applications or Spotlight

> **First launch:** macOS may show a warning that the app is from an unidentified developer. Go to **System Settings → Privacy & Security**, scroll down to the security section, and click **Open Anyway**.

### Option B — Build from Source

See [Section 8 — Build from Source](#8-build-from-source).

---

## 3. Download Your First Model

MLX Code runs models locally on your Mac. You need to download at least one model before you can start chatting. Models are stored in `~/Documents/MLXCode/models` by default.

### Recommended Models

| Model | Size | RAM Needed | Best For |
|-------|------|-----------|----------|
| **Qwen 2.5 7B Instruct 4-bit** ⭐ | ~4 GB | 8 GB | Best overall — fast, good at coding and tool calling |
| Qwen 2.5 14B Instruct 4-bit | ~8 GB | 16 GB | Better quality, needs more RAM |
| Mistral 7B Instruct v0.3 4-bit | ~4 GB | 8 GB | Good general purpose |
| DeepSeek Coder 6.7B 4-bit | ~4 GB | 8 GB | Specialised for code |
| Phi-3.5 Mini 4-bit | ~2 GB | 8 GB | Fastest, lightest, weaker reasoning |

### How to Download

1. Open **MLX Code**
2. Click the **Settings** icon (gear) in the toolbar
3. Go to the **Models** tab
4. Find the model you want and click **Download**
5. Wait for the download to complete — progress is shown inline

Models are downloaded from [Hugging Face mlx-community](https://huggingface.co/mlx-community) using the native Hub API. No browser or terminal needed.

### Custom Models

To add any model from mlx-community:

1. Settings → Models → **Add Custom Model**
2. Enter the Hugging Face repo ID, e.g. `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit`
3. Click Download

### Change the Models Directory

By default models are saved to `~/Documents/MLXCode/models`. To use a different location:

1. Settings → **General**
2. Change **Models Path** to your preferred directory
3. Move any existing models to the new path

---

## 4. Load a Model and Start Chatting

1. Open **MLX Code**
2. In the sidebar or toolbar, open the **model picker**
3. Select the model you downloaded
4. Click **Load Model** — first load takes 10–30 seconds as weights are loaded into GPU memory
5. The status bar shows **Model loaded: [name]** when ready
6. Type a message and press **Return** or click Send

### Tips

- **First message is slow** — the model warms up on the first inference. Subsequent messages are faster.
- **Context window** — the model remembers everything in the current conversation up to its context limit (shown in the status bar). Start a new conversation with **Cmd+N** to clear context.
- **Stop generation** — press the Stop button in the toolbar to interrupt a response mid-stream.
- **Regenerate** — click the regenerate button on any assistant message to try again.

---

## 5. Enable the Xcode Extension

The Xcode Source Editor Extension lets you invoke MLX Code commands directly from the **Editor** menu inside Xcode without leaving your code.

### Step 1 — Open MLX Code at least once

The extension will not appear in System Settings until the parent app (MLX Code) has been launched at least once.

### Step 2 — Enable in System Settings

1. Open **System Settings**
2. Go to **Privacy & Security**
3. Scroll down and click **Extensions**
4. Click **Xcode Source Editor**
5. Check the box next to **MLX Code**

> If **MLX Code** does not appear in the list, make sure the app is in `/Applications` (not just your Downloads folder or Desktop) and has been launched at least once.

### Step 3 — Restart Xcode

Quit Xcode completely and reopen it. The extension loads at startup.

### Verify It's Working

Open any Swift file in Xcode. Click the **Editor** menu at the top of the screen. You should see a **MLX Code** submenu with 5 commands.

---

## 6. Using the Xcode Extension

### The 5 Commands

| Command | What it does |
|---------|-------------|
| **Explain Selection** | Explains what the selected code does in plain English |
| **Refactor Selection** | Rewrites the selected code for clarity and performance |
| **Generate Tests** | Writes XCTest unit tests for the selected code |
| **Fix Issues** | Finds and fixes bugs in the selected code |
| **Ask MLX Code** | Opens MLX Code with the selected code pre-loaded — you type the question |

### How to Use

1. Select code in Xcode (one line, a function, or an entire file)
2. Click **Editor** in the menu bar → **MLX Code** → choose a command
3. **MLX Code** opens (or comes to the foreground) with the code already loaded
4. The model processes the request — for "Ask MLX Code", type your question first

### What Gets Sent

- The **selected text** (or the full file if nothing is selected)
- The **file type** (Swift, Objective-C, Python, etc.) for syntax-aware responses
- Nothing is sent to any server — everything stays on your Mac

### Keyboard Shortcut (Optional)

You can assign a keyboard shortcut to any extension command in **System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts**.

---

## 7. Set a Project Directory

MLX Code works better when it knows where your project lives. With a project directory set, it can:
- Read files directly when you ask about them
- Run builds, tests, and git commands in the right context
- Include relevant file context automatically

### How to Set

1. Settings → **General**
2. Set **Working Directory** to your project folder (e.g. `/Users/you/Developer/MyApp`)
3. Optionally set **Xcode Project** to your `.xcodeproj` or `.xcworkspace` file

### Or, Tell the Chat

You can also just say: `"Set working directory to ~/Developer/MyApp"` and the assistant will configure it.

---

## 8. Build from Source

### Requirements

- Xcode 15.0 or later
- macOS 14.0 SDK

### Steps

```bash
# Clone the repo
git clone https://github.com/kochj23/MLXCode.git
cd MLXCode

# Open in Xcode
open "MLX Code.xcodeproj"
```

In Xcode:

1. Select the **MLX Code** scheme in the toolbar
2. Set destination to **My Mac**
3. Press **Cmd+R** to build and run

Swift Package Manager will automatically resolve and download:
- `mlx-swift` — Apple's MLX tensor library for Swift
- `mlx-swift-lm` — LLM loading and inference
- `swift-transformers` — tokenizer support
- `swift-collections` — collection utilities

> First build takes several minutes while Xcode compiles mlx-swift's Metal shaders.

### Building the Xcode Extension

The extension is a separate target. To build it:

1. Select the **MLX Code Extension** scheme
2. Press **Cmd+B**

To use it locally, build and run the main **MLX Code** target first (this installs both the app and embedded extension), then enable it in System Settings as described in [Section 5](#5-enable-the-xcode-extension).

---

## 9. Troubleshooting

### App won't open — "unidentified developer"

Go to **System Settings → Privacy & Security** → scroll to the blocked app → click **Open Anyway**.

### Model download fails

- Check you have enough free disk space (models are 2–8 GB each)
- Check your internet connection
- The models directory must be writable — go to Settings → General and verify the **Models Path** exists

### Model loads but responses are very slow

- Ensure you're on Apple Silicon (M1/M2/M3/M4), not Intel — MLX only accelerates on Apple Silicon
- Close other GPU-intensive apps (games, video editors)
- Try a smaller model (Phi-3.5 Mini at ~2 GB is the fastest option)

### Xcode extension not appearing in System Settings

1. Make sure MLX Code is in `/Applications` — not in Downloads or on the Desktop
2. Launch MLX Code at least once
3. Wait 30 seconds, then check System Settings again
4. If still missing: quit Xcode, open Terminal, run `pluginkit -e use -i com.local.mlxcode.xcodeeditor`, relaunch Xcode

### Xcode extension appears but commands do nothing

- Make sure a model is loaded in MLX Code before invoking an extension command
- Check that the App Group entitlement is granted — both the main app and extension must share `group.com.jkoch.mlxcode`

### Tool calls not executing

- Tool mode must be enabled (Settings → Tools → Enable Tools)
- Ensure a project directory is set — some tools (Xcode build, git) require it
- If a tool call keeps failing, the model may be producing malformed JSON — MLX Code will retry automatically up to 2 times, then report the error

### Conversations not saving

Check that `~/Library/Application Support/MLX Code/Conversations/` exists and is writable.

---

## Storage Locations

| Item | Location |
|------|----------|
| Models | `~/Documents/MLXCode/models/` (default, configurable) |
| Conversations | `~/Library/Application Support/MLX Code/Conversations/` |
| User memories | `~/.mlxcode/memories.json` |
| App Group container | `~/Library/Group Containers/group.com.jkoch.mlxcode/` |
| Logs | `~/Library/Logs/MLX Code/` |

---

*MLX Code — Copyright 2026 Jordan Koch. MIT License.*
