# CUDA runtime libraries for ML development
# Provides libs via nix-ld so pip-installed PyTorch/TensorFlow can find CUDA at runtime
# Does NOT install ML frameworks - install those per-project with pip/uv
{ pkgs, ... }:
{
  # CUDA libraries available to nix-ld (for pip wheels that expect CUDA)
  programs.nix-ld.libraries = with pkgs; [
    cudaPackages.cuda_cudart      # CUDA runtime (libcudart.so)
    cudaPackages.cuda_nvrtc       # Runtime compilation (used by PyTorch JIT)
    cudaPackages.libcublas        # Matrix math (libcublas.so)
    cudaPackages.libcufft         # FFT operations
    cudaPackages.libcurand        # Random number generation
    cudaPackages.libcusparse      # Sparse matrix operations
    cudaPackages.libcusolver      # Dense/sparse solvers
    cudaPackages.cudnn            # Deep learning primitives (libcudnn.so)
    cudaPackages.nccl             # Multi-GPU communication
  ];

  # Make NVIDIA driver libs (libcuda.so) and CUDA runtime visible to all apps
  environment.sessionVariables = {
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
  };

  # Allow unfree CUDA packages
  nixpkgs.config.cudaSupport = true;
}
