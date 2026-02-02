# Claude Code Context for NixOS-Hyprland

## Overview

This is a **personal fork** of [JaKooLit/NixOS-Hyprland](https://github.com/JaKooLit/NixOS-Hyprland), a framework for installing NixOS with the Hyprland window manager.

**Owner**: HackNSnack
**Upstream**: https://github.com/JaKooLit/NixOS-Hyprland
**Fork**: https://github.com/HackNSnack/NixOS-Hyprland

## Repository Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    NixOS-Hyprland (this repo)               │
│  - NixOS system configuration                               │
│  - Install scripts                                          │
│  - Flake with package definitions                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ install.sh clones & runs copy.sh
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              Hyprland-Dots (separate repo)                  │
│  Fork: https://github.com/HackNSnack/Hyprland-Dots          │
│  - Hyprland configs (~/.config/hypr/)                       │
│  - Waybar, rofi, kitty configs                              │
│  - User customizations in UserConfigs/                      │
└─────────────────────────────────────────────────────────────┘
```

## Key Architectural Differences from Upstream

### 1. Modular Package Structure

**Upstream**: All packages in `modules/packages.nix`

**This fork**: Packages split into category modules:
```
modules/packages/
├── dev-python.nix      # Python 3.13 + packages
├── dev-clojure.nix     # Clojure, leiningen, babashka
├── dev-dotnet.nix      # .NET 9 SDK/runtime
├── dev-node.nix        # Node.js, pnpm
├── dev-nix-lua.nix     # nil, nixfmt, lua-language-server
├── cloud.nix           # Azure CLI, GCloud SDK
├── database.nix        # MySQL, Redis
├── communication.nix   # Signal, Teams, Zoom, Slack
├── ai-tools.nix        # Claude Code, Gemini CLI
├── browsers.nix        # Vivaldi (from nixpkgs-latest)
├── security.nix        # ClamAV, Wireshark
├── media.nix           # Spotify, JamesDSP
├── productivity.nix    # Obsidian, rofi-calc
├── privacy.nix         # Proton suite
├── keyboards.nix       # QMK, Vial, Via
└── misc.nix            # Various tools
```

### 2. Always-Latest Package Strategy

Some packages use dedicated flake inputs for latest versions:
- `inputs.claude-code` → Claude Code CLI
- `inputs.neovim-nightly` → Neovim nightly overlay
- `pkgs-latest` (nixpkgs-latest) → Vivaldi, Zoom, Slack

### 3. Additional System Modules

- `modules/nix-ld.nix` - For running unpatched binaries
- Docker enabled with firewall rules for bridge interfaces
- OBS virtual camera kernel modules
- Custom /etc/hosts entries for development

### 4. Install Script Enhancements

- **Installation mode selection**: Full/System/Dotfiles/Custom
- **Norwegian defaults**: Keyboard `no`, timezone `Europe/Oslo`
- **Personal repos**: Points to HackNSnack forks for dotfiles
- **Shell setup**: Downloads oh-my-posh theme and fzf-git.sh

### 5. Locale Settings

- Keyboard: Norwegian (`no`)
- Timezone: Europe/Oslo
- Locale: en_GB.UTF-8 with nb_NO.UTF-8 for LC_* settings

## Files That Should NEVER Be Overwritten by Upstream

These contain personal customizations:
- `hosts/default/variables.nix` - Username, email, browser preferences
- `hosts/default/config.nix` - Custom hosts, firewall rules, services
- `modules/packages/*.nix` - All modular package files
- `modules/nix-ld.nix` - nix-ld configuration
- `assets/.zshrc` - Custom shell configuration
- `install.sh` / `auto-install.sh` - Modified install flow

## Files Safe to Update from Upstream

These can usually be merged:
- `flake.lock` - Package versions (merge carefully)
- `modules/home/*.nix` - Home manager modules (except removed nixvim)
- `scripts/lib/install-common.sh` - Common functions (check for conflicts)
- Documentation files

## Merge Conflict Resolution Strategy

### Priority Rules
1. **Personal customizations take priority** over upstream defaults
2. **Structural changes** (modular packages) should be preserved
3. **New upstream features** should be integrated if they don't conflict
4. **Deprecated options** - follow upstream's lead on removals

### Common Conflict Patterns

1. **Package additions in modules/packages.nix**
   - Upstream adds packages to monolithic file
   - Resolution: Add to appropriate modular file instead

2. **Install script changes**
   - Upstream changes prompts/flow
   - Resolution: Merge new features but keep Norwegian defaults and mode selection

3. **Flake input changes**
   - Upstream updates nixpkgs or adds inputs
   - Resolution: Usually safe to accept, but keep custom inputs (claude-code, neovim-nightly, nixpkgs-latest)

4. **Config option changes**
   - Upstream changes Hyprland/NixOS options
   - Resolution: Check if option was renamed/removed, update accordingly

## Useful Commands

```bash
# Check upstream changes
./scripts/sync-upstream.sh --dry-run

# Merge upstream
./scripts/sync-upstream.sh

# Verify NixOS config
nix flake check

# Verify Hyprland config
Hyprland --verify-config
```

## Related Repositories

- **Hyprland-Dots fork**: ~/Hyprland-Dots (https://github.com/HackNSnack/Hyprland-Dots)
- **Neovim config**: https://github.com/HackNSnack/nvim2.git
- **Waybar config**: https://github.com/HackNSnack/waybar_configs.git
