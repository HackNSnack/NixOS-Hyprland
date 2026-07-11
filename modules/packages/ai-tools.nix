# AI assistant tools
# Claude Code uses dedicated flake input for hourly updates
# Update with: nix flake lock --update-input claude-code
{
  pkgs,
  inputs,
  system,
  lib,
  ...
}: let
  # OneCLI CLI — credential vault management tool for the OneCLI HTTPS proxy gateway.
  # The gateway itself (Docker Compose stack) is installed once via:
  #   curl -fsSL onecli.sh/install | sh
  # This derivation packages the `onecli` management binary declaratively.
  # To update: nix-prefetch-url the new release tarball and replace the hash.
  onecli-cli = pkgs.stdenv.mkDerivation rec {
    pname = "onecli-cli";
    version = "1.3.0";
    src = pkgs.fetchurl {
      url = "https://github.com/onecli/onecli-cli/releases/download/v${version}/onecli_${version}_linux_amd64.tar.gz";
      hash = "sha256-2AQoWi7JCuneQw69XuWgfHDPMTqf2XveXxEgQfPeDmw=";
    };
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 onecli $out/bin/onecli
      runHook postInstall
    '';
    meta = with lib; {
      description = "OneCLI credential vault CLI for AI agent containers";
      homepage = "https://onecli.sh";
      license = licenses.unfree;
      mainProgram = "onecli";
      platforms = ["x86_64-linux"];
    };
  };
in {
  environment.systemPackages = [
    # Claude Code - from dedicated flake (hourly updates)
    inputs.claude-code.packages.${system}.default

    # Gemini CLI
    pkgs.gemini-cli

    # Ollama for local LLMs - from overlay (latest binary, CPU-only safe)
    pkgs.ollama

    # OneCLI CLI - HTTPS credential proxy management (see nanoclaw setup)
    onecli-cli
  ];
}
