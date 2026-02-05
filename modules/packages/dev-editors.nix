# GUI code editors and IDEs
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vscode
    vim
  ];
}
