{
  lib,
  stdenvNoCC,
  fetchurl,
  electron,
  p7zip,
  icoutils,
  nodePackages,
  imagemagick,
  makeDesktopItem,
  makeWrapper,
  patchy-cnb,
  perl,
  glib-networking
}: let
  pname = "claude-desktop";
  version = "0.9.4";
  srcExe = fetchurl {
    # NOTE: Removing version parameter to avoid potential hash mismatches in CI/CD environments
    url = "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe";
    hash = "sha256-OofXsRNVBueiewCCfYOwGqlsZECYtWWRTg4Wu+hGAnE=";
  };
in
  stdenvNoCC.mkDerivation rec {
    inherit pname version;

    src = ./.;

    nativeBuildInputs = [
      p7zip
      nodePackages.asar
      makeWrapper
      imagemagick
      icoutils
      perl
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
      categories = [
        "Office"
        "Utility"
        "Network"
        "Chat"
      ];
      mimeTypes = ["x-scheme-handler/claude"];
    };

    buildPhase = ''
      runHook preBuild

      # Create temp working directory
      mkdir -p $TMPDIR/build
      cd $TMPDIR/build

      # Extract installer exe, and nupkg within it
      7z x -y ${srcExe}
      7z x -y "AnthropicClaude-${version}-full.nupkg"

      # Package the icons from claude.exe
      wrestool -x -t 14 lib/net45/claude.exe -o claude.ico
      icotool -x claude.ico

      for size in 16 24 32 48 64 256; do
        mkdir -p $TMPDIR/build/icons/hicolor/"$size"x"$size"/apps
        install -Dm 644 claude_*"$size"x"$size"x32.png \
          $TMPDIR/build/icons/hicolor/"$size"x"$size"/apps/claude.png
      done

      rm claude.ico

      # Process app.asar files
      # We need to replace claude-native-bindings.node in both the
      # app.asar package and .unpacked directory
      mkdir -p electron-app
      cp "lib/net45/resources/app.asar" electron-app/
      cp -r "lib/net45/resources/app.asar.unpacked" electron-app/

      cd electron-app
      asar extract app.asar app.asar.contents

      echo "Using search pattern: '$TARGET_PATTERN' within search base: '$SEARCH_BASE'"
      SEARCH_BASE="app.asar.contents/.vite/renderer/main_window/assets"
      TARGET_PATTERN="MainWindowPage-*.js"

      echo "Searching for '$TARGET_PATTERN' within '$SEARCH_BASE'..."
      # Find the target file recursively (ensure only one matches)
      TARGET_FILES=$(find "$SEARCH_BASE" -type f -name "$TARGET_PATTERN")
      # Count non-empty lines to get the number of files found
      NUM_FILES=$(echo "$TARGET_FILES" | grep -c .)
      echo "Found $NUM_FILES matching files"
      echo "Target files: $TARGET_FILES"

      echo "##############################################################"
      echo "Removing "'!'" from 'if ("'!'"isWindows && isMainWindow) return null;'"
      echo "detection flag to to enable title bar"

      echo "Current working directory: '$PWD'"

      echo "Searching for '$TARGET_PATTERN' within '$SEARCH_BASE'..."
      # Find the target file recursively (ensure only one matches)
      if [ "$NUM_FILES" -eq 0 ]; then
        echo "Error: No file matching '$TARGET_PATTERN' found within '$SEARCH_BASE'." >&2
        exit 1
      elif [ "$NUM_FILES" -gt 1 ]; then
        echo "Error: Expected exactly one file matching '$TARGET_PATTERN' within '$SEARCH_BASE', but found $NUM_FILES." >&2
        echo "Found files:" >&2
        echo "$TARGET_FILES" >&2
        exit 1
      else
        # Exactly one file found
        TARGET_FILE="$TARGET_FILES" # Assign the found file path
        echo "Found target file: $TARGET_FILE"

        echo "Attempting to replace patterns like 'if(!VAR1 && VAR2)' with 'if(VAR1 && VAR2)' in $TARGET_FILE..."
        perl -i -pe \
          's{if\(!(\w+)\s*&&\s*(\w+)\)}{if($1 && $2)}g' \
          "$TARGET_FILE"

        # Verification: Check if the original pattern structure still exists
        if ! grep -q -E '!\w+&&\w+' "$TARGET_FILE"; then
          echo "Successfully replaced patterns like '!VAR1&&VAR2' with 'VAR1&&VAR2' in $TARGET_FILE"
        else
          echo "Warning: Some instances of '!VAR1&&VAR2' might still exist in $TARGET_FILE." >&2
        fi        # Verification: Check if the original pattern structure still exists
      fi
      echo "##############################################################"
      # exit 1

      # Replace native bindings
      cp ${patchy-cnb}/lib/patchy-cnb.*.node app.asar.contents/node_modules/claude-native/claude-native-binding.node
      cp ${patchy-cnb}/lib/patchy-cnb.*.node app.asar.unpacked/node_modules/claude-native/claude-native-binding.node

      # .vite/build/index.js in the app.asar expects the Tray icons to be
      # placed inside the app.asar.
      mkdir -p app.asar.contents/resources
      ls ../lib/net45/resources/
      cp ../lib/net45/resources/Tray* app.asar.contents/resources/

      # Copy i18n json files
      mkdir -p app.asar.contents/resources/i18n
      cp ../lib/net45/resources/*.json app.asar.contents/resources/i18n/

      # Repackage app.asar
      asar pack app.asar.contents app.asar

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # Electron directory structure
      mkdir -p $out/lib/$pname
      cp -r $TMPDIR/build/electron-app/app.asar $out/lib/$pname/
      cp -r $TMPDIR/build/electron-app/app.asar.unpacked $out/lib/$pname/

      # Install icons
      mkdir -p $out/share/icons
      cp -r $TMPDIR/build/icons/* $out/share/icons

      # Install .desktop file
      mkdir -p $out/share/applications
      install -Dm0644 ${desktopItem}/share/applications/Claude.desktop $out/share/applications/Claude.desktop
      # Also install with original name for compatibility
      ln -s Claude.desktop $out/share/applications/claude-desktop.desktop

      # Create wrapper
      mkdir -p $out/bin
      makeWrapper ${electron}/bin/electron $out/bin/$pname \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [glib-networking]}" \
        --add-flags "$out/lib/$pname/app.asar" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,UseOzonePlatform --gtk-version=4}}" \
        --set-default NIXOS_OZONE_WL "\''${WAYLAND_DISPLAY:+1}" \
        --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
        --set GIO_EXTRA_MODULES "${glib-networking}/lib/gio/modules" \
        --set GDK_BACKEND "wayland,x11" \
        --set CHROME_DESKTOP "Claude.desktop" \
        --prefix XDG_DATA_DIRS : "$out/share"

      runHook postInstall
    '';

    dontUnpack = true;
    dontConfigure = true;

    meta = with lib; {
      description = "Claude Desktop for Linux";
      license = licenses.unfree;
      platforms = platforms.unix;
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      mainProgram = pname;
    };
  }
