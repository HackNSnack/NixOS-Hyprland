# Web browsers
# Vivaldi uses pkgs-latest for independent updates
# Update with: nix flake lock --update-input nixpkgs-latest
{ pkgs, pkgs-latest, ... }: {
  environment.systemPackages = [
    # From nixpkgs-latest (can be updated independently)
    pkgs-latest.vivaldi
    pkgs-latest.vivaldi-ffmpeg-codecs  # For video playback support
  ];
}
