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
      claude-desktop-with-fhs = pkgs.buildFHSEnv {
        name = "claude-desktop";
        targetPkgs = pkgs: with pkgs; [
          docker
          glibc
          openssl
          nodejs
          uv
        ];
        runScript = pkgs.writeScript "claude-desktop-wrapper" ''
          #!${pkgs.bash}/bin/bash

          # Create config directory if it doesn't exist
          mkdir -p $HOME/.config

          # Copy the config file if it exists and target doesn't exist or is different
          if [ -f ${builtins.toString ./config/claude_desktop_config.json} ]; then
          cp -f ${builtins.toString ./config/claude_desktop_config.json} $HOME/.config/
          elif [ -f $HOME/.config/claude_desktop_config.json ]; then
          # Use the existing file if we don't provide one in the flake
          echo "Using existing configuration file"
          else
          echo "Warning: No configuration file found"
          fi

          # Run the actual application
          exec ${self.packages.${system}.claude-desktop}/bin/claude-desktop "$@"
        ''; 
      };
      default = claude-desktop;
    };
  });
}
