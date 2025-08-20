{
  pkgs,
  username,
  lib,
  ...
}:

let
  inherit (import ./variables.nix) gitUsername;
in
{
  users = {
    mutableUsers = true;
    users."${username}" = {
      homeMode = "755";
      isNormalUser = true;
      description = "${gitUsername}";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "scanner"
        "lp"
        "video"
        "input"
        "audio"
        "docker"
      ];

      # define user packages here
      packages = with pkgs; [

        # Terminal
        zsh
        oh-my-posh
        fzf
        fd
        bat
        eza
        ripgrep

        # Browser
        vivaldi

        # Proton
        protonvpn-gui
        proton-pass
        protonmail-desktop

        # Notes
        obsidian

        # Microsoft
        whatsapp-for-linux
        teams-for-linux
        azuredatastudio

        # Sound / Music
        pulseaudioFull
        spotify
        jamesdsp
        #cavalier

        # Keyboard
        vial # QMK Firmware (Keyboard)
        via

        # Dev
        vscode
        nodejs
        gh

        # Div
        slack
        xclip

        # Calculator
        libqalculate
        rofi-calc
      ];

    };

    defaultUserShell = pkgs.zsh;
  };

  environment.shells = with pkgs; [ zsh ];
  environment.systemPackages = with pkgs; [
    lsd
    fzf
  ];

  programs = {
    # Zsh configuration
    # NB: This probably doesn't matter since I copy my own .zshrc
    zsh = {
      enable = true;
      enableCompletion = true;

      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

    };
  };
}
