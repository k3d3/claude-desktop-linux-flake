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
        claude-desktop-with-fhs = let
          fhsEnv = pkgs.buildFHSEnv {
            name = "claude-desktop";
            targetPkgs = pkgs: [
              self.packages.${system}.claude-desktop
              pkgs.docker
              pkgs.glibc
              pkgs.openssl
              pkgs.nodejs
              pkgs.uv
            ];
            runScript = "${claude-desktop}/bin/claude-desktop";
          };
        in pkgs.makeDesktopItem {
          name = "claude-desktop-fhs";
          desktopName = "Claude (FHS)";
          genericName = "Claude Desktop";
          exec = "${fhsEnv}/bin/claude-desktop";
          icon = "${self.packages.${system}.claude-desktop}/share/icons/hicolor/scalable/apps/claude.svg";
          categories = [ "Office" "Utility" ];
        };
        default = claude-desktop;
      };
    });
}
