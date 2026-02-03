# Communication apps
# Zoom and Slack use pkgs-latest for independent updates
# Update with: nix flake lock --update-input nixpkgs-latest
{ pkgs, pkgs-latest, ... }:
let
  # Zoom wrapper to fix Qt5/Qt6 conflict on Hyprland
  # Qt6 env vars (qt6ct, QML paths) break Zoom's Qt5 window rendering
  zoom-wrapped = pkgs.symlinkJoin {
    name = "zoom-us-wrapped";
    paths = [ pkgs.zoom-us ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zoom \
        --unset QT_QPA_PLATFORMTHEME \
        --unset QML_IMPORT_PATH \
        --unset QML2_IMPORT_PATH
      wrapProgram $out/bin/zoom-us \
        --unset QT_QPA_PLATFORMTHEME \
        --unset QML_IMPORT_PATH \
        --unset QML2_IMPORT_PATH
    '';
  };

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
    pkgs.teams-for-linux
    zoom-wrapped  # Wrapped to fix Qt5/Qt6 conflict on Hyprland
    # pkgs.discord  # Uncomment if needed

    # From nixpkgs-latest (can be updated independently)
    #pkgs-latest.zoom-us
    signal-wrapped  # Wrapped to avoid staging server when hostname is "default"
    pkgs-latest.slack
  ];
}
