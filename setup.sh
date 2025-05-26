#!/bin/bash

# Setup script for Claude Desktop AppImage builder
# This script creates the necessary directory structure and sets permissions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Claude Desktop AppImage builder..."

# Create scripts directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/scripts"

# Make all scripts executable
find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \;

# Check if we're in the correct directory (should have flake.nix and patchy-cnb)
if [ ! -f "$SCRIPT_DIR/flake.nix" ]; then
    echo "Warning: flake.nix not found. Make sure you're in the claude-desktop-linux-flake directory."
fi

if [ ! -d "$SCRIPT_DIR/patchy-cnb" ]; then
    echo "Warning: patchy-cnb directory not found. Make sure you have the complete repository."
fi

# Create output directory
mkdir -p "$SCRIPT_DIR/appimage-output"

echo "Setup completed successfully!"
echo ""
echo "To build Claude Desktop AppImage, run:"
echo "  ./build-appimage.sh"
echo ""
echo "The AppImage will be created in the 'appimage-output' directory."