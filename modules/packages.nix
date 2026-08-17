{
  pkgs,
  config,
  inputs,
  host,
  ...
}:
let
  hasNvidia = config.drivers.nvidia.enable || config.drivers.nvidia-prime.enable;
in
{

  services.power-profiles-daemon.enable = true;

  programs = {
    hyprland = {
      enable = true;
      withUWSM = false;
      #package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland; #hyprland-git
      #portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland; #xdph-git

      portalPackage = pkgs.xdg-desktop-portal-hyprland; # xdph none git
      xwayland.enable = true;
    };
    zsh.enable = true;
    firefox.enable = false;
    waybar.enable = false; # started by Hyprland dotfiles. Enabling causes two waybars
    hyprlock.enable = true;
    dconf.enable = true;
    seahorse.enable = true;
    fuse.userAllowOther = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    git.enable = true;
    tmux.enable = true;
    nm-applet.indicator = true;
    neovim = {
      enable = true;
      defaultEditor = false;
    };

    thunar.enable = true;
    thunar.plugins = with pkgs; [
      xfce4-exo
      mousepad
      thunar-archive-plugin
      thunar-volman
      tumbler
    ];
  };
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    alejandra
    onefetch
    atop
    go # needed for waybar-weather compile

    # Update flkake script
    (pkgs.writeShellScriptBin "update" ''
      cd ~/NixOS-Hyprland
      nh os switch -u -H ${host} .
    '')

    # Rebuild flkake script
    (pkgs.writeShellScriptBin "rebuild" ''
      cd ~/NixOS-Hyprland
      nh os switch -H ${host} .
    '')

    # Like rebuild, but stages the config for next boot instead of hot-switching.
    # Use this when the switch script warns about critical component changes
    # (e.g. dbus-implementation, systemd, kernel) to avoid breaking the live session.
    (pkgs.writeShellScriptBin "rebuild-boot" ''
      cd ~/NixOS-Hyprland
      nh os boot -H ${host} .
      echo ""
      echo "Config staged. Run 'reboot' when ready."
    '')

    # clean up old generations
    (writeShellScriptBin "ncg" ''
      nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot
    '')

    # Update only fast-moving packages (claude-code, neovim, zoom, vivaldi, slack)
    (writeShellScriptBin "update-latest" ''
      cd ~/NixOS-Hyprland
      echo "Updating fast-moving package inputs..."
      nix flake lock --update-input claude-code
      nix flake lock --update-input neovim-nightly
      nix flake lock --update-input nixpkgs-latest
      echo "Rebuilding with updated packages..."
      nh os switch -H ${host} .
    '')

    # Update only Claude Code
    (writeShellScriptBin "update-claude" ''
      cd ~/NixOS-Hyprland
      echo "Updating Claude Code..."
      nix flake lock --update-input claude-code
      nh os switch -H ${host} .
    '')

    # Update only Neovim
    (writeShellScriptBin "update-neovim" ''
      cd ~/NixOS-Hyprland
      echo "Updating Neovim..."
      nix flake lock --update-input neovim-nightly
      nh os switch -H ${host} .
    '')

    # Hyprland Stuff
    hypridle
    hyprpolkitagent
    pyprland
    #uwsm
    hyprlang
    hyprshot
    hyprcursor
    mesa
    nwg-displays
    nwg-look
    waypaper
    waybar
    waybar-weather
    hyprland-qt-support # for hyprland-qt-support

    #  Apps
    power-profiles-daemon
    loupe
    appimage-run
    bc
    brightnessctl
    (btop.override {
      cudaSupport = hasNvidia;
      rocmSupport = config.drivers.amdgpu.enable;
    })
    bottom
    baobab
    btrfs-progs
    cmatrix
    swaylock-plugin # Matrix-style lock screen with animated backgrounds
    distrobox
    dua
    duf
    cava
    # cargo removed from system closure (~2.4 GB). Add a devShell in
    # flake.nix (devShells.${system}.rust = pkgs.mkShell { packages = [ cargo rustc ... ]; })
    # or a local shell.nix, then use `nix develop .#rust` when you need Rust.
    clang
    cmake
    cliphist
    cpufrequtils
    curl
    dysk
    eog
    eza
    findutils
    figlet
    ffmpeg
    fd
    feh
    file-roller
    glib # for gsettings to work
    gsettings-qt
    git
    google-chrome
    gnome-system-monitor
    #fastfetch
    jq
    gcc
    git
    gnumake
    grim
    grimblast
    gtk-engine-murrine # for gtk themes
    inxi
    imagemagick
    killall
    kdePackages.qt6ct
    kdePackages.qtwayland
    kdePackages.qtstyleplugin-kvantum # kvantum
    lazydocker
    lazygit
    libappindicator
    libnotify
    libsForQt5.qtstyleplugin-kvantum # kvantum
    libsForQt5.qt5ct
    (mpv.override { scripts = [ mpvScripts.mpris ]; }) # with tray
    # nvtopPackages: full (NVIDIA+CUDA), amd, or intel — driven by drivers.* flags in host config
    (
      if hasNvidia then
        nvtopPackages.full
      else if config.drivers.amdgpu.enable then
        nvtopPackages.amd
      else
        nvtopPackages.intel
    )
    openssl # required by Rainbow borders
    pciutils
    networkmanagerapplet
    #nitrogen
    pamixer
    pavucontrol
    playerctl
    #polkit
    # polkit_gnome
    kdePackages.polkit-kde-agent-1
    # qt6ct
    #qt6.qtwayland
    #qt6Packages.qtstyleplugin-kvantum # kvantum
    # gsettings-qt
    rofi
    slurp
    swappy
    serie # git cli tool
    swaynotificationcenter
    awww
    unzip
    wallust
    wdisplays
    wl-clipboard
    wlr-randr
    wlogout
    wget
    xarchiver
    yad
    (yazi.override {
      _7zz = _7zz-rar; # Support for RAR extraction
    })
    xdg-user-dirs # needed for copy.sh
    yt-dlp

    (inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default)
    (inputs.ags.packages.${pkgs.stdenv.hostPlatform.system}.default)

    # Utils
    #browsr # file browser   # Fails python build 11/14/2025
    ctop # container top
    erdtree # great tree util run: erd
    frogmouth # cli markdown renderer A
    lstr # another tree util
    lolcat
    lsd # ls replacement util
    macchina # fetch tool
    mcat # show images in terminal
    mdcat # Markdown tool
    parallel-disk-usage # fast disk space tool run: pdu
    pik # Interactive process killer
    oh-my-posh
    ncdu # disk usage tool
    ncftp
    netop # network mon tool run: sudo netop
    ripgrep
    socat
    starship
    trippy # trace tool like mtr  run  sudo trip host/IP
    tldr
    tuptime # better uptime tool
    ugrep
    unrar
    v4l-utils
    # obs-studio  # Moved to Flatpak (com.obsproject.Studio) — ~4 GB closure
    zoxide

    # Hardware related
    atop # monitoring tool
    bandwhich # network monitor run with sudo
    caligula # burn ISOs at cli FAST
    cpufetch
    cpuid
    cpu-x
    cyme # list USB devices - very handy
    gdu # Dusk usage
    glances # system monitor tool
    gping # Graphical ping tool
    htop # system monitor tool
    hyfetch
    ipfetch
    pfetch
    smartmontools
    # light removed from nixpkgs, use brightnessctl or acpilight instead
    lm_sensors
    mission-center
    fastfetch

    # Development related
    luarocks
    nh

    # Internet
    discord

    # Virtuaizaiton
    virt-viewer
    libvirt

    # Video
    vlc

    # Terminals
    kitty
    wezterm
  ];
  environment.variables = {
    JAKOS_NIXOS_VERSION = "0.0.5";
    JAKOS = "true";
  };
}
