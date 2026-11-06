#!/bin/bash
#
# Setup script for MLX Code Python dependencies
# Installs all required packages for MLX inference and RAG system
#

set -e

echo "🚀 MLX Code Python Setup"
echo "========================"
echo ""

# Check Python version
echo "📋 Checking Python version..."
PYTHON_VERSION=$(/usr/bin/python3 --version 2>&1 | awk '{print $2}')
echo "   Found: Python $PYTHON_VERSION"

# Check if pip is available
if ! /usr/bin/python3 -m pip --version &> /dev/null; then
    echo "❌ pip is not available. Please install pip first."
    exit 1
fi

echo "   pip is available ✓"
echo ""

# Install dependencies
# NOTE: version specifiers MUST be quoted. Unquoted `pkg>=1.0` is parsed by the shell
# as `pkg` plus an output redirect into a file named `=1.0` (which is how the stray
# Python/=0.0.10 etc. files were created).
echo "📦 Installing Python dependencies..."
echo "   This may take a few minutes..."
echo ""

/usr/bin/python3 -m pip install --user --upgrade pip

echo "   Installing MLX framework..."
/usr/bin/python3 -m pip install --user "mlx>=0.0.10" "mlx-lm>=0.0.10"

echo "   Installing HuggingFace tools..."
/usr/bin/python3 -m pip install --user "huggingface-hub>=0.19.0" "transformers>=4.35.0"

echo "   Installing RAG dependencies..."
/usr/bin/python3 -m pip install --user "sentence-transformers>=2.2.0" "chromadb>=0.4.0"

echo "   Installing utilities..."
/usr/bin/python3 -m pip install --user "numpy>=1.24.0" "tqdm>=4.65.0"

echo ""
echo "✅ Installation complete!"
echo ""

# Verify installations
echo "🔍 Verifying installations..."

ERRORS=0

if /usr/bin/python3 -c "import mlx.core" 2>/dev/null; then
    echo "   ✓ MLX installed"
else
    echo "   ✗ MLX not found"
    ERRORS=$((ERRORS + 1))
fi

if /usr/bin/python3 -c "import mlx_lm" 2>/dev/null; then
    echo "   ✓ mlx-lm installed"
else
    echo "   ✗ mlx-lm not found"
    ERRORS=$((ERRORS + 1))
fi

if /usr/bin/python3 -c "import huggingface_hub" 2>/dev/null; then
    echo "   ✓ huggingface-hub installed"
else
    echo "   ✗ huggingface-hub not found"
    ERRORS=$((ERRORS + 1))
fi

if /usr/bin/python3 -c "import sentence_transformers" 2>/dev/null; then
    echo "   ✓ sentence-transformers installed"
else
    echo "   ✗ sentence-transformers not found"
    ERRORS=$((ERRORS + 1))
fi

if /usr/bin/python3 -c "import chromadb" 2>/dev/null; then
    echo "   ✓ chromadb installed"
else
    echo "   ✗ chromadb not found"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ All dependencies verified successfully!"
    echo ""
    echo "🎉 MLX Code is ready to use!"
    echo ""
    echo "Next steps:"
    echo "  1. Launch MLX Code app"
    echo "  2. Go to Settings → Models"
    echo "  3. Download a model (e.g., Llama 3.2 3B)"
    echo "  4. Start chatting!"
    echo ""
else
    echo "⚠️  Some dependencies failed to install ($ERRORS errors)"
    echo ""
    echo "Try running this command manually:"
    echo "  /usr/bin/python3 -m pip install --user -r requirements.txt"
    echo ""
    exit 1
fi
