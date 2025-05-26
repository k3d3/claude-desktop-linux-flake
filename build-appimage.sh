#!/bin/bash
set -e

# Script to build an AppImage for Claude Desktop on Fedora Linux
# This script automates the process of creating an AppImage for Claude Desktop

echo "Building Claude Desktop AppImage..."

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

# Install required dependencies if not already installed
echo "Checking and installing dependencies..."
if ! command -v curl &> /dev/null; then
    sudo dnf install -y curl
fi

if ! command -v 7z &> /dev/null; then
    sudo dnf install -y p7zip p7zip-plugins
fi

if ! command -v npm &> /dev/null; then
    sudo dnf install -y nodejs npm
fi

if ! command -v asar &> /dev/null; then
    sudo npm install -g asar
fi

if ! command -v rustc &> /dev/null; then
    sudo dnf install -y rust cargo
fi

# Install tools for icon extraction
if ! command -v wrestool &> /dev/null || ! command -v icotool &> /dev/null; then
    sudo dnf install -y icoutils
fi

# Install ImageMagick for icon creation if needed
if ! command -v convert &> /dev/null; then
    sudo dnf install -y ImageMagick
fi

if ! command -v appimagetool &> /dev/null; then
    echo "Installing appimagetool..."
    curl -L -o "$BUILD_DIR/appimagetool" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$BUILD_DIR/appimagetool"
    sudo mv "$BUILD_DIR/appimagetool" /usr/local/bin/
fi

# Download electron if not already installed
if ! command -v electron &> /dev/null; then
    echo "Installing electron..."
    sudo npm install -g electron
fi

# Download the Claude Desktop Windows installer
CLAUDE_VERSION="0.9.3"
CLAUDE_INSTALLER="$BUILD_DIR/Claude-Setup-x64.exe"
echo "Downloading Claude Desktop Windows installer..."
curl -L -o "$CLAUDE_INSTALLER" "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe?v=$CLAUDE_VERSION"

# Extract the installer
echo "Extracting installer..."
cd "$BUILD_DIR"
7z x -y "$CLAUDE_INSTALLER"
7z x -y "AnthropicClaude-$CLAUDE_VERSION-full.nupkg"

# Build patchy-cnb
echo "Building patchy-cnb..."
cd "$PROJECT_DIR/patchy-cnb"
npm install
npm run build

# Find the correct path to the built module
# The build output should be in the current directory after npm run build
PATCHY_CNB_PATH=""
if [ -f "patchy-cnb.linux-x64-gnu.node" ]; then
    PATCHY_CNB_PATH="$PROJECT_DIR/patchy-cnb/patchy-cnb.linux-x64-gnu.node"
elif [ -f "index.node" ]; then
    PATCHY_CNB_PATH="$PROJECT_DIR/patchy-cnb/index.node"
else
    # Look for any .node file in the current directory
    NODE_FILE=$(find . -name "*.node" -type f | head -n 1)
    if [ -n "$NODE_FILE" ]; then
        PATCHY_CNB_PATH="$PROJECT_DIR/patchy-cnb/$NODE_FILE"
    else
        echo "Error: Could not find compiled patchy-cnb module"
        echo "Contents of patchy-cnb directory:"
        ls -la "$PROJECT_DIR/patchy-cnb/"
        exit 1
    fi
fi

echo "Using patchy-cnb module at: $PATCHY_CNB_PATH"

# Verify the file exists
if [ ! -f "$PATCHY_CNB_PATH" ]; then
    echo "Error: patchy-cnb module not found at $PATCHY_CNB_PATH"
    echo "Contents of patchy-cnb directory:"
    ls -la "$PROJECT_DIR/patchy-cnb/"
    exit 1
fi

# Process app.asar files
echo "Processing app.asar files..."
cd "$BUILD_DIR"
mkdir -p electron-app
cp "lib/net45/resources/app.asar" electron-app/
cp -r "lib/net45/resources/app.asar.unpacked" electron-app/

cd electron-app
asar extract app.asar app.asar.contents

# Replace native bindings
echo "Replacing native bindings..."
# Create directories if they don't exist
mkdir -p app.asar.contents/node_modules/claude-native/
mkdir -p app.asar.unpacked/node_modules/claude-native/

cp "$PATCHY_CNB_PATH" app.asar.contents/node_modules/claude-native/claude-native-binding.node
cp "$PATCHY_CNB_PATH" app.asar.unpacked/node_modules/claude-native/claude-native-binding.node

# Copy Tray icons
mkdir -p app.asar.contents/resources
cp "$BUILD_DIR/lib/net45/resources/Tray"* app.asar.contents/resources/ 2>/dev/null || echo "Warning: No Tray icons found"

# Copy i18n json files
mkdir -p app.asar.contents/resources/i18n
cp "$BUILD_DIR/lib/net45/resources/"*.json app.asar.contents/resources/i18n/ 2>/dev/null || echo "Warning: No i18n files found"

# Repackage app.asar
asar pack app.asar.contents app.asar

# Create AppDir structure
echo "Creating AppDir structure..."
APPDIR="$BUILD_DIR/Claude.AppDir"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib/claude-desktop"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Extract icons from claude.exe
cd "$BUILD_DIR"
if command -v wrestool &> /dev/null && command -v icotool &> /dev/null; then
    echo "Extracting icons from claude.exe..."
    if [ -f "lib/net45/claude.exe" ]; then
        wrestool -x -t 14 lib/net45/claude.exe -o claude.ico 2>/dev/null || echo "Warning: Could not extract icons from claude.exe"

        if [ -f "claude.ico" ]; then
            icotool -x claude.ico 2>/dev/null || echo "Warning: Could not convert ico file"

            for size in 16 24 32 48 64 256; do
                mkdir -p "$APPDIR/usr/share/icons/hicolor/${size}x${size}/apps"
                icon_file=$(find . -name "*${size}x${size}x32.png" 2>/dev/null | head -n 1)
                if [ -n "$icon_file" ]; then
                    cp "$icon_file" "$APPDIR/usr/share/icons/hicolor/${size}x${size}/apps/claude-desktop.png"
                fi
            done

            # Use the largest icon for the AppImage
            largest_icon=$(find . -name "*256x256x32.png" 2>/dev/null | head -n 1)
            if [ -n "$largest_icon" ]; then
                cp "$largest_icon" "$APPDIR/claude-desktop.png"
            else
                # Try other sizes
                for size in 128 64 48 32; do
                    icon_file=$(find . -name "*${size}x${size}x32.png" 2>/dev/null | head -n 1)
                    if [ -n "$icon_file" ]; then
                        cp "$icon_file" "$APPDIR/claude-desktop.png"
                        break
                    fi
                done
            fi
        fi
    fi
fi

# If no icon was extracted, create a simple one
if [ ! -f "$APPDIR/claude-desktop.png" ]; then
    echo "Creating placeholder icon..."
    if command -v convert &> /dev/null; then
        convert -size 256x256 xc:white -fill black -gravity center -pointsize 40 -annotate 0 "Claude" "$APPDIR/claude-desktop.png"
    else
        # Create a very basic SVG and convert it
        cat > "$BUILD_DIR/claude-icon.svg" << 'EOF'
<svg width="256" height="256" xmlns="http://www.w3.org/2000/svg">
  <rect width="256" height="256" fill="white"/>
  <text x="128" y="128" font-family="Arial" font-size="40" text-anchor="middle" dy=".3em">Claude</text>
</svg>
EOF
        cp "$BUILD_DIR/claude-icon.svg" "$APPDIR/claude-desktop.png"
    fi
    cp "$APPDIR/claude-desktop.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/claude-desktop.png"
fi

# Copy app.asar and app.asar.unpacked to AppDir
cp -r "$BUILD_DIR/electron-app/app.asar" "$APPDIR/usr/lib/claude-desktop/"
cp -r "$BUILD_DIR/electron-app/app.asar.unpacked" "$APPDIR/usr/lib/claude-desktop/"

# Create desktop entry
cat > "$APPDIR/usr/share/applications/claude-desktop.desktop" << EOF
[Desktop Entry]
Name=Claude
Comment=Claude Desktop
Exec=claude-desktop
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;Utility;
MimeType=x-scheme-handler/claude;
EOF

# Create AppRun script
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec electron "${HERE}/usr/lib/claude-desktop/app.asar" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Create launcher script
cat > "$APPDIR/usr/bin/claude-desktop" << 'EOF'
#!/bin/bash
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
exec electron "${SCRIPT_DIR}/../lib/claude-desktop/app.asar" "$@"
EOF
chmod +x "$APPDIR/usr/bin/claude-desktop"

# Create symlink for desktop file
ln -sf usr/share/applications/claude-desktop.desktop "$APPDIR/claude-desktop.desktop"

# Build AppImage
echo "Building AppImage..."
cd "$BUILD_DIR"
appimagetool "$APPDIR" "$OUTPUT_DIR/Claude-$CLAUDE_VERSION-x86_64.AppImage"

echo "AppImage created at $OUTPUT_DIR/Claude-$CLAUDE_VERSION-x86_64.AppImage"
echo "You can now run it with: $OUTPUT_DIR/Claude-$CLAUDE_VERSION-x86_64.AppImage"