# modules/services/ollama.nix
#
# Ollama — manual serving over the tailnet (no auto-start by default).
#
# Why a module (not a config.nix block): matches the nanoclaw / jellyfin-media
# pattern — the module owns all the config, and the host config.nix (and the
# installer's nhl_prompt_services) flips a single `ollama-net.enable = true;`
# line. Single source of truth, single-line idempotent opt-in, no copy-pasted
# multi-line blocks.
#
# What enabling does:
#   - Opens :11434 on tailscale0 ONLY (networking.firewall.interfaces). LAN
#     interfaces stay blocked; docker0 is already wholesale-accepted by
#     config.nix's extraCommands, so nanoclaw's containers still reach ollama at
#     172.17.0.1:11434. Net: reachable from nanoclaw containers + tailnet, not
#     LAN.
#   - Adds the `ollama-net` alias (binds 0.0.0.0:11434 + debug flags) so a bare
#     `ollama-net` serves over the network. Plain `ollama serve` stays
#     127.0.0.1-only (localhost).
#
# Auto-start is OFF — run `ollama-net` manually. To start ollama on boot instead,
# set `ollama-net.autoStart = true;` in the host config. That flips the nixpkgs
# `services.ollama` on (bind 0.0.0.0, openFirewall false — the tailnet rule above
# already gates :11434).
#
# GPU: the overlay's pkgs.ollama (modules/overlays.nix) bundles CUDA stubs and
# picks up the NVIDIA driver at runtime via addDriverRunpath, so we do NOT set
# services.ollama.acceleration = "cuda" (it swaps to a different nixpkgs package
# and fights the overlay). Only enable this on a GPU host.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ollama-net;
in {
  options.ollama-net = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Ollama manual serving over the tailnet: opens :11434 on
        tailscale0 only and adds the `ollama-net` alias. Ollama itself is NOT
        auto-started — run `ollama-net` by hand. Set autoStart = true to start
        on boot instead.
      '';
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start ollama automatically on boot (binds 0.0.0.0:11434, tailnet-only
        via the firewall rule). Off by default — run `ollama-net` manually.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Tailnet-only: 11434 reachable on tailscale0 (and docker0 for nanoclaw
    # containers via config.nix's wholesale ACCEPT). LAN blocked — 11434 is not
    # in allowedTCPPorts and has no rule for eth0/wlan0. Inert when tailscale0
    # doesn't exist (host not on the tailnet) or ollama isn't running.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [11434];

    # Network-serving alias. Plain `ollama serve` stays 127.0.0.1-only; use this
    # when you want nanoclaw containers + tailnet to reach ollama.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ollama-net" ''
        exec env OLLAMA_HOST=0.0.0.0:11434 OLLAMA_DEBUG_LOG_REQUESTS=true \
          OLLAMA_DEBUG=1 ${pkgs.ollama}/bin/ollama serve "$@"
      '')
    ];

    # Auto-start (off by default). Uses the nixpkgs service; acceleration left
    # at default so the overlay's bundled-CUDA ollama binary is used.
    services.ollama = lib.mkIf cfg.autoStart {
      enable = true;
      host = "0.0.0.0";
      openFirewall = false; # gated by the tailscale0 rule above
    };
  };
}