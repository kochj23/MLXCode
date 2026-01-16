#!/bin/bash
#
# resign_and_install.sh - Re-sign and install MLX Code
#
# This script automatically re-signs the latest MLX Code build,
# installs it to ~/Applications/, and verifies the signature.
#
# Usage: ./resign_and_install.sh [build-path]
#
# If no build path is provided, uses the latest build in Binaries/

set -e  # Exit on error

echo "🔧 MLX Code Re-sign and Install Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
BINARIES_DIR="/Volumes/Data/xcode/Binaries"
INSTALL_DIR="/Users/kochj/Applications"
APP_NAME="MLX Code.app"

# Find build path
if [ -n "$1" ]; then
    BUILD_PATH="$1"
    echo "📦 Using provided build: $BUILD_PATH"
else
    # Find latest build
    LATEST_BUILD=$(ls -t "$BINARIES_DIR" | grep "MLXCode-v" | head -1)
    if [ -z "$LATEST_BUILD" ]; then
        echo -e "${RED}❌ No builds found in $BINARIES_DIR${NC}"
        exit 1
    fi
    BUILD_PATH="$BINARIES_DIR/$LATEST_BUILD/Export/$APP_NAME"
    echo "📦 Found latest build: $LATEST_BUILD"
fi

# Verify build exists
if [ ! -d "$BUILD_PATH" ]; then
    echo -e "${RED}❌ Build not found: $BUILD_PATH${NC}"
    exit 1
fi

echo ""
echo "Step 1: Re-signing exported app..."
codesign --force --deep --sign - "$BUILD_PATH"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Exported app re-signed${NC}"
else
    echo -e "${RED}❌ Failed to re-sign exported app${NC}"
    exit 1
fi

echo ""
echo "Step 2: Killing old instances..."
killall "$APP_NAME" 2>/dev/null || true
sleep 1
echo -e "${GREEN}✅ Old instances killed${NC}"

echo ""
echo "Step 3: Removing old installation..."
if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME"
    echo -e "${GREEN}✅ Old installation removed${NC}"
else
    echo -e "${YELLOW}⚠️  No previous installation found${NC}"
fi

echo ""
echo "Step 4: Copying to Applications..."
cp -R "$BUILD_PATH" "$INSTALL_DIR/"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Copied to $INSTALL_DIR${NC}"
else
    echo -e "${RED}❌ Failed to copy app${NC}"
    exit 1
fi

echo ""
echo "Step 5: Re-signing installed app..."
codesign --force --deep --sign - "$INSTALL_DIR/$APP_NAME"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Installed app re-signed${NC}"
else
    echo -e "${RED}❌ Failed to re-sign installed app${NC}"
    exit 1
fi

echo ""
echo "Step 6: Verifying signature..."
VERIFY_OUTPUT=$(codesign --verify --verbose "$INSTALL_DIR/$APP_NAME" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Signature verified:${NC}"
    echo "$VERIFY_OUTPUT"
else
    echo -e "${RED}❌ Signature verification failed:${NC}"
    echo "$VERIFY_OUTPUT"
    exit 1
fi

echo ""
echo "Step 7: Launching MLX Code..."
open "$INSTALL_DIR/$APP_NAME"
sleep 2

# Check if app is running
if pgrep -x "MLX Code" > /dev/null; then
    echo -e "${GREEN}✅ MLX Code launched successfully${NC}"
else
    echo -e "${YELLOW}⚠️  MLX Code may not have launched${NC}"
fi

echo ""
echo "========================================"
echo -e "${GREEN}🎉 MLX Code installed and running!${NC}"
echo ""
echo "Location: $INSTALL_DIR/$APP_NAME"
echo "Build: $(basename "$(dirname "$(dirname "$BUILD_PATH")")")"
echo ""
