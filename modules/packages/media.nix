# Media and audio applications
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    spotify
    jamesdsp        # Audio DSP/equalizer
    pulseaudioFull  # Full PulseAudio tools
    # cavalier      # Audio visualizer (uncomment if needed)
  ];
}
