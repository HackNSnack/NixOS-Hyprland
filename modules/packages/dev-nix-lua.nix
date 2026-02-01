# Nix and Lua language support
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Nix
    nil               # Nix language server
    nixfmt-rfc-style  # Nix formatter

    # Lua
    lua-language-server
    stylua            # Lua formatter

    # AI-assisted coding
    llm-ls            # LLM language server
  ];
}
