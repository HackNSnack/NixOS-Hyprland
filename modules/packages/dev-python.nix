# Python development environment
{ pkgs, ... }:
let
  python-packages = pkgs.python313.withPackages (
    ps: with ps; [
      # Web framework
      requests
      pyquery # needed for hyprland-dots Weather script
      python-dotenv
      fastapi
      uvicorn

      # Data science
      numpy
      pandas
      pyodbc

      # Parallel processing
      threadpoolctl
      joblib

      # Audio
      sounddevice
    ]
  );
in
{
  environment.systemPackages = [
    python-packages

    # Python tooling
    pkgs.uv      # Fast Python package installer
    pkgs.devenv  # Development environments
  ];
}
