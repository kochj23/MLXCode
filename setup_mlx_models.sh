#!/bin/bash
#
# MLX Code Model Setup Script
# Downloads and sets up models for MLX Code
#

set -e

echo "=================================================="
echo "MLX Code - Model Setup Script"
echo "=================================================="
echo ""

# Use direct Python (not xcode-select shim)
PYTHON="/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9"

# Verify Python exists
if [ ! -f "$PYTHON" ]; then
    echo "❌ Python 3.9 not found at: $PYTHON"
    echo "Please install Xcode and Command Line Tools"
    exit 1
fi

echo "✅ Python found: $PYTHON"

# Set PYTHONPATH for user packages
export PYTHONPATH="$HOME/Library/Python/3.9/lib/python/site-packages"

# Verify required packages
echo ""
echo "Checking Python packages..."
$PYTHON -c "import mlx.core; print('✅ mlx installed')" || {
    echo "❌ MLX not installed. Install with:"
    echo "   pip3 install mlx mlx-lm"
    exit 1
}

$PYTHON -c "import huggingface_hub; print('✅ huggingface_hub installed')" || {
    echo "❌ huggingface_hub not installed. Install with:"
    echo "   pip3 install huggingface-hub"
    exit 1
}

echo ""
echo "=================================================="
echo "All prerequisites met! Starting downloads..."
echo "=================================================="
echo ""

# Models directory
MODELS_DIR="$HOME/.mlx/models"
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

echo "📁 Models will be saved to: $MODELS_DIR"
echo ""

# Model selection
echo "Available models:"
echo "  1. Phi-3.5 Mini (4GB) - Fast, good for coding"
echo "  2. Llama 3.2 3B (7GB) - Better quality"
echo "  3. Qwen 2.5 7B (14GB) - Best coding model"
echo "  4. Mistral 7B (14GB) - Best general purpose"
echo "  5. All models"
echo ""
read -p "Select models to download (1-5): " choice

download_phi() {
    echo ""
    echo "📥 Downloading Phi-3.5 Mini (4GB)..."
    huggingface-cli download mlx-community/Phi-3.5-mini-instruct-4bit --local-dir phi-3.5-mini
    echo "✅ Phi-3.5 Mini downloaded"
}

download_llama() {
    echo ""
    echo "📥 Downloading Llama 3.2 3B (7GB)..."
    huggingface-cli download mlx-community/Llama-3.2-3B-Instruct-4bit --local-dir llama-3.2-3b
    echo "✅ Llama 3.2 3B downloaded"
}

download_qwen() {
    echo ""
    echo "📥 Downloading Qwen 2.5 7B (14GB)..."
    huggingface-cli download mlx-community/Qwen2.5-7B-Instruct-4bit --local-dir qwen-2.5-7b
    echo "✅ Qwen 2.5 7B downloaded"
}

download_mistral() {
    echo ""
    echo "📥 Downloading Mistral 7B (14GB)..."
    huggingface-cli download mlx-community/Mistral-7B-Instruct-v0.3-4bit --local-dir mistral-7b
    echo "✅ Mistral 7B downloaded"
}

case $choice in
    1)
        download_phi
        ;;
    2)
        download_llama
        ;;
    3)
        download_qwen
        ;;
    4)
        download_mistral
        ;;
    5)
        download_phi
        download_llama
        download_qwen
        download_mistral
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=================================================="
echo "✅ SETUP COMPLETE!"
echo "=================================================="
echo ""
echo "Models saved to: $MODELS_DIR"
echo ""
echo "Downloaded models:"
ls -d "$MODELS_DIR"/*/ 2>/dev/null | while read dir; do
    model_name=$(basename "$dir")
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    echo "  • $model_name ($size)"
done
echo ""
echo "Next steps:"
echo "  1. Launch MLX Code"
echo "  2. Models will auto-discover on startup"
echo "  3. Select a model from the dropdown"
echo "  4. Click 'Load' and start chatting!"
echo ""
