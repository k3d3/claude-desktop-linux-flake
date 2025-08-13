{
  description = "Claude Desktop for Linux";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      packages = rec {
        patchy-cnb = pkgs.callPackage ./pkgs/patchy-cnb.nix {};
        claude-desktop-base = pkgs.callPackage ./pkgs/claude-desktop.nix {
          inherit patchy-cnb;
        };
        claude-desktop = let
          basePackage = self.packages.${system}.claude-desktop-base;
          fhsEnv = pkgs.buildFHSEnv {
            name = "claude-desktop";
            targetPkgs = pkgs: [
              basePackage
              pkgs.docker
              pkgs.glibc
              pkgs.openssl
              pkgs.nodejs
              pkgs.uv
              pkgs.python3
              pkgs.git
            ];
            runScript = "${basePackage}/bin/claude-desktop";
          };
        in pkgs.stdenv.mkDerivation {
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
            
            # Create wrapper script that preserves all arguments and environment
            cat > $out/bin/claude-desktop << 'EOF'
            #!/usr/bin/env bash
            # FHS wrapper for Claude Desktop with MCP support
            exec ${fhsEnv}/bin/claude-desktop "$@"
            EOF
            chmod +x $out/bin/claude-desktop
            
            # Create desktop file
            cat > $out/share/applications/claude-desktop.desktop << 'EOF'
            [Desktop Entry]
            Name=Claude
            GenericName=Claude Desktop with MCP Support
            Comment=AI assistant with Model Context Protocol support
            Exec=${placeholder "out"}/bin/claude-desktop %u
            Icon=claude
            Type=Application
            Terminal=false
            Categories=Office;Utility;Development;
            MimeType=x-scheme-handler/claude;
            StartupWMClass=Claude
            Keywords=AI;Assistant;Chat;Claude;MCP;
            EOF
            
            runHook postInstall
          '';
          
          passthru = {
            inherit fhsEnv;
            originalPackage = basePackage;
          };
          
          meta = basePackage.meta // {
            description = "Claude Desktop for Linux with FHS environment for MCP server support";
            longDescription = ''
              Claude Desktop wrapped in an FHS environment to provide compatibility
              with Model Context Protocol (MCP) servers that require standard filesystem
              hierarchy and common development tools.
            '';
            mainProgram = "claude-desktop";
          };
        };
        default = claude-desktop;
      };
    });
}
