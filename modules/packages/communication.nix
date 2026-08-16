# Communication apps
# Slack and Signal kept declarative; Zoom and Teams moved to Flatpak
# (see hosts/default/config.nix services.flatpak.packages) to shrink the
# system closure.
#
# --- Reverting Zoom to declarative (if Flatpak Zoom misbehaves) ---
# 1. Remove us.zoom.Zoom from hosts/default/config.nix services.flatpak.packages.
# 2. Uncomment the zoom-wrapped let binding and the zoom-wrapped reference below.
#    The Qt5/Qt6 workaround is REQUIRED on Hyprland: Qt6 env vars set by qt6ct/
#    QML path injection (QT_QPA_PLATFORMTHEME, QML_IMPORT_PATH, QML2_IMPORT_PATH)
#    break Zoom's Qt5 window rendering, so the wrapper unsets them for zoom only.
# 3. Rebuild.
#
# Update Slack/Signal with: nix flake lock --update-input nixpkgs-latest
{ pkgs, pkgs-latest, ... }:
let
  # Zoom wrapper to fix Qt5/Qt6 conflict on Hyprland (kept for easy revert).
  # Uncomment to restore declarative Zoom; see header note above.
  # zoom-wrapped = pkgs.symlinkJoin {
  #   name = "zoom-us-wrapped";
  #   paths = [ pkgs.zoom-us ];
  #   buildInputs = [ pkgs.makeWrapper ];
  #   postBuild = ''
  #     wrapProgram $out/bin/zoom \
  #       --unset QT_QPA_PLATFORMTHEME \
  #       --unset QML_IMPORT_PATH \
  #       --unset QML2_IMPORT_PATH
  #     wrapProgram $out/bin/zoom-us \
  #       --unset QT_QPA_PLATFORMTHEME \
  #       --unset QML_IMPORT_PATH \
  #       --unset QML2_IMPORT_PATH
  #   '';
  # };

  # Signal wrapper to fix staging server issue when hostname is "default"
  # node-config loads {hostname}.json, and "default.json" contains staging URLs
  # Setting HOST env var overrides the system hostname for node-config
  signal-wrapped = pkgs.symlinkJoin {
    name = "signal-desktop-wrapped";
    paths = [ pkgs-latest.signal-desktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/signal-desktop \
        --set HOST "signal-production"
    '';
  };
in
{
  environment.systemPackages = [
    # From main nixpkgs
    #pkgs.signal-desktop
    #pkgs.signal-desktop-bin
    # pkgs.teams-for-linux  # Moved to Flatpak (com.microsoft.Teams)
    # zoom-wrapped  # Uncomment to restore declarative Zoom (see header)
    # pkgs.discord  # Uncomment if needed

    # From nixpkgs-latest (can be updated independently)
    #pkgs-latest.zoom-us
    signal-wrapped  # Wrapped to avoid staging server when hostname is "default"
    pkgs-latest.slack
  ];
}
