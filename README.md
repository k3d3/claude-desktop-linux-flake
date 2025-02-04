***THIS IS AN UNOFFICIAL BUILD SCRIPT!***

If you run into an issue with this build script, make an issue here. Don't bug Anthropic about it - they already have enough on their plates.

# Claude Desktop for Linux (Nix)

Supports MCP!
![image](https://github.com/user-attachments/assets/93080028-6f71-48bd-8e59-5149d148cd45)

Supports the Ctrl+Alt+Space popup!
![image](https://github.com/user-attachments/assets/1deb4604-4c06-4e4b-b63f-7f6ef9ef28c1)

Supports the Tray menu! (Screenshot of running on KDE)

![image](https://github.com/user-attachments/assets/ba209824-8afb-437c-a944-b53fd9ecd559)

This is a Nix flake for running Claude Desktop on Linux.

# Usage

To run this once, make sure Nix is installed, then run

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run github:k3d3/claude-desktop-linux-flake --impure
```

The "unfree" part is due to the fact that Claude Desktop is not an open source application, and thus, Nix's licensing rules
are dictated by the application itself, not the build script used to build the application.

## Installation on NixOS with Flakes

Add the following to your `flake.nix`:
```nix
inputs.claude-desktop.url = "github:k3d3/claude-desktop-linux-flake";
inputs.claude-desktop.inputs.nixpkgs.follows = "nixpkgs";
inputs.claude-desktop.inputs.flake-utils.follows = "flake-utils";
```

And then the following package to your `environment.systemPackages` or `home.packages`:
```nix
inputs.claude-desktop.packages.${system}.claude-desktop
```

If you would like to run [MCP servers with Claude Desktop](https://modelcontextprotocol.io/quickstart/user) on NixOS, use the `claude-desktop-with-fhs` package. This will allow running MCP servers with calls to `npx`, `uvx`, or `docker` (assuming docker is installed).
```nix
inputs.claude-desktop.packages.${system}.claude-desktop-with-fhs
```

## Other distributions

This repository only provides a Nix flake, and does not provide a package for e.g. Ubuntu, Fedora, or Arch Linux.

Other known variants:
- https://github.com/wankdanker/claude-desktop-linux-bash - A bash-based Claude Desktop builder that works on Ubuntu and possibly other Debian derivatives

If anyone else packages Claude Desktop for other distributions, make an issue or PR and I'll link it here.

# How it works

Claude Desktop is an Electron application. That means the majority of the application is inside an `app.asar` archive, which usually contains minified Javascript, HTML, and CSS, along with images and a few other things.

Despite there being no official Linux Claude Desktop release, the vast majority of the code is completely cross-platform.

With the exception of one library.

## `claude-native-bindings`

![image](https://github.com/user-attachments/assets/9b386f42-2565-441a-a351-9c09347f9f5f)

Node, and by extension Electron, allow you to import natively-compiled objects into the Node runtime as if they were regular modules.
These are typically used to extend the functionality in ways Node itself can't do. Only problem, as shown above, is that these objects 
are only compiled for one OS. 

Luckily enough, because it's a loadable Node module, that means you can open it up yourself in node and inspect it - no decompilation or disassembly needed:

![image](https://github.com/user-attachments/assets/b2f1e72c-f763-45c0-8631-2de5555ae653)

There are many functions here for getting monitor/window information, as well as for controlling the mouse and keyboard.
I'm not sure what exactly these are for - my best guess is something unreleased related to [Computer Use](https://docs.anthropic.com/en/docs/build-with-claude/computer-use),
however I'm not a huge fan of this functionality existing in the first place.

As for how to move forward with getting Claude Desktop working on Linux, seeing as how the API surface area of this module is relatively
small, it looked fairly easy to just wholesale reimplement it, using stubs for the functionality.

## `patchy-cnb`

The result of that is a library I call `patchy-cnb`, which uses NAPI-RS to match the original API with stub functions.
Turns out, the original module also used NAPI-RS. Neat!

From there, it's just a matter of compiling `patchy-cnb`, repackaging the app.asar to include the newly built Linux module, and
making a new Electron build with these files.

# License

The build scripts in this repository, as well as `patchy-cnb`, are dual-licensed under the terms of the MIT license and the Apache License (Version 2.0).

See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE) for details.

The Claude Desktop application, not included in this repository, is likely covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).

## Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any
additional terms or conditions.
