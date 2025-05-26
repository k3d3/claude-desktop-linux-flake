#!/bin/bash
set -e

# Main script to build an AppImage for Claude Desktop on Linux
# Supports multiple distributions: Fedora, Ubuntu/Debian, Arch Linux

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"
source "$SCRIPT_DIR/scripts/distro-detect.sh"

echo "Building Claude Desktop AppImage..."

# Detect distribution and source appropriate package manager script
detect_distro
case "$DISTRO_FAMILY" in
    "fedora")
        source "$SCRIPT_DIR/scripts/deps-fedora.sh"
        ;;
    "debian")
        source "$SCRIPT_DIR/scripts/deps-debian.sh"
        ;;
    "arch")
        source "$SCRIPT_DIR/scripts/deps-arch.sh"
        ;;
    *)
        echo "Error: Unsupported distribution family: $DISTRO_FAMILY"
        echo "Supported distributions: Fedora, CentOS, RHEL, Ubuntu, Debian, Arch Linux, Manjaro"
        exit 1
        ;;
esac

echo "Detected distribution: $DISTRO_NAME ($DISTRO_FAMILY)"

# Create temporary build directory
PROJECT_DIR="$(pwd)"
BUILD_DIR="$(mktemp -d)"
OUTPUT_DIR="$(pwd)/appimage-output"
mkdir -p "$OUTPUT_DIR"

# Cleanup function to run on exit
cleanup() {
    echo "Cleaning up..."
    rm -rf "$BUILD_DIR"
}
#trap cleanup EXIT

# Install dependencies
echo "Installing dependencies..."
install_dependencies

# Source the build functions
source "$SCRIPT_DIR/scripts/build-functions.sh"

# Download Claude Desktop
download_claude_desktop "$BUILD_DIR"

# Extract installer
extract_installer "$BUILD_DIR"

# Build patchy-cnb
build_patchy_cnb "$PROJECT_DIR"

# Process app.asar files
process_app_asar "$BUILD_DIR" "$PATCHY_CNB_PATH"

# Create AppImage
create_appimage "$BUILD_DIR" "$OUTPUT_DIR"

# Get the actual AppImage name that was created
APPIMAGE_NAME=$(ls "$OUTPUT_DIR"/Claude-$CLAUDE_VERSION-*.AppImage 2>/dev/null | head -n 1)
if [ -n "$APPIMAGE_NAME" ]; then
    echo "AppImage created at $APPIMAGE_NAME"
    echo "You can now run it with: $APPIMAGE_NAME"
else
    echo "AppImage creation may have failed. Check the output directory: $OUTPUT_DIR"
fi