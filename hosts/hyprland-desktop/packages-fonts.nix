# 💫 https://github.com/JaKooLit 💫 #
# Packages for this host only

{ pkgs, inputs, ... }:
let

  python-packages = pkgs.python313.withPackages (
    ps: with ps; [
      requests
      pyquery # needed for hyprland-dots Weather script
      pyodbc
      numpy
      pandas
      #opencv-python
      python-dotenv
      fastapi
      uvicorn
      threadpoolctl
      joblib
      sounddevice
    ]
  );

in
{

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnsupportedSystem = false;

  environment.systemPackages =
    (with pkgs; [
      # Antivirus
      clamav
      # System Packages
      bc
      baobab
      btrfs-progs
      clang
      curl
      cpufrequtils
      duf
      findutils
      ffmpeg
      glib # for gsettings to work
      gsettings-qt
      git
      killall
      libappindicator
      libnotify
      #xfce.xfce4-notifyd
      openssl # required by Rainbow borders
      pciutils
      vim
      wget
      xdg-user-dirs
      xdg-utils
      gnumake
      #go
      inputs.fix-python.packages.${pkgs.system}.default
      #fix-python
      xorg.libSM
      xorg.libXext
      libuuid
      mysql84
      llm-ls
      stylua
      lua-language-server
      nil
      nixfmt-rfc-style
      # unixODBC
      # unixODBCDrivers.psql
      # #unixODBCDrivers.mysql
      # unixODBCDrivers.sqlite
      # unixODBCDrivers.msodbcsql18
      portaudio
      devenv
      signal-desktop
      moon
      uv
      leiningen
      pnpm
      clojure
      clojure-lsp
      babashka
      jdk21_headless
      redis
      redisinsight
      zoom-us
      claude-code
      (yazi.override {
        _7zz = _7zz-rar; # Support for RAR extraction
      })
      cloudflare-warp
      gemini-cli
      google-cloud-sdk

      fastfetch
      (mpv.override { scripts = [ mpvScripts.mpris ]; }) # with tray
      #ranger

      # Dotnet
      csharpier
      (
        with dotnetCorePackages;
        combinePackages [
          dotnet_9.sdk
          dotnet_9.runtime
          dotnet_9.aspnetcore
        ]
      )
      csharp-ls
      netcoredbg

      fastfetch
      (mpv.override { scripts = [ mpvScripts.mpris ]; }) # with tray
      (azure-cli.withExtensions [
        azure-cli.extensions.aks-preview
        azure-cli.extensions.webapp
        azure-cli.extensions.redisenterprise
      ])
      #ranger

      # Hyprland Stuff
      ags # desktop overview
      hyprland-qt-support # for hyprland-qt-support
            #btop
      brightnessctl # for brightness control
      cava
      cliphist
      loupe
      gnome-system-monitor
      grim
      gtk-engine-murrine # for gtk themes
      hypridle
      imagemagick
      inxi
      jq
      cavalier
      kitty
      libsForQt5.qtstyleplugin-kvantum # kvantum
      networkmanagerapplet
      nwg-displays
      nwg-look
      #nvtopPackages.full
      pamixer
      pavucontrol
      playerctl
      polkit_gnome
      libsForQt5.qt5ct
      kdePackages.qt6ct
      kdePackages.qtwayland
      kdePackages.qtstyleplugin-kvantum # kvantum
      rofi
      slurp
      swappy
      swaynotificationcenter
      swww
      unzip
      wallust
      wl-clipboard
      wlogout
      xarchiver
      yad
      yt-dlp

    ])
    ++ [
      python-packages
    ];

  #FONTS
  fonts = {
    packages = with pkgs; [
      noto-fonts
      fira-code
      noto-fonts-cjk-sans
      jetbrains-mono
      font-awesome
      terminus_font
      victor-mono

      nerd-fonts.jetbrains-mono # unstable
      nerd-fonts.fira-code # unstable
      nerd-fonts.fantasque-sans-mono # unstable
    ];

  };

  programs = {

    wireshark = {
      enable = true;
    };

    virt-manager.enable = false;

    #steam = {
    #  enable = true;
    #  gamescopeSession.enable = true;
    #  remotePlay.openFirewall = true;
    #  dedicatedServer.openFirewall = true;
    #};
  };

  programs = {

    steam = {
      enable = false;
      gamescopeSession.enable = false;
      remotePlay.openFirewall = false;
      dedicatedServer.openFirewall = false;
    };

  };
}
