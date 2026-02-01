# AI assistant tools
# Claude Code uses dedicated flake input for hourly updates
# Update with: nix flake lock --update-input claude-code
{ pkgs, inputs, system, ... }: {
  environment.systemPackages = [
    # Claude Code - from dedicated flake (hourly updates)
    inputs.claude-code.packages.${system}.default

    # Gemini CLI
    pkgs.gemini-cli
  ];
}
