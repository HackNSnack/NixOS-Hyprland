#!/usr/bin/env bash
# Common installer helpers for NixOS-Hyprland
# Sourced by install.sh and auto-install.sh

nhl_detect_gpu_and_toggle() {
  # Args: $1 = hostName
  local hostName="$1"
  local cfg="./hosts/$hostName/config.nix"
  [ -f "$cfg" ] || cfg="./hosts/default/config.nix"

  local has_vm=false has_nvidia=false has_amd=false has_intel=false

  if hostnamectl | grep -q 'Chassis: vm'; then
    has_vm=true
  fi
  if command -v lspci >/dev/null 2>&1; then
    while read -r line; do
      if echo "$line" | grep -qi 'nvidia'; then
        has_nvidia=true
      elif echo "$line" | grep -qi 'amd'; then
        has_amd=true
      elif echo "$line" | grep -qi 'intel'; then
        has_intel=true
      fi
    done < <(lspci | grep -iE '(VGA|3D)')
  fi

  # Decide detected profile
  local detected=""
  if $has_vm; then
    detected="vm"
  elif $has_nvidia && $has_intel; then
    detected="nvidia-laptop"
  elif $has_nvidia; then
    detected="nvidia"
  elif $has_amd; then
    detected="amd"
  elif $has_intel; then
    detected="intel"
  fi

  # Confirm or manually choose profile
  local profile="$detected"
  if [ -n "$detected" ]; then
    printf "Detected GPU profile: %s. Use this? (Y/n): " "$detected"
    read -r _ans </dev/tty || true
    if [ -n "$_ans" ] && ! echo "$_ans" | grep -qi '^y'; then
      profile=""
    fi
  fi
  if [ -z "$profile" ]; then
    printf "Enter your GPU profile (amd|intel|nvidia|nvidia-laptop|vm): [amd] "
    read -r profile </dev/tty || true
    profile=${profile:-amd}
  fi

  # Reset toggles
  sed -i 's/drivers\.amdgpu\.enable = [^;]*;/drivers.amdgpu.enable = false;/' "$cfg" || true
  sed -i 's/drivers\.intel\.enable = [^;]*;/drivers.intel.enable = false;/' "$cfg" || true
  sed -i 's/drivers\.nvidia\.enable = [^;]*;/drivers.nvidia.enable = false;/' "$cfg" || true
  sed -i 's/drivers\.nvidia-prime\.enable = [^;]*;/drivers.nvidia-prime.enable = false;/' "$cfg" || true
  sed -i 's/vm\.guest-services\.enable = [^;]*;/vm.guest-services.enable = false;/' "$cfg" || true

  # Apply selected profile
  case "$profile" in
    vm)
      sed -i 's/vm\.guest-services\.enable = [^;]*;/vm.guest-services.enable = true;/' "$cfg" || true
      ;;
    nvidia-laptop)
      sed -i 's/drivers\.nvidia-prime\.enable = [^;]*;/drivers.nvidia-prime.enable = true;/' "$cfg" || true
      sed -i 's/drivers\.intel\.enable = [^;]*;/drivers.intel.enable = true;/' "$cfg" || true
      ;;
    nvidia)
      sed -i 's/drivers\.nvidia\.enable = [^;]*;/drivers.nvidia.enable = true;/' "$cfg" || true
      ;;
    amd)
      sed -i 's/drivers\.amdgpu\.enable = [^;]*;/drivers.amdgpu.enable = true;/' "$cfg" || true
      ;;
    intel)
      sed -i 's/drivers\.intel\.enable = [^;]*;/drivers.intel.enable = true;/' "$cfg" || true
      ;;
    *)
      # Fallback: do nothing if unknown
      ;;
  esac
}

nhl_prompt_timezone_console() {
  # Args: $1 = hostName, $2 = defaultKeyboardLayout
  local hostName="$1"
  local defKb="${2:-no}"
  local cfg="./hosts/$hostName/config.nix"
  [ -f "$cfg" ] || cfg="./hosts/default/config.nix"

  # Timezone prompt (default: Europe/Oslo)
  local timeZone
  read -rp "Enter your timezone (e.g. Europe/Oslo): [ Europe/Oslo ] " timeZone </dev/tty
  timeZone=${timeZone:-Europe/Oslo}
  # Set explicit timezone and disable automatic (only modify if setting exists in config)
  if grep -q 'time\.timeZone' "$cfg"; then
    sed -i "s|time\.timeZone = \".*\";|time.timeZone = \"$timeZone\";|" "$cfg" || true
  fi
  if grep -q 'services\.automatic-timezoned\.enable' "$cfg"; then
    sed -i 's/services\.automatic-timezoned\.enable = [^;]*/services.automatic-timezoned.enable = false/' "$cfg" || true
  fi

  # Console keymap prompt (defaults to keyboardLayout)
  local consoleKeyMap
  read -rp "Enter your console keymap: [$defKb] " consoleKeyMap </dev/tty
  consoleKeyMap=${consoleKeyMap:-$defKb}
  # Replace existing console.keyMap assignment (only if it exists)
  if grep -q 'console\.keyMap' "$cfg"; then
    sed -i "s|console\.keyMap = \".*\";|console.keyMap = \"$consoleKeyMap\";|" "$cfg" || true
  fi
}

nhl_check_go_version() {
  local min_version="1.25.5"
  local nix_go_version=""
  local go_version=""

  if command -v nix >/dev/null 2>&1; then
    nix_go_version=$(NIX_CONFIG="experimental-features = nix-command flakes" nix eval --raw "nixpkgs#go.version" 2>/dev/null || true)
  fi

  if [ -n "$nix_go_version" ]; then
    if [ "$(printf '%s\n' "$min_version" "$nix_go_version" | sort -V | head -n1)" != "$min_version" ]; then
      echo "${ERROR} Go in nixpkgs is ${nix_go_version}, but ${min_version} or greater is required."
      exit 1
    fi
    echo "${OK} Go in nixpkgs is ${nix_go_version} (>= ${min_version})."
    return 0
  fi

  if command -v go >/dev/null 2>&1; then
    go_version=$(go version | awk '{print $3}' | sed 's/^go//')
    if [ -n "$go_version" ] && [ "$(printf '%s\n' "$min_version" "$go_version" | sort -V | head -n1)" = "$min_version" ]; then
      echo "${OK} Go is ${go_version} (>= ${min_version})."
      return 0
    fi
    echo "${ERROR} Go is ${go_version}, but ${min_version} or greater is required."
    exit 1
  fi

  echo "${ERROR} Unable to determine Go version. Please ensure Go ${min_version}+ is available."
  exit 1
}

# Prompt for optional services (NanoClaw, Jellyfin) and insert/remove their
# `enable = true;` override in the host config.nix. The enable flags default to
# false in their modules, so "off" = no line at all (module default applies) —
# no duplicated defaults in config.nix. Jellyfin accel is derived in the module
# from the per-host driver toggles, so the installer touches nothing but enable.
# Args: $1 = hostName
nhl_prompt_services() {
  local hostName="$1"
  local cfg="./hosts/$hostName/config.nix"
  [ -f "$cfg" ] || cfg="./hosts/default/config.nix"

  # Idempotency: remove any previously-inserted managed enable lines first,
  # so re-runs never stack duplicates. Lines are tagged # nhl:nanoclaw-enable /
  # # nhl:jellyfin-enable / # nhl:tailscale-enable / # nhl:ollama-enable so only
  # installer-managed lines are touched.
  sed -i '/# nhl:nanoclaw-enable/d' "$cfg" 2>/dev/null || true
  sed -i '/# nhl:jellyfin-enable/d' "$cfg" 2>/dev/null || true
  sed -i '/# nhl:tailscale-enable/d' "$cfg" 2>/dev/null || true
  sed -i '/# nhl:ollama-enable/d' "$cfg" 2>/dev/null || true

  echo "-----"
  echo "$NOTE Optional services (default off to avoid duplicate instances on the LAN):"

  local ans
  read -rp "$CAT Enable NanoClaw (AI assistant)? [y/N]: " ans </dev/tty || true
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    # Insert the override below the anchor in config.nix.
    sed -i 's|# nhl:services-anchor|# nhl:services-anchor\n  services.nanoclaw.enable = true; # nhl:nanoclaw-enable|' "$cfg" || true
    echo "$OK NanoClaw enabled"
  else
    echo "$NOTE NanoClaw left disabled"
  fi

  read -rp "$CAT Enable Jellyfin media server? [y/N]: " ans </dev/tty || true
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sed -i 's|# nhl:services-anchor|# nhl:services-anchor\n  jellyfin-media.enable = true; # nhl:jellyfin-enable|' "$cfg" || true
    # Accel is derived in the module from drivers.*.enable (set above by
    # nhl_detect_gpu_and_toggle). NVENC/CUDA is deferred — to enable NVENC
    # later, set jellyfin-media.accel.type = "nvenc" + cudaSupport = true
    # (and the device path) in the host config.
    echo "$OK Jellyfin enabled (accel derived from GPU drivers; NVENC deferred)"
  else
    echo "$NOTE Jellyfin left disabled"
  fi

  # Tailscale is the network layer for remote access — once the host joins the
  # tailnet it gets a 100.x.y.z IP and every listening service with openFirewall
  # (or a tailscale0 interface rule) is reachable from authenticated peers.
  # This is a host-level opt-in; per-service exposure is governed by each
  # service's own openFirewall / networking.firewall.interfaces.tailscale0.
  read -rp "$CAT Enable Tailscale (remote access over tailnet)? [y/N]: " ans </dev/tty || true
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sed -i 's|# nhl:services-anchor|# nhl:services-anchor\n  services.tailscale = { enable = true; openFirewall = true; }; # nhl:tailscale-enable|' "$cfg" || true
    echo "$OK Tailscale enabled (run 'sudo tailscale up' after rebuild to authenticate)"
  else
    echo "$NOTE Tailscale left disabled"
  fi

  # Ollama is run MANUALLY (not auto-started). Enabling here only flips the
  # ollama-net module (modules/services/ollama.nix): it opens the tailnet-only
  # firewall rule on :11434 and adds the `ollama-net` alias (binds 0.0.0.0:11434
  # so nanoclaw's Docker containers on docker0/172.17.0.1 AND the tailnet on
  # tailscale0 can reach it; LAN blocked). To auto-start ollama on boot instead
  # of running `ollama-net` by hand, set ollama-net.autoStart = true in the host
  # config. Only enable on a GPU host (the overlay's pkgs.ollama bundles CUDA).
  read -rp "$CAT Enable Ollama tailnet serving (manual; GPU host)? [y/N]: " ans </dev/tty || true
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sed -i 's|# nhl:services-anchor|# nhl:services-anchor\n  ollama-net.enable = true; # nhl:ollama-enable|' "$cfg" || true
    echo "$OK Ollama tailnet serving enabled (run 'ollama-net' to serve; :11434 tailnet-only)"
  else
    echo "$NOTE Ollama tailnet serving left disabled"
  fi
}

# Remove stale Home Manager backup files (*.hm-bak) before a rebuild.
# flake.nix sets home-manager.backupFileExtension = "hm-bak", so when HM takes
# over a file that already exists on disk it moves it to <file>.hm-bak. HM never
# cleans these up, so a stale .hm-bak from a prior failed activation makes the
# next activation refuse with "Existing file ... would be clobbered by backing
# up ...". Clearing them before rebuild breaks that stuck loop.
nhl_clean_hm_backups() {
  local removed=0 f
  while IFS= read -r -d '' f; do
    rm -f "$f"
    removed=$((removed + 1))
  done < <(find "${HOME}/.config" -name '*.hm-bak' -type f -print0 2>/dev/null)
  if [ "$removed" -gt 0 ]; then
    echo "$NOTE Removed $removed stale Home Manager backup(s) (*.hm-bak) under ~/.config"
  fi
}
