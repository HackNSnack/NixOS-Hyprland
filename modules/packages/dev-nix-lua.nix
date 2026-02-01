# Nix and Lua language support
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Nix
    nil               # Nix language server
    nixfmt            # Nix formatter (was nixfmt-rfc-style)

    # Lua
    lua-language-server
    stylua            # Lua formatter

    # AI-assisted coding
    llm-ls            # LLM language server
  ];
}
