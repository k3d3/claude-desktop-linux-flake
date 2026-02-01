# CLAUDE.md

## Project Overview

Nix flake that runs Claude Desktop on Linux by repackaging the macOS build with JavaScript stubs for the native bindings.

## Building

```bash
nix build .#claude-desktop          # Standard build
nix build .#claude-desktop-with-fhs # With FHS environment for MCP servers
nix run .                           # Build and run
```

## Architecture

The build process (`pkgs/claude-desktop.nix`):

1. Download macOS DMG
2. Extract with 7z (handles HFS+ despite warnings)
3. Extract and patch `app.asar`:
   - Title bar: Enable native frames on Linux
   - Platform detection: Add `linux-x64`/`linux-arm64` for Claude Code
   - Origin validation: Allow `file://` protocol when unpackaged
   - Tray icons: Theme-aware selection
   - Window blur: Fix quick-submit focus
4. Replace `@ant/claude-native` with inline JS stubs
5. Repackage and wrap with Electron

## Updating Version

In `pkgs/claude-desktop.nix`:
1. Update `version`
2. Update `srcDmg.url` with new version/hash from filename
3. Update `srcDmg.hash` (run `nix-prefetch-url <url>` then `nix hash to-sri sha256:<hash>`)

## Packages

- `claude-desktop` - Standard build
- `claude-desktop-with-fhs` - FHS wrapper for MCP servers (npx, uvx, docker)
- `claude-desktop-shell` - FHS shell for MCP development
