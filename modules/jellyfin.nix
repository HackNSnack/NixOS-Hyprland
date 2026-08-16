# nixos/jellyfin.nix — shared, parameterized Tier 1 module
#
# Usage in your flake (~/NixOS-Hyprland): import this file as a module on each
# host, then set the `jellyfin-media.accel` option per host.
#
# The module defines a custom option `jellyfin-media` so each host declares
# only what differs (accel + user + media dir), and the shared Jellyfin config
# is written once here.
#
# --- Example: desktop (RTX 4090, NVENC) ---
#   { ... }: {
#     imports = [ ./path/to/jellyfin.nix ];
#     jellyfin-media = {
#       user = "mathipe";
#       mediaDir = "/data/media";
#       accel.type = "nvenc";
#       accel.device = "/dev/dri/by-path/pci-0000:01:00.0-render";
#       cudaSupport = true;     # NVENC needs CUDA (larger closure)
#     };
#   }
#
# --- Example: laptop (Intel Iris Xe, VAAPI) ---
#   { ... }: {
#     imports = [ ./path/to/jellyfin.nix ];
#     jellyfin-media = {
#       user = "mathipe";
#       mediaDir = "/home/mathipe/media";
#       accel.type = "vaapi";
#       accel.device = "/dev/dri/renderD128";
#       intelMediaDriver = true;   # adds intel-media-driver + intel-compute-runtime
#     };
#   }
#
# --- Example: minimal test (no hardware accel, CPU transcode) ---
#   { ... }: {
#     imports = [ ./path/to/jellyfin.nix ];
#     jellyfin-media = {
#       user = "mathipe";
#       mediaDir = "/home/mathipe/media";
#       # accel omitted → no hardwareAcceleration block, CPU transcode only
#     };
#   }
#
# Discover device paths on the host with:
#   lspci | grep -iE 'vga|3d|nvidia|intel'
#   ls -l /dev/dri/by-path/ | grep render     # match PCI bus from lspci
{ config, lib, pkgs, ... }:
let
  cfg = config.jellyfin-media;
in
{
  # ---- custom option (per-host knobs) -------------------------------------
  options.jellyfin-media = {
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run Jellyfin as (so it can read the media dir without permission fights).";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the media directory (movies/tv subdirs).";
    };

    accel = {
      type = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "nvenc" "vaapi" "qsv" ]);
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
  config = {
    nixpkgs.config.cudaSupport = cfg.cudaSupport;

    hardware.graphics = lib.mkIf cfg.intelMediaDriver {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver      # Broadwell+ (ca. 2014+); set LIBVA_DRIVER_NAME=iHD
        intel-compute-runtime    # newer Intel iGPU OpenCL
        intel-ocl
      ];
    };

    # VAAPI wants this env var (iHD = newer Intel media driver)
    systemd.services.jellyfin.environment = lib.mkIf (cfg.accel.type == "vaapi") {
      LIBVA_DRIVER_NAME = "iHD";
    };

    services.jellyfin = {
      enable = true;
      openFirewall = true;                     # opens :8096 to LAN; WAN stays blocked
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