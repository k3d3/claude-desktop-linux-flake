{
  description = "Claude Desktop for Linux";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        packages = rec {
          patchy-cnb = pkgs.callPackage ./pkgs/patchy-cnb.nix { };
          claude-desktop = pkgs.callPackage ./pkgs/claude-desktop.nix { inherit patchy-cnb; };
          claude-desktop-with-fhs =
            let
              basePackage = self.packages.${system}.claude-desktop;
              fhsEnv = pkgs.buildFHSEnv {
                name = "claude-desktop";
                targetPkgs = pkgs: [
                  basePackage
                  pkgs.docker
                  pkgs.glibc
                  pkgs.openssl
                  pkgs.nodejs
                  pkgs.uv
                  (pkgs.python3.withPackages (
                    ps: with ps; [
                      pip
                      httpx
                      mcp
                    ]
                  ))
                  pkgs.git
                ];

                profile = ''
                                  # UV Configuration for NixOS - prevent Python downloads
                                  export UV_PYTHON_PREFERENCE="system"
                                  export UV_PYTHON_DOWNLOADS="never"
                                  export UV_LINK_MODE="copy"

                                  # Ensure UV configuration directory exists
                                  mkdir -p "$HOME/.config/uv"

                                  # Create UV config file if it doesn't exist
                                  if [[ ! -f "$HOME/.config/uv/uv.toml" ]]; then
                                    cat > "$HOME/.config/uv/uv.toml" << 'EOF'
                  # Use system Python instead of downloading
                  python-preference = "system"
                  python-downloads = "never"
                  link-mode = "copy"
                  cache-dir = "~/.cache/uv"
                  EOF
                                  fi

                                  # Ensure Claude and MCP directories exist
                                  mkdir -p "$HOME/.config/Claude"
                                  mkdir -p "$HOME/.local/lib/python3.11/site-packages"

                                  # SSL certificates for package downloads
                                  export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                                  export CURL_CA_BUNDLE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                                  export GIT_SSL_CAINFO="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                '';

                runScript = "${basePackage}/bin/claude-desktop";
              };
            in
            pkgs.stdenv.mkDerivation {
              pname = "claude-desktop";
              version = basePackage.version;

              dontUnpack = true;
              dontBuild = true;

              installPhase = ''
                runHook preInstall

                # Create directory structure
                mkdir -p $out/{bin,share/{applications,icons}}

                # Copy icons from the original package to maintain icon theme integration
                cp -r ${basePackage}/share/icons/* $out/share/icons/

                # Copy and modify desktop file from base package
                cp ${basePackage}/share/applications/claude-desktop.desktop $out/share/applications/claude-desktop.desktop
                # Update the Exec path to point to our FHS wrapper
                sed -i 's|Exec=claude-desktop|Exec=${placeholder "out"}/bin/claude-desktop|g' $out/share/applications/claude-desktop.desktop

                # Create wrapper script that preserves all arguments and environment
                cat > $out/bin/claude-desktop << 'EOF'
                #!/usr/bin/env bash
                # FHS wrapper for Claude Desktop with MCP support
                exec ${fhsEnv}/bin/claude-desktop "$@"
                EOF
                chmod +x $out/bin/claude-desktop

                runHook postInstall
              '';

              passthru = {
                inherit fhsEnv;
                originalPackage = basePackage;
              };

              meta = basePackage.meta;
            };
          default = claude-desktop;
        };
      }
    );
}
