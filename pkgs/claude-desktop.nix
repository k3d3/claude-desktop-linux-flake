{
  lib,
  stdenvNoCC,
  fetchurl,
  electron,
  p7zip,
  libicns,
  nodePackages,
  imagemagick,
  makeDesktopItem,
  makeWrapper,
  glib-networking,
  writeText,
}:
let
  pname = "claude-desktop";
  version = "1.1.1200";
  srcDmg = fetchurl {
    url = "https://downloads.claude.ai/releases/darwin/universal/${version}/Claude-46e5339828adcd54a87842c010c8c0607f729b52.dmg";
    hash = "sha256-bFhonYSsghEMPaf3q6p2Wb/YyV/bqf0agveLA6N3pPQ=";
  };
  nativeStub = writeText "claude-native-stub.js" ''
    // Stub implementation of @ant/claude-native for Linux
    const KeyboardKey = {
      Backspace: 43, Tab: 280, Enter: 261, Shift: 272, Control: 61, Alt: 40,
      CapsLock: 56, Escape: 85, Space: 276, PageUp: 251, PageDown: 250,
      End: 83, Home: 154, LeftArrow: 175, UpArrow: 282, RightArrow: 262,
      DownArrow: 81, Delete: 79, Meta: 187
    };
    Object.freeze(KeyboardKey);

    class AuthRequest {
      static isAvailable() { return false; }
      async start(url, scheme, windowHandle) {
        throw new Error('AuthRequest not available on Linux');
      }
      cancel() {}
    }

    module.exports = {
      getWindowsVersion: () => "10.0.0",
      setWindowEffect: () => {},
      removeWindowEffect: () => {},
      getIsMaximized: () => false,
      flashFrame: () => {},
      clearFlashFrame: () => {},
      showNotification: () => {},
      setProgressBar: () => {},
      clearProgressBar: () => {},
      setOverlayIcon: () => {},
      clearOverlayIcon: () => {},
      KeyboardKey,
      AuthRequest,
      requestAccessibility: () => true,
      getWindowInfo: () => [],
      getActiveWindowHandle: () => 0,
      getMonitorInfo: () => ({
        x: 0, y: 0, width: 1920, height: 1080,
        monitorName: "DISPLAY1", isPrimary: true
      }),
      focusWindow: () => {},
      InputEmulator: class {
        copy() {}
        cut() {}
        paste() {}
        undo() {}
        selectAll() {}
        held() { return []; }
        pressChars(text) {}
        pressKey(key) {}
        pressThenReleaseKey(key) {}
        releaseChars(text) {}
        releaseKey(key) {}
        setButtonClick(button) {}
        setButtonToggle(button) {}
        getMousePosition() { return { x: 0, y: 0 }; }
        typeText(text) {}
        setMouseScroll(direction, amount) {}
      }
    };
  '';
in
stdenvNoCC.mkDerivation rec {
  inherit pname version;

  src = ./.;

  nativeBuildInputs = [
    p7zip
    nodePackages.asar
    makeWrapper
    imagemagick
    libicns
  ];

  desktopItem = makeDesktopItem {
    name = "Claude";
    exec = "claude-desktop %u";
    icon = "claude";
    type = "Application";
    terminal = false;
    desktopName = "Claude";
    genericName = "Claude Desktop";
    comment = "AI Assistant by Anthropic";
    startupWMClass = "Claude";
    startupNotify = true;
    categories = [
      "Office"
      "Utility"
      "Network"
      "Chat"
    ];
    mimeTypes = [ "x-scheme-handler/claude" ];
  };

  buildPhase = ''
    runHook preBuild

    mkdir -p $TMPDIR/build
    cd $TMPDIR/build

    # Extract Mac DMG
    echo "Extracting Mac DMG..."
    7z x -y ${srcDmg} || true

    if [ ! -d "Claude/Claude.app" ]; then
      echo "ERROR: Failed to extract Claude.app from DMG"
      ls -la
      exit 1
    fi

    APP_CONTENTS="$TMPDIR/build/Claude/Claude.app/Contents"
    RESOURCES="$APP_CONTENTS/Resources"

    # Extract icons
    echo "Extracting icons..."
    icns2png -x "$RESOURCES/electron.icns"
    for size in 16 32 48 128 256 512; do
      mkdir -p $TMPDIR/build/icons/hicolor/"$size"x"$size"/apps
      if [ -f "electron_"$size"x"$size"x32.png" ]; then
        install -Dm 644 "electron_"$size"x"$size"x32.png" \
          $TMPDIR/build/icons/hicolor/"$size"x"$size"/apps/claude.png
      elif [ -f "electron_"$size"x"$size".png" ]; then
        install -Dm 644 "electron_"$size"x"$size".png" \
          $TMPDIR/build/icons/hicolor/"$size"x"$size"/apps/claude.png
      fi
    done

    # Process app.asar
    mkdir -p electron-app
    cp "$RESOURCES/app.asar" electron-app/
    cp -r "$RESOURCES/app.asar.unpacked" electron-app/

    cd electron-app
    asar extract app.asar app.asar.contents

    INDEX_FILE="app.asar.contents/.vite/build/index.js"

    # ===========================================
    # PATCH 1: Title bar (enable on Linux)
    # ===========================================
    SEARCH_BASE="app.asar.contents/.vite/renderer/main_window/assets"
    TARGET_FILE=$(find "$SEARCH_BASE" -type f -name "MainWindowPage-*.js" 2>/dev/null | head -1)
    if [ -n "$TARGET_FILE" ]; then
      echo "Patching title bar in: $TARGET_FILE"
      sed -i -E 's/if\(!([a-zA-Z]+)[[:space:]]*&&[[:space:]]*([a-zA-Z]+)\)/if(\1 \&\& \2)/g' "$TARGET_FILE"
    fi

    # ===========================================
    # PATCH 2: Linux platform support for Claude Code
    # ===========================================
    if [ -f "$INDEX_FILE" ]; then
      echo "Patching platform detection..."
      sed -i 's/if(process.platform==="win32")return"win32-x64";throw/if(process.platform==="win32")return"win32-x64";if(process.platform==="linux")return process.arch==="arm64"?"linux-arm64":"linux-x64";throw/g' "$INDEX_FILE"

      # ===========================================
      # PATCH 3: Origin validation for file:// protocol
      # ===========================================
      echo "Patching origin validation..."
      sed -i -E 's/e\.protocol==="file:"\&\&[a-zA-Z]+\.app\.isPackaged===!0/e.protocol==="file:"/g' "$INDEX_FILE"

      # ===========================================
      # PATCH 4: Tray icon theme detection
      # ===========================================
      echo "Patching tray icon theme..."
      sed -i -E 's/:([a-zA-Z])="TrayIconTemplate\.png"/:\1=require("electron").nativeTheme.shouldUseDarkColors?"TrayIconTemplate-Dark.png":"TrayIconTemplate.png"/g' "$INDEX_FILE"

      # ===========================================
      # PATCH 5: Window blur before hide (fixes quick submit)
      # ===========================================
      echo "Patching window blur..."
      sed -i 's/e\.hide()/e.blur(),e.hide()/g' "$INDEX_FILE"
    fi

    # ===========================================
    # Install native stub (JavaScript, not Rust)
    # ===========================================
    echo "Installing native stub..."
    mkdir -p app.asar.contents/node_modules/@ant/claude-native
    mkdir -p app.asar.unpacked/node_modules/@ant/claude-native
    cp ${nativeStub} app.asar.contents/node_modules/@ant/claude-native/index.js
    cp ${nativeStub} app.asar.unpacked/node_modules/@ant/claude-native/index.js

    # Swift addon stub (reuse the same stub)
    mkdir -p app.asar.contents/node_modules/@ant/claude-swift
    mkdir -p app.asar.unpacked/node_modules/@ant/claude-swift
    echo "module.exports = {};" > app.asar.contents/node_modules/@ant/claude-swift/index.js
    echo "module.exports = {};" > app.asar.unpacked/node_modules/@ant/claude-swift/index.js

    # Copy tray icons
    mkdir -p app.asar.contents/resources
    cp "$RESOURCES"/TrayIconTemplate*.png app.asar.contents/resources/ 2>/dev/null || true
    cp "$RESOURCES"/Tray*.ico app.asar.contents/resources/ 2>/dev/null || true

    # Fix icon opacity for Linux
    echo "Fixing tray icon opacity..."
    for icon in app.asar.contents/resources/TrayIconTemplate*.png; do
      if [ -f "$icon" ]; then
        convert "$icon" -channel A -fx "a>0?1:0" "$icon" 2>/dev/null || true
      fi
    done

    # Copy i18n
    mkdir -p app.asar.contents/resources/i18n
    cp "$RESOURCES"/*.json app.asar.contents/resources/i18n/ 2>/dev/null || true

    # Repack
    asar pack app.asar.contents app.asar

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/$pname
    cp -r $TMPDIR/build/electron-app/app.asar $out/lib/$pname/
    cp -r $TMPDIR/build/electron-app/app.asar.unpacked $out/lib/$pname/

    mkdir -p $out/share/icons
    cp -r $TMPDIR/build/icons/* $out/share/icons

    mkdir -p $out/share/applications
    install -Dm0644 {${desktopItem},$out}/share/applications/Claude.desktop

    mkdir -p $out/bin
    makeWrapper ${electron}/bin/electron $out/bin/$pname \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ glib-networking ]}" \
      --add-flags "$out/lib/$pname/app.asar" \
      --add-flags "\''${CLAUDE_USE_WAYLAND:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,UseOzonePlatform --gtk-version=4}" \
      --set GIO_EXTRA_MODULES "${glib-networking}/lib/gio/modules" \
      --set-default GDK_BACKEND "x11" \
      --set CHROME_DESKTOP "Claude.desktop" \
      --set-default GTK_THEME "\''${GTK_THEME:-Adwaita:dark}" \
      --set-default COLOR_SCHEME_PREFERENCE "\''${COLOR_SCHEME_PREFERENCE:-dark}" \
      --prefix XDG_DATA_DIRS : "$out/share"

    runHook postInstall
  '';

  dontUnpack = true;
  dontConfigure = true;

  meta = with lib; {
    description = "Claude Desktop for Linux";
    license = licenses.unfree;
    platforms = platforms.unix;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = pname;
  };
}
