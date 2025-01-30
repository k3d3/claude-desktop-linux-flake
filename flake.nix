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
        default = claude-desktop;
      };
    });
}
