# Productivity and note-taking apps
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    obsidian        # Note-taking
    libqalculate    # Calculator library
    rofi-calc       # Rofi calculator plugin
  ];
}
