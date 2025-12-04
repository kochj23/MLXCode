#!/bin/bash

echo "======================================"
echo "MLX Code - Live Console Output Monitor"
echo "======================================"
echo ""
echo "Watching for print() statements from MLX Code app..."
echo "These will appear in real-time as you interact with the app."
echo ""
echo "Press Ctrl+C to stop"
echo ""
echo "======================================"
echo ""

# Get the PID of the running MLX Code app
PID=$(ps aux | grep "MLX Code.app/Contents/MacOS/MLX Code" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$PID" ]; then
    echo "❌ MLX Code app is not running!"
    echo "Please launch the app first."
    exit 1
fi

echo "✅ Found MLX Code running with PID: $PID"
echo ""
echo "======================================"
echo "LIVE OUTPUT (print statements will appear below):"
echo "======================================"
echo ""

# Stream the console output for this process
log stream --process $PID --level debug --style compact 2>&1
