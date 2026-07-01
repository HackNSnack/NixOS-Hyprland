# GUI code editors and IDEs
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vscode
    vim
    tree-sitter # CLI required by nvim-treesitter (main branch) to build parsers
  ];
}
