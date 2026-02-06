# Media and audio applications
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    spotify
    jamesdsp        # Audio DSP/equalizer
    pulseaudioFull  # Full PulseAudio tools
    # cavalier      # Audio visualizer (uncomment if needed)

    # Video playback
    mpv             # Media player
    mpvpaper        # Video wallpaper for Wayland (used for animated lock screen)
  ];
}
