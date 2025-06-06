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
        claude-desktop = pkgs.callPackage ./pkgs/claude-desktop.nix {
          inherit patchy-cnb;
        };
        claude-desktop-with-fhs = pkgs.symlinkJoin {
          name = "claude-desktop-with-fhs";
          paths = [
            claude-desktop
            (pkgs.buildFHSEnv {
              name = "claude-desktop-bwrap";
              targetPkgs = pkgs: with pkgs; [
                docker
                glibc
                openssl
                nodejs
                uv
                glib
                gvfs
                xdg-utils
              ];
              runScript = "${claude-desktop}/bin/claude-desktop";
            })
          ];
          postBuild = ''
            # Replace the regular binary with the FHS wrapped one
            rm -f $out/bin/claude-desktop
            ln -sf $out/bin/claude-desktop-bwrap $out/bin/claude-desktop
          '';
        };
        default = claude-desktop;
      };
    });
}
