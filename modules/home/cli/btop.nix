# osConfig is the NixOS config — available because home-manager runs as a NixOS module
{ pkgs, osConfig, ... }:
let
  hasNvidia = osConfig.drivers.nvidia.enable || osConfig.drivers.nvidia-prime.enable;
in
{
  programs.btop = {
    enable = true;
    package = pkgs.btop.override {
      cudaSupport = hasNvidia;
      rocmSupport = osConfig.drivers.amdgpu.enable;
    };
    settings = {
      vim_keys = true;
      rounded_corners = true;
      proc_tree = true;
      show_gpu_info = "on";
      show_uptime = true;
      show_coretemp = true;
      cpu_sensor = "auto";
      show_disks = true;
      only_physical = true;
      io_mode = true;
      io_graph_combined = false;
    };
  };
}
