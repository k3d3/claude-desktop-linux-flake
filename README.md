***THIS IS AN UNOFFICIAL BUILD SCRIPT!***

If you run into an issue with this build script, make an issue here. Don't bug Anthropic about it - they already have enough on their plates.

# Claude Desktop for Linux (Nix)

This is a Nix flake for running Claude Desktop on Linux with proper desktop integration.

## Features

- MCP server support
- Ctrl+Alt+Space popup
- System tray integration
- GNOME/Wayland desktop integration

## Usage

To run once:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run github:k3d3/claude-desktop-linux-flake --impure
```

The "unfree" flag is required because Claude Desktop itself is proprietary.

## Installation on NixOS with Flakes

Add to your `flake.nix`:
```nix
inputs.claude-desktop.url = "github:k3d3/claude-desktop-linux-flake";
inputs.claude-desktop.inputs.nixpkgs.follows = "nixpkgs";
inputs.claude-desktop.inputs.flake-utils.follows = "flake-utils";
```

Then add to `environment.systemPackages` or `home.packages`:
```nix
inputs.claude-desktop.packages.${system}.claude-desktop
```

For [MCP servers](https://modelcontextprotocol.io/quickstart/user) (`npx`, `uvx`, `docker`), use the FHS variant:
```nix
inputs.claude-desktop.packages.${system}.claude-desktop-with-fhs
```

## Other Distributions

- [claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian) - Debian/Ubuntu
- [AUR package](https://aur.archlinux.org/packages/claude-desktop-bin) - Arch Linux
- [claude-desktop-linux-bash](https://github.com/wankdanker/claude-desktop-linux-bash) - Ubuntu/Debian (bash-based)

## How it Works

Claude Desktop is an Electron app. The macOS DMG is extracted, patched for Linux compatibility, and repackaged:

1. Extract `app.asar` from the macOS build
2. Patch title bar detection, platform checks, and tray icon handling
3. Replace `@ant/claude-native` Windows bindings with JavaScript stubs
4. Repackage with Linux Electron

The native binding stubs provide no-op implementations for Windows-specific features (window effects, input emulation, etc.) that aren't needed on Linux.

## License

Build scripts are dual-licensed under MIT and Apache 2.0. See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE).

Claude Desktop itself is covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).
