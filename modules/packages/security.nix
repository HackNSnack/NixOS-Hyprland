# Security tools
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    clamav
  ];

  programs.wireshark.enable = true;

  # ClamAV antivirus service
  services.clamav = {
    daemon.enable = true;
    updater.enable = true;
  };
}
