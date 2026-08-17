# 💫 https://github.com/JaKooLit 💫 #
# Main default config
{
  pkgs,
  host,
  username,
  options,
  ...
}: let
  inherit (import ./variables.nix) keyboardLayout;
in {
  imports = [
    ./hardware.nix
    ./users.nix
    ./packages-fonts.nix

    # Driver modules
    ../../modules/amd-drivers.nix
    ../../modules/nvidia-drivers.nix
    ../../modules/nvidia-prime-drivers.nix
    ../../modules/intel-drivers.nix
    ../../modules/vm-guest-services.nix
    ../../modules/local-hardware-clock.nix

    # Development environments (comment out what you don't need)
    ../../modules/packages/dev-python.nix
    ../../modules/packages/dev-clojure.nix
    ../../modules/packages/dev-dotnet.nix
    ../../modules/packages/dev-node.nix
    ../../modules/packages/dev-nix-lua.nix

    # Tools and services
    ../../modules/packages/cloud.nix
    ../../modules/packages/database.nix
    ../../modules/packages/communication.nix
    ../../modules/packages/ai-tools.nix
    ../../modules/packages/cuda.nix
    ../../modules/packages/security.nix
    ../../modules/packages/misc.nix
    ../../modules/packages/browsers.nix

    # Applications
    ../../modules/packages/keyboards.nix
    ../../modules/packages/media.nix
    ../../modules/packages/productivity.nix
    ../../modules/packages/privacy.nix
    ../../modules/packages/dev-editors.nix

    # System
    ../../modules/nix-ld.nix

    # Services
    ../../modules/services/nanoclaw.nix

    # Jellyfin media server (shared parameterized module; per-host settings below)
    ../../modules/jellyfin.nix

    # Ollama tailnet serving (opt-in via the module's ollama-net.enable; default off)
    ../../modules/services/ollama.nix
  ];

  # BOOT related stuff
  boot = {
    kernelPackages = pkgs.linuxPackages_zen; # zen Kernel
    #kernelPackages = pkgs.linuxPackages_latest; # Kernel

    kernelParams = [
      "systemd.mask=systemd-vconsole-setup.service"
      "systemd.mask=dev-tpmrm0.device" # this is to mask that stupid 1.5 mins systemd bug
      "nowatchdog"
      "modprobe.blacklist=sp5100_tco" # watchdog for AMD
      "modprobe.blacklist=iTCO_wdt" # watchdog for Intel
    ];

    # OBS Virtual Cam Support
    kernelModules = ["v4l2loopback"];
    extraModulePackages = [pkgs.linuxPackages_zen.v4l2loopback];

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [];
    };

    # Needed For Some Steam Games
    #kernel.sysctl = {
    #  "vm.max_map_count" = 2147483642;
    #};

    ## BOOT LOADERS: NOTE USE ONLY 1. either systemd or grub
    # Bootloader SystemD
    loader.systemd-boot.enable = true;

    loader.efi = {
      #efiSysMountPoint = "/efi"; #this is if you have separate /efi partition
      canTouchEfiVariables = true;
    };

    loader.timeout = 5;

    # Bootloader GRUB
    #loader.grub = {
    #enable = true;
    #  devices = [ "nodev" ];
    #  efiSupport = true;
    #  gfxmodeBios = "auto";
    #  memtest86.enable = true;
    #  extraGrubInstallArgs = [ "--bootloader-id=${host}" ];
    #  configurationName = "${host}";
    #	 };

    # Bootloader GRUB theme, configure below

    ## -end of BOOTLOADERS----- ##

    # Make /tmp a tmpfs
    tmp = {
      useTmpfs = false;
      tmpfsSize = "30%";
    };

    # Appimage Support
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };

    plymouth.enable = true;
  };

  # GRUB Bootloader theme. Of course you need to enable GRUB above.. duh! and also, enable it on flake.nix
  #distro-grub-themes = {
  #  enable = true;
  #  theme = "nixos";
  #};

  # Extra Module Options
  drivers = {
    amdgpu.enable = false;
    intel.enable = false;
    nvidia.enable = true;
    nvidia-prime = {
      enable = false;
      intelBusID = "";
      nvidiaBusID = "";
    };
  };
  vm.guest-services.enable = false;
  local.hardware-clock.enable = false;

  # Optional services — opt in per host. The enable flags default to false in
  # their modules (single source), so config.nix carries NO enable line when a
  # host is off — the module default applies. The installer inserts a
  # `services.X.enable = true;` / `jellyfin-media.enable = true;` override below
  # the anchor when you opt in (see nhl_prompt_services in
  # scripts/lib/install-common.sh). Jellyfin accel is derived in the module
  # from the per-host driver toggles (drivers.*.enable), so nothing else lives
  # here. This keeps one consolidated branch with per-host opt-in.
  # nhl:services-anchor
  services.tailscale = { enable = true; openFirewall = true; }; # nhl:tailscale-enable

  # networking
  networking = {
    networkmanager.enable = true;
    hostName = "${host}";
    timeServers = options.networking.timeServers.default ++ ["pool.ntp.org"];

    # Custom hosts entries for local development
    hosts = {
      "127.0.0.1" = [
        "ardoqbundlesproduction.localhost"
        "piedpiper.localhost"
        "dkellyltd.localhost"
      ];
      "10.0.3.180" = [
        "llm-gateway.hq.ardoq"
        "llm-gateway.hq.ardoq.dev"
      ];
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Oslo";
  services.automatic-timezoned.enable = false;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nb_NO.UTF-8";
    LC_IDENTIFICATION = "nb_NO.UTF-8";
    LC_MEASUREMENT = "nb_NO.UTF-8";
    LC_MONETARY = "nb_NO.UTF-8";
    LC_NAME = "nb_NO.UTF-8";
    LC_NUMERIC = "nb_NO.UTF-8";
    LC_PAPER = "nb_NO.UTF-8";
    LC_TELEPHONE = "nb_NO.UTF-8";
    LC_TIME = "nb_NO.UTF-8";
  };

  # Services to start
  services = {
    xserver = {
      enable = false;
      xkb = {
        layout = "${keyboardLayout}";
        variant = "";
      };
    };

    smartd = {
      enable = false;
      autodetect = true;
    };

    gvfs.enable = true;
    tumbler.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    #pulseaudio.enable = false; #unstable
    udev.enable = true;
    envfs.enable = true;
    dbus.enable = true;

    fstrim = {
      enable = true;
      interval = "weekly";
    };

    libinput.enable = true;

    rpcbind.enable = true;
    nfs.server.enable = true;

    openssh.enable = true;

    # Declarative Flatpak — nix-flatpak installs/removes these on every
    # nixos-rebuild switch, so the system is fully reproducible.
    # To add more apps: look up the App ID on https://flathub.org and add
    # another { appId = "..."; origin = "flathub"; } entry, then rebuild.
    flatpak = {
      enable = true;
      packages = [
        {
          appId = "com.bambulab.BambuStudio";
          origin = "flathub";
        }
        # Heavy GUI apps moved out of the Nix closure to shrink rebuilds.
        # Removed from modules/packages/*; revert there if you drop these.
        {
          appId = "org.freecad.FreeCAD";
          origin = "flathub";
        }
        {
          appId = "us.zoom.Zoom";
          origin = "flathub";
        }
        {
          appId = "com.obsproject.Studio";
          origin = "flathub";
        }
        {
          appId = "com.github.IsmaelMartinez.teams_for_linux";
          origin = "flathub";
        }
      ];
    };

    blueman.enable = true;

    #hardware.openrgb.enable = true;
    #hardware.openrgb.motherboard = "amd";

    fwupd.enable = true;

    upower.enable = true;

    gnome.gnome-keyring.enable = true;

    #printing = {
    #  enable = false;
    #  drivers = [
    # pkgs.hplipWithPlugin
    #  ];
    #};

    # Network discovery (mDNS)
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        workstation = true;
      };
    };

    nscd.enable = true;

    # Cloudflare WARP VPN
    cloudflare-warp.enable = true;

    #ipp-usb.enable = true;

    #syncthing = {
    #  enable = false;
    #  user = "${username}";
    #  dataDir = "/home/${username}";
    #  configDir = "/home/${username}/.config/syncthing";
    #};
  };

  systemd.services.flatpak-repo = {
    path = [pkgs.flatpak];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # zram
  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 30;
    swapDevices = 1;
    algorithm = "zstd";
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

  #hardware.sane = {
  #  enable = true;
  #  extraBackends = [ pkgs.sane-airscan ];
  #  disabledDefaultBackends = [ "escl" ];
  #};

  # Extra Logitech Support
  hardware = {
    logitech.wireless.enable = false;
    logitech.wireless.enableGraphical = false;
  };

  services.pulseaudio.enable = false; # stable branch

  # Bluetooth
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };
  };

  # Security / Polkit
  security = {
    rtkit.enable = true;
    polkit.enable = true;
    polkit.extraConfig = ''
       polkit.addRule(function(action, subject) {
         if (
           subject.isInGroup("users")
             && (
               action.id == "org.freedesktop.login1.reboot" ||
               action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
               action.id == "org.freedesktop.login1.power-off" ||
               action.id == "org.freedesktop.login1.power-off-multiple-sessions"
             )
           )
         {
           return polkit.Result.YES;
         }
      })
    '';
  };
  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };
  security.pam.services.swaylock-plugin = {
    text = ''
      auth include login
    '';
  };

  # Cachix, Optimization settings and garbage collection automation
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];

      # ── Build parallelism ───────────────────────────────────────────────────
      # Default "auto" = one job per CPU thread (12 on your i7-1355U).
      # Each heavy derivation (rustc, clang, dotnet, azure-cli...) can eat
      # 2-4 GB on its own, so 12 simultaneous jobs easily blows past 32 GB.
      # 4 jobs × 3 cores each = all 12 threads utilised, RAM stays sane.
      max-jobs = 4;
      cores = 3;
    };

    # ── Daemon scheduling ───────────────────────────────────────────────────
    # `nice nix build` has zero effect in multi-user mode — the daemon runs
    # as root in a separate process tree. These are the real knobs.
    # "idle" = builds only consume CPU/IO when nothing else wants it,
    # so the desktop stays completely responsive during a rebuild.
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";

    # ── Store optimisation ──────────────────────────────────────────────────
    # auto-optimise-store = true (old setting) runs a hardlink-dedup scan
    # after *every single derivation build* — very slow on an 85 GB store.
    # The scheduled job below does the exact same thing once a week instead.
    optimise = {
      automatic = true;
      dates = ["weekly"];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ── Disk swap safety net ────────────────────────────────────────────────
  # zram (your current setup) compresses pages *back into RAM* — it helps
  # under normal pressure but provides zero extra headroom when RAM is truly
  # exhausted and the OOM killer starts firing. 8 GB on disk is cheap
  # insurance that's only ever touched in worst-case scenarios.
  # hardware.nix has swapDevices = [] which NixOS merges with this, no conflict.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024; # MiB → 8 GB
    }
  ];

  # Virtualization / Containers
  virtualisation.libvirtd.enable = false;
  virtualisation.docker.enable = true;
  virtualisation.podman = {
    enable = false;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = false;
  };

  # OpenGL
  hardware.graphics = {
    enable = true;
  };

  console.keyMap = "no";

  # For Electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # For Hyprland QT Support
  environment.sessionVariables.QML_IMPORT_PATH = "${pkgs.hyprland-qt-support}/lib/qt-6/qml";

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [80];
    allowedUDPPorts = [80];
    # Allow traffic on bridge interfaces (Docker, VMs)
    # Note: "br+" only matches Docker's custom-network bridges (br-<hash>);
    # the default Docker bridge is always named "docker0" and needs its own rule.
    extraCommands = ''
      iptables -I nixos-fw 1 -i br+ -j ACCEPT
      iptables -I nixos-fw 1 -i docker0 -j ACCEPT
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -i br+ -j ACCEPT || true
      iptables -D nixos-fw -i docker0 -j ACCEPT || true
    '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
