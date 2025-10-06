{
  description = "Claude Desktop for Linux";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = lib.genAttrs systems;
      pkgsFor = lib.genAttrs systems (
        system:
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (lib.getName pkg) [
              "claude-desktop"
            ];
        }
      );
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        rec {
          patchy-cnb = pkgs.callPackage ./pkgs/patchy-cnb.nix { };
          claude-desktop = pkgs.callPackage ./pkgs/claude-desktop.nix {
            inherit patchy-cnb;
          };
          claude-desktop-with-fhs = pkgs.buildFHSEnv {
            name = "claude-desktop";
            targetPkgs =
              pkgs: with pkgs; [
                docker
                glibc
                openssl
                nodejs
                uv
              ];
            runScript = "${claude-desktop}/bin/claude-desktop";
            extraInstallCommands = ''
              # Copy desktop file from the claude-desktop package
              mkdir -p $out/share/applications
              cp ${claude-desktop}/share/applications/claude.desktop $out/share/applications/

              # Copy icons
              mkdir -p $out/share/icons
              cp -r ${claude-desktop}/share/icons/* $out/share/icons/
            '';
          };
          default = claude-desktop;
        }
      );
    };
}
