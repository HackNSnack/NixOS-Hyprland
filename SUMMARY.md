# Summary of NixOS-Hyprland Customizations

This document summarizes all customizations made to this fork of JaKooLit/NixOS-Hyprland and the related Hyprland-Dots repository.

---

## Repository Overview

| Repository | Upstream | Fork |
|------------|----------|------|
| NixOS-Hyprland | https://github.com/JaKooLit/NixOS-Hyprland | https://github.com/HackNSnack/NixOS-Hyprland |
| Hyprland-Dots | https://github.com/JaKooLit/Hyprland-Dots | https://github.com/HackNSnack/Hyprland-Dots |
| Neovim Config | N/A (custom) | https://github.com/HackNSnack/nvim2 |
| Waybar Config | N/A (custom) | https://github.com/HackNSnack/waybar_configs |

---

## Part 1: NixOS-Hyprland Changes

### 1.1 Locale & Regional Settings

**Changed from upstream defaults to Norwegian:**

| Setting | Upstream Default | Fork Default |
|---------|------------------|--------------|
| Keyboard layout | `us` | `no` |
| Timezone | Auto-detect | `Europe/Oslo` |
| Console keymap | `us` | `no` |
| Locale | `en_US.UTF-8` | `en_GB.UTF-8` |
| LC_* settings | `en_US.UTF-8` | `nb_NO.UTF-8` |

**Files modified:**
- `hosts/default/config.nix` - Timezone, locale settings
- `hosts/default/variables.nix` - Keyboard layout
- `install.sh` / `auto-install.sh` - Default prompts
- `scripts/lib/install-common.sh` - Timezone/keymap defaults

---

### 1.2 Modular Package Structure

**Upstream:** All packages in single `modules/packages.nix` file

**Fork:** Packages split into category-based modules:

```
modules/packages/
├── dev-python.nix      # Python 3.13 + packages (requests, fastapi, numpy, pandas, etc.)
├── dev-clojure.nix     # Clojure, clojure-lsp, leiningen, babashka, jdk21, cljfmt
├── dev-dotnet.nix      # .NET 9 SDK/runtime, csharp-ls, csharpier, netcoredbg
├── dev-node.nix        # Node.js, pnpm, prettierd
├── dev-nix-lua.nix     # nil, nixfmt, lua-language-server, stylua, llm-ls
├── dev-editors.nix     # VSCode
├── cloud.nix           # Azure CLI (with extensions), Google Cloud SDK, Azure Data Studio
├── database.nix        # MySQL 8.4, Redis, RedisInsight
├── communication.nix   # Signal, Teams, Zoom (from nixpkgs-latest), Slack (from nixpkgs-latest)
├── ai-tools.nix        # Claude Code (dedicated flake), Gemini CLI
├── browsers.nix        # Vivaldi (from nixpkgs-latest), vivaldi-ffmpeg-codecs
├── security.nix        # ClamAV (with daemon), Wireshark
├── media.nix           # Spotify, JamesDSP, PulseAudio
├── productivity.nix    # Obsidian, libqalculate, rofi-calc
├── privacy.nix         # ProtonVPN, Proton Pass, Protonmail Desktop
├── keyboards.nix       # QMK, Vial, Via (with udev rules)
└── misc.nix            # Cloudflare WARP, moon, vim, gh, xclip, zip, xdg-utils
```

---

### 1.3 Always-Latest Package Strategy

**New flake inputs added for packages that should always be latest:**

```nix
# In flake.nix
inputs = {
  nixpkgs-latest.url = "github:nixos/nixpkgs/nixos-unstable";
  claude-code.url = "github:sadjow/claude-code-nix";
  neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
};
```

| Package | Source |
|---------|--------|
| Claude Code | `inputs.claude-code` (dedicated flake) |
| Neovim | `neovim-nightly` overlay |
| Vivaldi | `pkgs-latest` (nixpkgs-latest) |
| Zoom | `pkgs-latest` |
| Slack | `pkgs-latest` |

---

### 1.4 Additional System Modules

#### nix-ld (`modules/nix-ld.nix`)
Enables running unpatched binaries with common libraries pre-configured.

#### Docker Configuration
```nix
virtualisation.docker.enable = true;
users.users.${username}.extraGroups = ["docker"];

# Firewall rules for Docker bridges
networking.firewall = {
  extraCommands = "iptables -I nixos-fw 1 -i br+ -j ACCEPT";
  extraStopCommands = "iptables -D nixos-fw -i br+ -j ACCEPT || true";
};
```

#### OBS Virtual Camera
```nix
boot.kernelModules = ["v4l2loopback"];
boot.extraModulePackages = [pkgs.linuxPackages_zen.v4l2loopback];
```

#### Custom /etc/hosts
Development-related host entries for local services.

---

### 1.5 Install Script Enhancements

#### Installation Mode Selection (NEW)
```
1) Full install      - NixOS rebuild + all dotfiles/themes
2) System only       - NixOS rebuild only (no dotfiles/themes)
3) Dotfiles only     - Dotfiles/themes only (no NixOS rebuild)
4) Custom            - Choose individual components
```

#### Custom Mode Components
- Configure system (hostname, GPU, keyboard, timezone)
- Run NixOS rebuild
- Copy .zshrc
- Install GTK themes and icons
- Copy config directories (gtk-3.0, Thunar, xfce4)
- Install Hyprland-Dots
- Install Neovim configuration
- Install Waybar configuration
- Copy fastfetch config

#### Personal Repository URLs
```bash
# Hyprland-Dots
https://github.com/HackNSnack/Hyprland-Dots.git

# Neovim config
https://github.com/HackNSnack/nvim2.git

# Waybar config
https://github.com/HackNSnack/waybar_configs.git
```

#### Smart Config Cloning
Handles existing directories that aren't git repos:
- Checks for `.git` directory
- If exists as git repo → `git pull`
- If exists but not git repo → backup and clone fresh
- If doesn't exist → clone

#### Shell Setup Downloads
Automatically downloads during zshrc setup:
- `~/jandedobbeleer.omp.json` - oh-my-posh theme
- `~/fzf-git.sh` - fzf git integration

---

### 1.6 Removed Components

#### Nixvim
Removed in favor of separate neovim config repository:
- Deleted `modules/home/editors/nixvim.nix`
- Deleted `assets/Intro-to-Neovim.md` and `.es.md`
- Removed nixvim flake input
- Removed import from `modules/home/default.nix`

---

### 1.7 variables.nix Configuration

```nix
{
  gitUsername = "HacknSnack";
  gitEmail = "mathias.pettersen@proton.me";
  browser = "vivaldi";
  terminal = "kitty";
  keyboardLayout = "no";
  clock24h = true;
}
```

---

### 1.8 Custom .zshrc (`assets/.zshrc`)

Features:
- **oh-my-posh** with jandedobbeleer theme
- **FZF** with custom colors and fd integration
- **FZF git integration** (fzf-git.sh)
- **bat** with tokyonight_night theme
- **eza** aliases for ls replacement
- **NixOS aliases**: `nix_list_gen`, `nix_del_old`
- **fastfetch** on terminal launch

---

### 1.9 Deprecated Package Fixes

Updated package names for nixpkgs compatibility:
| Old Name | New Name |
|----------|----------|
| `nixfmt-rfc-style` | `nixfmt` |
| `xfce.exo` | `xfce4-exo` |
| `xfce.mousepad` | `mousepad` |
| `xfce.thunar-archive-plugin` | `thunar-archive-plugin` |
| `xfce.thunar-volman` | `thunar-volman` |
| `xfce.tumbler` | `tumbler` |

---

## Part 2: Hyprland-Dots Changes

### 2.1 Two-Tier Configuration System

The fork leverages upstream's layered config approach:

```
config/hypr/
├── configs/           # UPSTREAM DEFAULTS
│   ├── Keybinds.conf
│   ├── Settings.conf
│   └── Startup_Apps.conf
└── UserConfigs/       # USER OVERRIDES (our customizations)
    ├── 01-UserDefaults.conf
    ├── UserSettings.conf
    ├── UserKeybinds.conf
    └── Startup_Apps.conf
```

---

### 2.2 UserConfigs Customizations

#### 01-UserDefaults.conf
```conf
env = EDITOR,nvim
$term = kitty
$files = thunar
$Search_Engine = "https://www.qwant.com/?q={}"
```

#### UserSettings.conf
```conf
input {
  kb_layout = no
  repeat_rate = 50
  repeat_delay = 300
  numlock_by_default = true

  touchpad {
    natural_scroll = true
    tap-to-click = true
  }
}

misc {
  disable_hyprland_logo = true
  vfr = true
  vrr = 2
}

cursor {
  no_hardware_cursors = 2
  enable_hyprcursor = true
}
```

#### UserKeybinds.conf
```conf
bindd = $mainMod SHIFT, V, Open Vivaldi browser, exec, vivaldi
```

#### Startup_Apps.conf
```conf
exec-once = protonvpn-app
exec-once = $UserScripts/RainbowBorders.sh
```

---

### 2.3 Other Customizations

| File | Change |
|------|--------|
| `config/hypr/configs/ENVariables.conf` | Bibata-Modern-Ice cursor enabled |
| `config/kitty/kitty.conf` | Font size: 14 (was 16) |
| `config/rofi/0-shared-fonts.rasi` | Reduced font sizes |

---

### 2.4 Deprecated Options Removed

Removed `gestures` block (options moved to `input:touchpad` in recent Hyprland):
```conf
# OLD (removed):
gestures {
  workspace_swipe = true
  workspace_swipe_fingers = 3
  ...
}

# NEW (comment only):
# Gestures now configured in input:touchpad
```

---

## Part 3: Merge Conflict Resolution Tools

### 3.1 CLAUDE.md Context Files

Created for both repositories to provide Claude Code with context:
- `~/NixOS-Hyprland/CLAUDE.md`
- `~/Hyprland-Dots/CLAUDE.md`

### 3.2 Sync Script (`scripts/sync-upstream.sh`)

Usage:
```bash
# Check for upstream changes (dry run)
./scripts/sync-upstream.sh --dry-run

# Merge upstream changes
./scripts/sync-upstream.sh

# Merge with Claude-assisted conflict resolution
./scripts/sync-upstream.sh --claude
```

Features:
- Fetches and shows upstream commit summary
- Dry-run mode to preview conflicts
- Automatic merge attempt
- Claude Code integration for conflict resolution
- Context-aware prompts with customization guidelines

---

## Part 4: File Change Summary

### NixOS-Hyprland Files Modified

| File | Type of Change |
|------|----------------|
| `flake.nix` | Added inputs (claude-code, neovim-nightly, nixpkgs-latest) |
| `hosts/default/config.nix` | Locale, Docker, OBS, hosts, firewall, module imports |
| `hosts/default/variables.nix` | Username, email, browser, keyboard |
| `install.sh` | Mode selection, Norwegian defaults, personal repos, shell setup |
| `auto-install.sh` | Same as install.sh |
| `scripts/lib/install-common.sh` | Norwegian defaults, removed append fallbacks |
| `modules/packages.nix` | Fixed deprecated package names |
| `modules/overlays.nix` | Added neovim-nightly overlay |
| `modules/home/default.nix` | Removed nixvim import |
| `assets/.zshrc` | Complete rewrite with oh-my-posh, fzf, eza |

### NixOS-Hyprland Files Added

| File | Purpose |
|------|---------|
| `modules/nix-ld.nix` | nix-ld configuration |
| `modules/packages/*.nix` | 16 modular package files |
| `scripts/sync-upstream.sh` | Upstream sync helper |
| `CLAUDE.md` | Claude Code context |
| `SUMMARY.md` | This file |

### NixOS-Hyprland Files Deleted

| File | Reason |
|------|--------|
| `modules/home/editors/nixvim.nix` | Using separate neovim repo |
| `assets/Intro-to-Neovim.md` | No longer needed |
| `assets/Intro-to-Neovim.es.md` | No longer needed |

### Hyprland-Dots Files Modified

| File | Type of Change |
|------|----------------|
| `config/hypr/UserConfigs/01-UserDefaults.conf` | Qwant search, nvim editor |
| `config/hypr/UserConfigs/UserSettings.conf` | Norwegian keyboard, input settings |
| `config/hypr/UserConfigs/UserKeybinds.conf` | Vivaldi keybind |
| `config/hypr/UserConfigs/Startup_Apps.conf` | ProtonVPN, RainbowBorders |
| `config/hypr/configs/ENVariables.conf` | Bibata cursor enabled |
| `config/kitty/kitty.conf` | Font size 14 |
| `config/rofi/0-shared-fonts.rasi` | Smaller fonts |

### Hyprland-Dots Files Added

| File | Purpose |
|------|---------|
| `scripts/sync-upstream.sh` | Upstream sync helper |
| `CLAUDE.md` | Claude Code context |

---

## Part 5: Quick Reference

### Useful Commands

```bash
# Verify NixOS configuration
nix flake check

# Test rebuild without applying
sudo nixos-rebuild dry-run --flake ~/NixOS-Hyprland#default

# Apply NixOS configuration
sudo nixos-rebuild switch --flake ~/NixOS-Hyprland#default

# Verify Hyprland config
Hyprland --verify-config

# Reload Hyprland config (from within Hyprland)
hyprctl reload

# Sync with upstream
./scripts/sync-upstream.sh --dry-run  # Preview
./scripts/sync-upstream.sh            # Merge
./scripts/sync-upstream.sh --claude   # Merge with Claude help
```

### Git Remotes Setup

```bash
# NixOS-Hyprland
origin   → https://github.com/HackNSnack/NixOS-Hyprland.git (fork)
upstream → https://github.com/JaKooLit/NixOS-Hyprland.git (original)

# Hyprland-Dots
origin   → https://github.com/HackNSnack/Hyprland-Dots.git (fork)
upstream → https://github.com/JaKooLit/Hyprland-Dots.git (original)
```

---

## Part 6: Merge Conflict Priority Rules

When merging upstream changes:

1. **Personal customizations ALWAYS take priority**
   - Norwegian locale/keyboard settings
   - Personal repo URLs
   - Modular package structure
   - UserConfigs/ in Hyprland-Dots

2. **Accept from upstream**
   - Bug fixes
   - Hyprland/NixOS compatibility updates
   - New features that don't conflict
   - Script improvements

3. **Merge carefully**
   - flake.lock (keep custom inputs)
   - modules/packages.nix (add new packages to modular files)
   - Install script changes (keep mode selection and defaults)

4. **Never overwrite**
   - `hosts/default/variables.nix`
   - `modules/packages/*.nix`
   - `UserConfigs/*` in Hyprland-Dots
