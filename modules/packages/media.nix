# Media and audio applications
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # --no-zygote: NVIDIA+Wayland GPU process crashes ("GPU process isn't usable. Goodbye.");
    # disabling the zygote keeps the GPU process alive (GPU acceleration stays on)
    (symlinkJoin {
      name = "spotify";
      paths = [ spotify ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/spotify --add-flags "--no-zygote"
      '';
    })
    jamesdsp        # Audio DSP/equalizer
    pulseaudioFull  # Full PulseAudio tools
    # cavalier      # Audio visualizer (uncomment if needed)

    # Video playback
    mpv             # Media player
    mpvpaper        # Video wallpaper for Wayland (used for animated lock screen)
  ];
}
