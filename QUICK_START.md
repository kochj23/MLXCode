# MLX Code - Quick Start Guide

Get up and running with MLX Code in 5 minutes!

---

## Prerequisites

- ✅ macOS 14.0+ (Sonoma or later)
- ✅ Apple Silicon Mac (M1/M2/M3/M4)
- ✅ Xcode 15.0+ installed
- ✅ Command Line Tools installed

---

## Step 1: Install Python Dependencies (2 minutes)

```bash
# Create virtual environment
python3 -m venv ~/mlx-env

# Activate it
source ~/mlx-env/bin/activate

# Install MLX packages
pip install mlx mlx-lm numpy transformers

# Verify installation
python -c "import mlx.core as mx; print(f'MLX version: {mx.__version__}')"
```

**Expected output:** `MLX version: 0.x.x`

---

## Step 2: Launch MLX Code (30 seconds)

```bash
# Navigate to project
cd "/Volumes/Data/xcode/MLX Code"

# Open in Xcode
open "MLX Code.xcodeproj"

# Build and run (⌘R)
```

Or build from command line:
```bash
xcodebuild -project "MLX Code.xcodeproj" \
  -scheme "MLX Code" \
  -configuration Debug \
  build
```

---

## Step 3: Configure Settings (1 minute)

1. **Launch the app**
2. **Open Settings** (⌘,)
3. **Go to Advanced tab**
4. **Set Python path:** `~/mlx-env/bin/python`
5. **Click "Validate"** - should show ✅ green checkmark
6. **Close Settings**

---

## Step 4: Load a Model (2 minutes)

### Option A: Use Built-in Model (Recommended)

1. Click **Model Selector** in toolbar
2. Choose **Deepseek Coder 6.7B** (recommended for beginners)
3. Model will download automatically (if download feature enabled)
4. Wait for "Model loaded" status

### Option B: Use Custom Model

1. Download an MLX model manually:
   ```bash
   # Example: Download from HuggingFace
   huggingface-cli download mlx-community/deepseek-coder-6.7b-instruct-4bit
   ```

2. In MLX Code:
   - Settings → Model → Add Custom Model
   - Set path to downloaded model
   - Click "Load Model"

---

## Step 5: Start Chatting! (30 seconds)

1. **Type a message** in the input box at the bottom
2. Try: `"Explain what a view model is in SwiftUI"`
3. **Press ⌘Return** or click Send button
4. **Watch the magic happen!** 🎉

---

## Essential Keyboard Shortcuts

Learn these first:

| Shortcut | Action |
|----------|--------|
| **⌘Return** | Send message |
| **⌘N** | New conversation |
| **⌘K** | Clear conversation |
| **⌘⇧T** | Open template library |
| **⌘/** | Command palette |
| **⌘,** | Settings |

---

## Quick Tips

### Using Templates

1. Press **⌘⇧T** to open template library
2. Browse 20+ built-in templates
3. Try "SwiftUI View" template:
   - Fill in name: "ProfileView"
   - Fill in requirements: "Display user name and avatar"
   - Click "Use Template"
   - Magic! ✨

### Git Integration

1. Press **⌘⇧G** to open Git helper
2. See your modified files
3. Click "Generate Commit Message"
4. AI writes a perfect commit message!
5. Click "Commit" to save

### Build Error Help

1. Press **⌘⇧B** to build current project
2. If errors occur, they appear in a panel
3. Click any error to see AI suggestion
4. Click "Apply Fix" to fix automatically

### Markdown Support

All messages support full markdown:

```
# Heading
**bold** and *italic*
`inline code`
- Lists work too!
```

Code blocks with syntax highlighting:
````
```swift
func hello() {
    print("Hello, MLX Code!")
}
```
````

---

## Example Use Cases

### 1. Generate a View Model

**You:** "Create a view model for managing user authentication"

**MLX Code will:**
- Generate ObservableObject class
- Add @Published properties
- Include async login/logout methods
- Add error handling
- Include [weak self] for memory safety

### 2. Refactor Code

**You:** "Convert this completion handler to async/await: [paste code]"

**MLX Code will:**
- Analyze the code
- Convert to async throws
- Update function signatures
- Maintain behavior
- Explain changes

### 3. Debug Errors

**You:** "Build the project and fix any errors"

**MLX Code will:**
- Run xcodebuild
- Parse errors
- Suggest fixes for each
- Apply fixes with your approval
- Re-run build to verify

### 4. Write Tests

**You:** Use template "Unit Tests"
- Class name: "ChatViewModel"
- Scenarios: "message sending, error handling"

**MLX Code will:**
- Generate XCTest class
- Create test methods
- Add setup/teardown
- Include async tests
- Add assertions

---

## Troubleshooting

### "Model won't load"

**Check:**
1. Is Python path correct? (Settings → Advanced)
2. Is MLX installed? Run: `pip list | grep mlx`
3. Is model path valid? Check the path exists
4. Enough RAM? (7B model needs ~8GB)

**Fix:** Restart app, try smaller model, check logs

### "Commands aren't working"

**Check:**
1. Is xcodebuild available? Run: `xcodebuild -version`
2. Is git available? Run: `git --version`
3. File permissions granted?

**Fix:** Install Command Line Tools: `xcode-select --install`

### "Build errors not parsing"

**Check:**
1. Is project a valid Xcode project?
2. Is project path accessible?
3. Check console logs for errors

**Fix:** Open project in Xcode first, then try again

### "Slow performance"

**Optimize:**
1. Use quantized models (4-bit or 8-bit)
2. Close unused apps to free RAM
3. Pre-load model at startup
4. Reduce max tokens in settings

---

## Advanced Features

### Create Custom Templates

1. Open template library (⌘⇧T)
2. Click **+ New Template**
3. Fill in:
   - Name: "My Custom Template"
   - Category: Custom
   - Template text with `{{variables}}`
4. Save and use!

### Command Palette Power

Press **⌘/** to access all features instantly:
- Type to search
- Hit Return to execute
- No mouse needed!

### Batch Operations

Use templates for batch work:
- "Add unit tests for: [list of classes]"
- "Document all methods in: [file names]"
- "Refactor all these files: [paste list]"

---

## Pro Tips

1. **Learn keyboard shortcuts** - 10x faster workflow
2. **Create your own templates** - Reuse common prompts
3. **Use markdown** - Better formatting in messages
4. **Git integration** - Never write commit messages again
5. **Build integration** - Fix errors automatically
6. **Conversation export** - Save important chats
7. **Model selection** - Different models for different tasks

---

## Getting Help

### Resources

- **README.md** - Full user guide
- **SECURITY.md** - Security documentation
- **PROJECT_SUMMARY.md** - Technical details

### Console Logs

If something isn't working:
1. Open Console.app
2. Filter by "MLX Code"
3. Check for error messages
4. Look at SecureLogger output

### Common Issues

**"No model loaded"**
→ Load a model first (Model Selector)

**"Python not found"**
→ Set Python path in Settings

**"Permission denied"**
→ Grant file access when prompted

**"Build failed"**
→ Check xcodebuild is installed

---

## Next Steps

Now that you're up and running:

1. ✅ **Explore templates** - Check out all 20 built-in templates
2. ✅ **Try different models** - Experiment with CodeLlama, Qwen
3. ✅ **Create custom templates** - Build your own library
4. ✅ **Integrate with your workflow** - Use it daily!
5. ✅ **Read advanced docs** - Check README for deep dives

---

## Success Checklist

Before you start using MLX Code daily, verify:

- [ ] Python environment set up and validated
- [ ] At least one model loaded successfully
- [ ] Created a test conversation
- [ ] Sent a test message and received response
- [ ] Tried a template from the library
- [ ] Tested Git helper on a repo
- [ ] Ran a build and saw results
- [ ] Learned essential keyboard shortcuts
- [ ] Read README.md for full features

---

## Welcome to MLX Code! 🚀

You're now ready to experience local AI-powered coding assistance. No cloud, no tracking, complete privacy.

**Happy coding!**

---

**Need help?** Check the docs or console logs
**Found a bug?** Check build logs and console output
**Have feedback?** Document your experience!

---

**Version:** 1.0.0
**Last Updated:** November 18, 2025
**Status:** ✅ Ready to use!
