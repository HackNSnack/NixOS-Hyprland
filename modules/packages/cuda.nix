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

  # NOTE: deliberately NOT setting nixpkgs.config.cudaSupport = true here.
  # cudaPackages.* above are a separate package set and are unaffected by
  # that flag either way. Setting it globally flips `enableCuda ? config.cudaSupport`
  # on for every package with an optional CUDA branch (notably opencv4, which
  # frei0r-plugins -> jellyfin-ffmpeg and pillow-heif -> imageio -> waypaper
  # both pull in transitively). CUDA-enabled opencv is never present on
  # cache.nixos.org, so it silently forces a full from-source OpenCV+CUDA
  # rebuild on every closure change. Packages that actually want a CUDA
  # build locally (nvtopPackages.full, btop.override { cudaSupport = ...; })
  # already opt in explicitly in packages.nix - that stays intact.
}
