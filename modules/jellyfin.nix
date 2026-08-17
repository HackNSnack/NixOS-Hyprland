# nixos/jellyfin.nix — shared, parameterized Tier 1 module
#
# Import this file as a module on each host. The module carries sensible
# defaults for the common knobs (user, mediaDir, enable) and DERIVES the
# hardware accel knobs from the per-host GPU driver toggles (drivers.*.enable),
# which the installer sets per host — so no accel config lives in the host
# config.nix. A host can still override any jellyfin-media.* option explicitly.
#
# The installer (nhl_prompt_services in scripts/lib/install-common.sh) only
# inserts/removes `jellyfin-media.enable = true;` per host (opt-in). cudaSupport
# / NVENC wiring is deferred (nvidia → CPU transcode until you set
# accel.type = "nvenc" + cudaSupport = true manually).
#
# --- Override example (only if a host needs to differ from the derived defaults) ---
#   { ... }: {
#     jellyfin-media = {
#       enable = true;
#       accel.type = "nvenc";
#       accel.device = "/dev/dri/by-path/pci-0000:01:00.0-render";
#       cudaSupport = true;     # NVENC needs CUDA (larger closure)
#     };
#   }
#
# Discover device paths on the host with:
#   lspci | grep -iE 'vga|3d|nvidia|intel'
#   ls -l /dev/dri/by-path/ | grep render     # match PCI bus from lspci
{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.jellyfin-media;
in {
  # ---- custom option (per-host knobs) -------------------------------------
  options.jellyfin-media = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the Jellyfin media server on this host. Keep this off on hosts
        that shouldn't expose the service (e.g. to avoid two instances on the
        same LAN). The installer toggles this per host.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "${username}";
      description = "User to run Jellyfin as (so it can read the media dir without permission fights).";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${username}/Prosjekter/Personal/jellyfin-media-server/media";
      description = "Absolute path to the media directory (movies/tv subdirs).";
    };

    accel = {
      type = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["nvenc" "vaapi" "qsv"]);
        default = null;
        description = "Hardware transcode type. null = CPU-only (no hw accel).";
      };
      device = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Render device path, e.g. /dev/dri/by-path/pci-...-render or /dev/dri/renderD128.";
      };
    };

    cudaSupport = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nixpkgs.config.cudaSupport (required for NVENC; large build closure).";
    };

    intelMediaDriver = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Add Intel VAAPI media driver + compute runtime (for vaapi/qsv on Intel iGPU).";
    };
  };

  # ---- shared Jellyfin config ---------------------------------------------
  config = lib.mkIf cfg.enable {
    # Derive hardware accel from the per-host GPU driver toggles
    # (drivers.*.enable), which the installer sets per host (see
    # nhl_detect_gpu_and_toggle). A host can still override any of these by
    # setting jellyfin-media.accel.* explicitly.
    # NVENC + CUDA is deferred (nvidia → CPU transcode for now); set
    # accel.type = "nvenc" + cudaSupport = true manually when wiring it up.
    jellyfin-media.accel.type = lib.mkDefault (
      if config.drivers.nvidia.enable || config.drivers.nvidia-prime.enable then null
      else if config.drivers.intel.enable || config.drivers.amdgpu.enable then "vaapi"
      else null
    );
    jellyfin-media.accel.device = lib.mkDefault (
      if config.drivers.intel.enable || config.drivers.amdgpu.enable
      then "/dev/dri/renderD128"
      else null
    );
    jellyfin-media.intelMediaDriver = lib.mkDefault config.drivers.intel.enable;

    nixpkgs.config.cudaSupport = cfg.cudaSupport;

    hardware.graphics = lib.mkIf cfg.intelMediaDriver {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver # Broadwell+ (ca. 2014+); set LIBVA_DRIVER_NAME=iHD
        intel-compute-runtime # newer Intel iGPU OpenCL
        intel-ocl
      ];
    };

    # VAAPI wants this env var (iHD = newer Intel media driver)
    systemd.services.jellyfin.environment = lib.mkIf (cfg.accel.type == "vaapi") {
      LIBVA_DRIVER_NAME = "iHD";
    };

    services.jellyfin = {
      enable = true;
      openFirewall = true; # opens :8096 to LAN; WAN stays blocked
      user = cfg.user;

      hardwareAcceleration = lib.mkIf (cfg.accel.type != null) {
        enable = true;
        type = cfg.accel.type;
        device = cfg.accel.device;
      };
    };

    # Hint: the media dir must exist and be readable by `cfg.user`.
    # If you switch `user` after a prior install, fix ownership:
    #   sudo chown -R <user>:<user> /var/lib/jellyfin /var/cache/jellyfin
  };
}
