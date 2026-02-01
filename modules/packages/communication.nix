# Communication apps
# Zoom and Slack use pkgs-latest for independent updates
# Update with: nix flake lock --update-input nixpkgs-latest
{ pkgs, pkgs-latest, ... }: {
  environment.systemPackages = [
    # From main nixpkgs
    pkgs.signal-desktop
    pkgs.teams-for-linux
    # pkgs.discord  # Uncomment if needed

    # From nixpkgs-latest (can be updated independently)
    pkgs-latest.zoom-us
    pkgs-latest.slack
  ];
}
