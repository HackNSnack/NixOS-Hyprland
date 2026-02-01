# Node.js / TypeScript development environment
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    nodejs
    pnpm
    prettierd   # Prettier daemon for faster formatting
    # yarn      # Uncomment if you prefer Yarn
  ];
}
