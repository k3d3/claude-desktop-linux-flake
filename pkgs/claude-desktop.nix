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
  version ? "0.7.8", # Can use "latest" if you're using `--impure`
}: let
  bucketName = "osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97";
  objectName = "nest-win-x64%2fClaude-Setup-x64.exe";

  versions = {
    latest = builtins.fromJSON (builtins.readFile (builtins.fetchurl {
      url = "https://storage.googleapis.com/storage/v1/b/${bucketName}/o/${objectName}";
      name = "info.json";
    }));
    "0.7.8" = {
      generation = "1736347746447694";
      md5Hash = "0hi+BaQq0gkG99Te8IRMdw==";
    };
    "0.7.7" = {
      generation = "1734634165702331";
      md5Hash = "w/gyP91dwnH9+eTL1OtBAg==";
    };
  };

  generation = versions.${version}.generation;
  md5Hash = versions.${version}.md5Hash;

  pname = "claude-desktop";
  srcExeGz = fetchurl {
    name = "${pname}-${version}.exe.gz";
    url = "https://storage.googleapis.com/download/storage/v1/b/${bucketName}/o/${objectName}?generation=${generation}&alt=media";
    hash = "md5-${md5Hash}";
    curlOptsList = ["-H" "Accept-Encoding: gzip"]; # To prevent gunzipper transformer and match md5hash from the info
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
    ];

    desktopItem = makeDesktopItem {
      name = "claude-desktop";
      exec = "claude-desktop %u";
      icon = "claude-desktop";
      type = "Application";
      terminal = false;
      desktopName = "Claude";
      genericName = "Claude Desktop interface";
      categories = [
        "Office"
        "Utility"
      ];
      mimeTypes = ["x-scheme-handler/claude"];
    };

    buildPhase = ''
      runHook preBuild

      # Create temp working directory
      mkdir -p $TMPDIR/build
      cd $TMPDIR/build

      # Extract gzip, installer exe, and nupkg within it
      gunzip --stdout ${srcExeGz} > ${pname}-${version}.exe
      7z x -y ${pname}-${version}.exe
      7z x -y "AnthropicClaude-*-full.nupkg"

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

      # Replace native bindings
      cp ${patchy-cnb}/lib/patchy-cnb.*.node app.asar.contents/node_modules/claude-native/claude-native-binding.node
      cp ${patchy-cnb}/lib/patchy-cnb.*.node app.asar.unpacked/node_modules/claude-native/claude-native-binding.node

      # .vite/build/index.js in the app.asar expects the Tray icons to be
      # placed inside the app.asar.
      mkdir -p app.asar.contents/resources
      ls ../lib/net45/resources/
      cp ../lib/net45/resources/Tray* app.asar.contents/resources/

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
      install -Dm0644 {${desktopItem},$out}/share/applications/$pname.desktop

      # Create wrapper
      mkdir -p $out/bin
      makeWrapper ${electron}/bin/electron $out/bin/$pname \
        --add-flags "$out/lib/$pname/app.asar" \
        --add-flags "--openDevTools" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

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
