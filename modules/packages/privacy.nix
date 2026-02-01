# Privacy and security applications
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Proton suite
    protonvpn-gui
    proton-pass
    protonmail-desktop
  ];
}
