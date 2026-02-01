# Host-specific packages
# Most packages are now in modules/packages/*.nix
# This file is for packages unique to this host only
{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # Add any host-specific packages here
  ];

  programs = {
    steam = {
      enable = false;
      gamescopeSession.enable = false;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };
  };
}
