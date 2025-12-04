# Troubleshooting Guide

Having issues with MLX Code? This guide will help you solve common problems quickly.

---

## 🚫 Common Issues & Solutions

### Issue: "No model is loaded" Error

**Symptoms:**
- Click Send but nothing happens
- Status bar shows "No model loaded"
- Error message appears

**Solutions:**
1. **Check Model Status**
   - Click Settings (gear icon)
   - Go to "Models" tab
   - Look for green checkmark next to a model

2. **Download a Model**
   - If no models shown as downloaded:
   - Select a model (recommend: Phi-3.5 Mini)
   - Click "Download" button
   - Wait for download to complete (shows progress)

3. **Load the Model**
   - After download, click "Load" button
   - Wait 3-5 seconds
   - Status bar should show "Model loaded: [name]"

4. **Verify Model Files**
   - Open Terminal
   - Run: `ls -la ~/.mlx/models/`
   - Should see model folders with files

---

### Issue: "MLX not installed" or Import Error

**Symptoms:**
- App shows "Python bridge failed to start"
- Error mentions "mlx" module not found
- Can't load any models

**Solutions:**
1. **Install MLX** (Most Common Fix)
   ```bash
   pip3 install mlx mlx-lm
   ```

2. **Check Python Version**
   ```bash
   python3 --version
   ```
   - Need Python 3.9 or later
   - If older, update Python from python.org

3. **Verify Installation**
   ```bash
   python3 -c "import mlx.core; print('Success!')"
   ```
   - Should print "Success!"
   - If error, reinstall MLX

4. **Check Python Path**
   - Settings → Paths tab
   - Verify Python path: `/usr/bin/python3`
   - Try: `/usr/local/bin/python3` if default doesn't work

---

### Issue: Model Download Fails

**Symptoms:**
- Download stops partway
- Shows error message
- Progress stuck at 0%

**Solutions:**
1. **Check Internet**
   - Open a web browser
   - Visit any website
   - If no internet, fix connection first

2. **Check Disk Space**
   - Need 10GB+ free space
   - Apple menu → About This Mac → Storage
   - Free up space if needed

3. **Try Again**
   - Click Download button again
   - Downloads can resume from where they stopped

4. **Try Smaller Model**
   - If large model fails, try Phi-3.5 Mini (2GB)
   - Smaller = faster, more reliable download

5. **Manual Download** (Advanced)
   ```bash
   cd ~/.mlx/models
   git clone https://huggingface.co/mlx-community/phi-3.5-mini
   ```

---

### Issue: Slow Generation Speed

**Symptoms:**
- Responses take forever
- Tokens/second very low (< 10 t/s)
- Mac feels sluggish

**Solutions:**
1. **Check Mac Model**
   - MLX requires Apple Silicon (M1/M2/M3/M4)
   - Intel Macs not supported
   - Check: Apple menu → About This Mac

2. **Free Up Memory**
   - Close other apps
   - Need 4-8GB RAM available
   - Activity Monitor → Memory tab

3. **Use Smaller Model**
   - Phi-3.5 Mini (2GB) is fastest
   - Larger models = slower but better quality

4. **Plug In Your Mac**
   - Battery mode = slower performance
   - Plug in for full speed

5. **Close Background Apps**
   - Quit unused applications
   - Check Activity Monitor for CPU hogs

6. **Restart Mac**
   - Sometimes helps clear memory
   - Fresh start often faster

---

### Issue: Chat Not Responding

**Symptoms:**
- Type message, press Enter, nothing happens
- No error shown
- App seems frozen

**Solutions:**
1. **Check Status Bar**
   - Look at bottom of window
   - If shows "Generating...", AI is working

2. **Wait Longer**
   - First response can take 30+ seconds
   - Watch for spinning progress indicator

3. **Check Model Loaded**
   - See "No model loaded" section above

4. **Restart App**
   - Quit: `⌘Q`
   - Relaunch MLX Code
   - Load model again

5. **Check Logs**
   - Press `⌘⇧L` to open log viewer
   - Look for error messages

---

### Issue: Gibberish or Poor Quality Responses

**Symptoms:**
- AI generates nonsense
- Repeated words
- Incomplete sentences

**Solutions:**
1. **Try Different Model**
   - Some models better for certain tasks
   - Larger models usually better quality

2. **Clear Conversation**
   - Press `⌘K` to clear
   - Start fresh conversation

3. **Reload Model**
   - Settings → Models
   - Click "Unload" then "Load"

4. **Check Model Download**
   - Model files might be corrupted
   - Try downloading again

5. **Adjust Settings** (Advanced)
   - Settings → Models → Parameters
   - Try different temperature (0.7 is good default)

---

### Issue: App Crashes or Freezes

**Symptoms:**
- App stops responding
- Force quit needed
- Crashes on launch

**Solutions:**
1. **Check macOS Version**
   - Need macOS 14.0 (Sonoma) or later
   - Apple menu → Software Update

2. **Free Up Resources**
   - Close other apps
   - Restart Mac
   - Try again

3. **Reset Settings**
   - Quit app
   - Delete: `~/Library/Application Support/MLX Code/settings.json`
   - Relaunch app

4. **Reinstall MLX**
   ```bash
   pip3 uninstall mlx mlx-lm
   pip3 install mlx mlx-lm
   ```

5. **Check Logs**
   - Look in Console app (macOS utility)
   - Search for "MLX Code"
   - Note any error messages

---

### Issue: Model Files Missing or Corrupted

**Symptoms:**
- "Model not found" error
- Model shows as downloaded but won't load
- Config.json missing

**Solutions:**
1. **Check Model Directory**
   ```bash
   ls -la ~/.mlx/models/phi-3.5-mini/
   ```
   - Should see: config.json, model.safetensors, etc.

2. **Redownload Model**
   - Settings → Models
   - Find the model
   - Click "Download" again
   - Overwrites corrupted files

3. **Verify Path**
   - Settings → Paths
   - Models Path should be: `~/.mlx/models`
   - Can change if needed

4. **Manual Check**
   ```bash
   cd ~/.mlx/models
   find . -name "config.json"
   ```
   - Each model folder should have config.json

---

## 🔧 Advanced Troubleshooting

### Enable Debug Logging

1. Hold `Option (⌥)` key while launching app
2. Enables verbose logging
3. Check logs: `⌘⇧L`

### Check Python Environment

```bash
# Verify Python
which python3
python3 --version

# Check MLX installation
pip3 list | grep mlx

# Test MLX import
python3 -c "import mlx.core as mx; print(mx.__version__)"
```

### Reset Everything

If all else fails:

```bash
# Backup conversations first!
cp -r ~/Library/Application\ Support/MLX\ Code/ ~/Desktop/MLX_Code_Backup/

# Remove settings
rm -rf ~/Library/Application\ Support/MLX\ Code/

# Remove models (optional - will need to redownload)
rm -rf ~/.mlx/models/

# Reinstall MLX
pip3 uninstall -y mlx mlx-lm
pip3 install mlx mlx-lm

# Relaunch app
```

---

## 📊 Performance Optimization

### Get Best Speed

1. **Use Apple Silicon Mac** (M1/M2/M3/M4)
2. **Plug in to power**
3. **Close other apps**
4. **Use smaller models**
5. **Ensure 16GB+ RAM**

### Expected Performance

| Model | Speed | Memory |
|-------|-------|--------|
| Phi-3.5 Mini | 150-200 t/s | 2-3 GB |
| Mistral 7B | 80-120 t/s | 4-5 GB |
| Llama 3 8B | 60-100 t/s | 5-6 GB |

*On M1 Pro/Max with 16GB RAM

---

## 🆘 Still Need Help?

### Collect Information

Before asking for help, gather:
1. macOS version
2. Mac model (M1/M2/M3/M4)
3. MLX Code version
4. Error messages
5. Steps to reproduce issue

### Get Support

1. **Check Documentation**
   - Help → Getting Started
   - Help → Features Guide

2. **View Logs**
   - `⌘⇧L` in app
   - Look for errors

3. **Report Issue**
   - GitHub: [link to issues page]
   - Include info from above

4. **Community**
   - MLX Discord server
   - Reddit: r/mlx

---

## ✅ Quick Fixes Checklist

Before deep troubleshooting, try these:

- [ ] Restart MLX Code app
- [ ] Check model is loaded (Settings → Models)
- [ ] Verify internet connection (for downloads)
- [ ] Check disk space (need 10GB+)
- [ ] Confirm MLX installed: `pip3 list | grep mlx`
- [ ] Try different model
- [ ] Clear conversation: `⌘K`
- [ ] Restart Mac
- [ ] Update macOS to latest version

---

**Most issues can be solved with:** Reinstall MLX, Reload model, or Restart app!
