# Miscellaneous packages
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    cloudflare-warp
    moon
    portaudio  # Required for audio development

    # CLI utilities
    gh         # GitHub CLI
    xclip      # X11 clipboard
    zip        # Compression
    xdg-utils  # xdg-open and desktop integration
  ];
}
