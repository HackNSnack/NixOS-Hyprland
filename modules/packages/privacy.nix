# Privacy and security applications
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Proton suite
    proton-vpn
    proton-pass
    protonmail-desktop
    git-credential-manager
  ];
}
