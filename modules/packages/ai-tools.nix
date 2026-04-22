# AI assistant tools
# Claude Code uses overlay from dedicated flake for hourly updates
# Update with: nix flake lock --update-input claude-code
# Quick reinstall without full rebuild: nix profile install github:sadjow/claude-code-nix
# Ollama uses overlay with latest binary release (modules/overlays.nix)
# Update: bump version + hash in modules/overlays.nix
{
  pkgs,
  lib,
  ...
}:
let
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
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
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
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [
    # Claude Code - from overlay (inputs.claude-code.overlays.default in overlays.nix)
    pkgs.claude-code

    # Gemini CLI
    pkgs.gemini-cli

    # OneCLI CLI - HTTPS credential proxy management (see nanoclaw setup)
    onecli-cli

    # Ollama for local LLMs - from overlay (latest binary with bundled CUDA)
    pkgs.ollama
  ];
}
