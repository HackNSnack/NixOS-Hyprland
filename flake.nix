{
  description = "KooL's NixOS-Hyprland";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    #hyprland.url = "github:hyprwm/Hyprland"; # hyprland development
    alejandra.url = "github:kamadorueda/alejandra";

    # Always-latest package flakes
    # Update with: nix flake lock --update-input <input-name>
    claude-code.url = "github:sadjow/claude-code-nix"; # Hourly updates
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";

    # For packages without dedicated flakes (zoom, slack, vivaldi)
    # This can be updated independently of main nixpkgs
    nixpkgs-latest.url = "github:nixos/nixpkgs/nixos-unstable";

    ags = {
      type = "github";
      owner = "aylur";
      repo = "ags";
      ref = "v1";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs @ { self
    , nixpkgs
    , ags
    , alejandra
    , ...
    }:
    let
      system = "x86_64-linux";
      host = "default";
      username = "mathipe";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };

      # For packages without dedicated flakes (zoom, slack, vivaldi)
      pkgs-latest = import inputs.nixpkgs-latest {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };

      waybarWeatherPkg = pkgs.callPackage ./pkgs/waybar-weather.nix { };
    in
    {
      packages.${system} = {
        waybar-weather = waybarWeatherPkg;
      };
      nixosConfigurations = {
        "${host}" = nixpkgs.lib.nixosSystem rec {
          specialArgs = {
            inherit system;
            inherit inputs;
            inherit username;
            inherit host;
            inherit pkgs-latest;
          };
          modules = [
            ./hosts/${host}/config.nix
            # inputs.distro-grub-themes.nixosModules.${system}.default
            ./modules/overlays.nix # nixpkgs overlays (CMake policy fixes)
            ./modules/quickshell.nix # quickshell module
            ./modules/packages.nix # Software packages
            # Allow broken packages (temporary fix for broken CUDA in nixos-unstable)
            { nixpkgs.config.allowBroken = true; }
            ./modules/fonts.nix # Fonts packages
            ./modules/portals.nix # portal
            ./modules/theme.nix # Set dark theme
            ./modules/ly.nix # ly greater with matrix animation
            ./modules/nh.nix # nix helper
            inputs.catppuccin.nixosModules.catppuccin
            # Integrate Home Manager as a NixOS module
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-bak";

              home-manager.extraSpecialArgs = { inherit inputs system username host; };

              home-manager.users.${username} = {
                home.username = username;
                home.homeDirectory = "/home/${username}";
                home.stateVersion = "24.05";

                # Import your copied HM modules
                imports = [
                  ./modules/home/default.nix
                ];
              };
            }
          ];
        };
      };
      # Code formatter
      formatter.x86_64-linux = alejandra.defaultPackage.x86_64-linux;
    };
}
