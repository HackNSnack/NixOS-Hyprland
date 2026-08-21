# modules/services/tailscale-protonvpn.nix
#
# Tailscale + ProtonVPN coexistence.
#
# PROBLEM (root cause, verified 2026-08-21):
#   Tailscale marks its own sockets with fwmark 0x80000 and installs ip rules
#   that send marked packets to the main routing table:
#     5210: from all fwmark 0x80000/0xff0000 lookup main
#   But ProtonVPN (NetworkManager-WireGuard, auto-default-route) moves the
#   default route OUT of `main` into a private dynamic table and only reaches
#   it via:
#     31xxx: not from all fwmark <proton-fwmark> lookup <proton-table>
#   So `main` only holds the LAN default. Tailscale's marked packets escape
#   via the LAN gateway instead of riding the VPN -> the DERP/control return
#   path comes back via proton0 -> asymmetric routing -> TLS handshake times
#   out -> `tailscale up` hangs forever.
#
#   (The earlier handoff doc blamed NetworkManager-WireGuard's fwmark and
#   proposed changing ProtonVPN's wireguard.fwmark. That was wrong: ProtonVPN's
#   fwmark is 0x640dfab6, not 0x80000, and the 0x80000 rules are Tailscale's
#   own — confirmed by stopping tailscaled and watching them vanish.)
#
# FIX:
#   One ip rule at priority 5200 (above Tailscale's 5210) that sends the same
#   fwmark to ProtonVPN's current routing table, so Tailscale's egress rides
#   proton0 symmetrically with the return path. Verified: `tailscale up`
#   completes, control + DERP + STUN work through the VPN, and the VPN stays
#   up (the prior "VPN death" was lingering route churn from a different test,
#   not this routing).
#
# DURABILITY:
#   ProtonVPN's table NUMBER is dynamic (changes across reboots, stable within
#   a session). So the rule cannot hardcode the table — it must re-read it
#   whenever proton0 comes up. An NM dispatcher fires on every proton0 up
#   event regardless of who brought the interface up (the ProtonVPN GUI app
#   owns the connection lifecycle, and `nmcli connection up` cannot reBring it
#   up after a `down`), which makes it the right primitive here.
#
# This module is always-on and harmless when proton0 never appears (the
# dispatcher only acts on `proton0 up`). No opt-in flag needed.
{
  pkgs,
  lib,
  ...
}: {
  environment.etc."NetworkManager/dispatcher.d/99-tailscale-proton.sh" = {
    mode = "0755";
    text = let
      # NM dispatcher scripts run with a minimal PATH (/bin:/usr/bin) where
      # coreutils/grep/awk are NOT present on NixOS. Pin every tool to its
      # nix-store path so the script works regardless of the dispatcher env.
      path = lib.makeBinPath [
        pkgs.iproute2
        pkgs.gnugrep
        pkgs.gawk
        pkgs.coreutils
      ];
    in ''
      #!/bin/sh
      # Tailscale + ProtonVPN coexistence — see modules/services/tailscale-protonvpn.nix
      # Fires on proton0 up: (re)add rule 5200 routing Tailscale's fwmark-0x80000
      # egress through ProtonVPN's current routing table.
      export PATH=${path}
      [ "$1" = proton0 ] && [ "$2" = up ] || exit 0

      # NM-WG may need a moment to install its table + catch-all rule after the
      # interface reports up. Retry briefly.
      TBL=""
      for _ in 1 2 3 4 5; do
        TBL="$(ip rule show | grep 'not from all fwmark' | grep -o 'lookup [0-9]*' | awk '{print $2}')"
        [ -n "$TBL" ] && break
        sleep 1
      done
      [ -z "$TBL" ] && exit 0

      ip rule del priority 5200 2>/dev/null || true
      ip rule add priority 5200 fwmark 0x80000/0xff0000 table "$TBL"
    '';
  };
}