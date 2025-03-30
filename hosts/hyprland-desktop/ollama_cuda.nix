# 💫 https://github.com/JaKooLit 💫 #
# Packages and Fonts config including the "programs" options

{ pkgs, inputs, lib, ...}:
{
    environment.systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
      cudaPackages.cuda_cudart
    ];

    # Expose web-portal for Ollama at localhost:8080
    services.open-webui.enable = true;

    environment.sessionVariables = {
      CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
      LD_LIBRARY_PATH = lib.makeLibraryPath [
        "${pkgs.cudaPackages.cudatoolkit}"
        "${pkgs.cudaPackages.cudatoolkit}/lib64"
        pkgs.cudaPackages.cudnn
        pkgs.cudaPackages.cuda_cudart
        # pkgs.stdenv.cc.cc.lib
      ];
      CUDA_MODULE_LOADING = "LAZY";
    };

    services.ollama = {
      enable = true;
      acceleration = "cuda";
      environmentVariables = {
        CUDA_VISIBLE_DEVICES = "0";
        NVIDIA_VISIBLE_DEVICES = "all";
      };
    };
}
