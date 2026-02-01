# 💫 https://github.com/JaKooLit 💫 #

#!/usr/bin/env bash
clear

printf "\n%.0s" {1..2}
echo -e "\e[35m
	╦╔═┌─┐┌─┐╦    ╦ ╦┬ ┬┌─┐┬─┐┬  ┌─┐┌┐┌┌┬┐
	╠╩╗│ ││ │║    ╠═╣└┬┘├─┘├┬┘│  ├─┤│││ ││ 2025
	╩ ╩└─┘└─┘╩═╝  ╩ ╩ ┴ ┴  ┴└─┴─┘┴ ┴┘└┘─┴┘
\e[0m"
printf "\n%.0s" {1..1}

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

set -e

# Common installer functions
if [ -f "scripts/lib/install-common.sh" ]; then
    # shellcheck source=/dev/null
    . "scripts/lib/install-common.sh"
fi

if [ -n "$(grep -i nixos </etc/os-release)" ]; then
    echo "${OK} Verified this is NixOS."
    echo "-----"
else
    echo "$ERROR This is not NixOS or the distribution information is not available."
    exit 1
fi

if command -v git &>/dev/null; then
    echo "$OK Git is installed, continuing with installation."
    echo "-----"
else
    echo "$ERROR Git is not installed. Please install Git and try again."
    echo "Example: nix-shell -p git"
    exit 1
fi

# Check for pciutils (lspci)
if ! command -v lspci >/dev/null 2>&1; then
    echo "$ERROR pciutils is not installed. Please install pciutils and try again."
    echo "Example: nix-shell -p pciutils"
    exit 1
fi

# Check Go version (from nixpkgs or local) for waybar-weather
if type nhl_check_go_version >/dev/null 2>&1; then
    nhl_check_go_version
fi

echo "$NOTE Ensure In Home Directory"
cd || exit

echo "-----"

backupname=$(date "+%Y-%m-%d-%H-%M-%S")
if [ -d "NixOS-Hyprland" ]; then
    echo "$NOTE NixOS-Hyprland exists, backing up to NixOS-Hyprland-backups directory."
    if [ -d "NixOS-Hyprland-backups" ]; then
        echo "Moving current version of NixOS-Hyprland to backups directory."
        sudo mv "$HOME"/NixOS-Hyprland NixOS-Hyprland-backups/"$backupname"
        sleep 1
    else
        echo "$NOTE Creating the backups directory & moving NixOS-Hyprland to it."
        mkdir -p NixOS-Hyprland-backups
        sudo mv "$HOME"/NixOS-Hyprland NixOS-Hyprland-backups/"$backupname"
        sleep 1
    fi
else
    echo "$OK Thank you for choosing KooL's NixOS-Hyprland"
fi

echo "-----"

echo "$NOTE Cloning & Entering NixOS-Hyprland Repository"
git clone --depth 1 https://github.com/JaKooLit/NixOS-Hyprland.git ~/NixOS-Hyprland
cd ~/NixOS-Hyprland || exit

printf "\n%.0s" {1..2}

echo "-----"
printf "\n%.0s" {1..1}

# ============================================================
# INSTALLATION MODE SELECTION
# ============================================================
echo "$NOTE Select installation mode:"
echo ""
echo "  ${GREEN}1)${RESET} Full install      - NixOS rebuild + all dotfiles/themes"
echo "  ${GREEN}2)${RESET} System only       - NixOS rebuild only (no dotfiles/themes)"
echo "  ${GREEN}3)${RESET} Dotfiles only     - Dotfiles/themes only (no NixOS rebuild)"
echo "  ${GREEN}4)${RESET} Custom            - Choose individual components"
echo ""
read -rp "$CAT Select mode [1-4]: [ 1 ] " installMode </dev/tty
installMode=${installMode:-1}

# Initialize component flags (all enabled by default for full install)
DO_SYSTEM_CONFIG=true      # Hostname, GPU, keyboard, timezone, hardware config
DO_NIXOS_REBUILD=true      # nixos-rebuild switch
DO_ZSHRC=true              # Copy .zshrc
DO_GTK_THEMES=true         # GTK themes and icons
DO_CONFIG_DIRS=true        # gtk-3.0, Thunar, xfce4 configs
DO_HYPRLAND_DOTS=true      # Hyprland-Dots
DO_NEOVIM_CONFIG=true      # Neovim configuration
DO_WAYBAR_CONFIG=true      # Waybar configuration
DO_FASTFETCH=true          # Fastfetch config

case "$installMode" in
    1)
        # Full install - all flags already true
        echo "$OK Full install selected"
        ;;
    2)
        # System only
        DO_ZSHRC=false
        DO_GTK_THEMES=false
        DO_CONFIG_DIRS=false
        DO_HYPRLAND_DOTS=false
        DO_NEOVIM_CONFIG=false
        DO_WAYBAR_CONFIG=false
        DO_FASTFETCH=false
        echo "$OK System only selected - will rebuild NixOS without dotfiles/themes"
        ;;
    3)
        # Dotfiles only
        DO_SYSTEM_CONFIG=false
        DO_NIXOS_REBUILD=false
        echo "$OK Dotfiles only selected - will install dotfiles/themes without NixOS rebuild"
        ;;
    4)
        # Custom - prompt for each component
        echo ""
        echo "$NOTE Custom mode - select components to install:"
        echo "-----"

        read -rp "$CAT Configure system (hostname, GPU, keyboard, timezone)? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_SYSTEM_CONFIG=false

        read -rp "$CAT Run NixOS rebuild? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_NIXOS_REBUILD=false

        read -rp "$CAT Copy .zshrc? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_ZSHRC=false

        read -rp "$CAT Install GTK themes and icons? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_GTK_THEMES=false

        read -rp "$CAT Copy config directories (gtk-3.0, Thunar, xfce4)? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_CONFIG_DIRS=false

        read -rp "$CAT Install Hyprland-Dots? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_HYPRLAND_DOTS=false

        read -rp "$CAT Install Neovim configuration? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_NEOVIM_CONFIG=false

        read -rp "$CAT Install Waybar configuration? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_WAYBAR_CONFIG=false

        read -rp "$CAT Copy fastfetch config? [Y/n]: " _ans </dev/tty
        [[ "$_ans" =~ ^[Nn]$ ]] && DO_FASTFETCH=false

        echo ""
        echo "$OK Custom configuration set"
        ;;
    *)
        echo "$WARN Invalid selection, defaulting to full install"
        ;;
esac

echo "-----"
printf "\n%.0s" {1..1}

echo "$NOTE Default options are in brackets []"
echo "$NOTE Just press ${MAGENTA}ENTER${RESET} to select the default"
sleep 1

echo "-----"

# ============================================================
# SYSTEM CONFIGURATION (hostname, GPU, keyboard, timezone)
# ============================================================
if $DO_SYSTEM_CONFIG; then
    read -rp "$CAT Enter Your New Hostname: [ default ] " hostName </dev/tty
    if [ -z "$hostName" ]; then
        hostName="default"
    fi

    echo "-----"

    # Create directory for the new hostname, unless the default is selected
    if [ "$hostName" != "default" ]; then
        mkdir -p hosts/"$hostName"
        cp hosts/default/*.nix hosts/"$hostName"
    else
        echo "Default hostname selected, no extra hosts directory created."
    fi

    # GPU/VM detection and toggles (operate on selected host)
    if type nhl_detect_gpu_and_toggle >/dev/null 2>&1; then
        nhl_detect_gpu_and_toggle "$hostName"
    fi
    echo "-----"

    read -rp "$CAT Enter your keyboard layout: [ us ] " keyboardLayout </dev/tty
    if [ -z "$keyboardLayout" ]; then
        keyboardLayout="us"
    fi

    sed -i 's/keyboardLayout\s*=\s*"\([^"]*\)"/keyboardLayout = "'"$keyboardLayout"'"/' ./hosts/$hostName/variables.nix

    # Timezone and console keymap
    if type nhl_prompt_timezone_console >/dev/null 2>&1; then
        nhl_prompt_timezone_console "$hostName" "$keyboardLayout"
    fi

    echo "-----"

    installusername=$(echo $USER)
    sed -i 's/username\s*=\s*"\([^"]*\)"/username = "'"$installusername"'"/' ./flake.nix

    echo "$NOTE Generating The Hardware Configuration"
    attempts=0
    max_attempts=3
    hardware_file="./hosts/$hostName/hardware.nix"

    while [ $attempts -lt $max_attempts ]; do
        sudo nixos-generate-config --show-hardware-config >"$hardware_file" 2>/dev/null

        if [ -f "$hardware_file" ]; then
            echo "${OK} Hardware configuration successfully generated."
            break
        else
            echo "${WARN} Failed to generate hardware configuration. Attempt $(($attempts + 1)) of $max_attempts."
            attempts=$(($attempts + 1))

            # Exit if this was the last attempt
            if [ $attempts -eq $max_attempts ]; then
                echo "${ERROR} Unable to generate hardware configuration after $max_attempts attempts."
                exit 1
            fi
        fi
    done

    echo "-----"

    echo "$NOTE Setting Required Nix Settings Then Going To Install"
    git config --global user.name "installer"
    git config --global user.email "installer@gmail.com"
    git add .
    # Update host in flake.nix (first occurrence of host = "...")
    sed -i -E '0,/(^\s*host\s*=\s*")([^"]*)(";)/s//\1'"$hostName"'\3/' ./flake.nix
    # Verify
    echo "$OK Hostname updated in flake.nix:"
    grep -E "^[[:space:]]*host[[:space:]]*=" ./flake.nix | head -1 || true
else
    # Use default hostname when skipping system config
    hostName="default"
    echo "$NOTE Skipping system configuration, using hostname: $hostName"
fi

# ============================================================
# NIXOS REBUILD
# ============================================================
if $DO_NIXOS_REBUILD; then
    printf "\n%.0s" {1..2}

    echo "$NOTE Rebuilding NixOS..... so pls be patient.."
    echo "-----"
    echo "$CAT In the meantime, go grab a coffee and stretch your legs or at least do something!!..."
    echo "-----"
    echo "$ERROR YES!!! YOU read it right!!.. you staring too much at your monitor ha ha... joke :)......"
    printf "\n%.0s" {1..2}
    echo "-----"
    printf "\n%.0s" {1..1}

    # Set the Nix configuration for experimental features
    NIX_CONFIG="experimental-features = nix-command flakes"
    #sudo nix flake update
    sudo nixos-rebuild switch --flake ~/NixOS-Hyprland/#"${hostName}"

    echo "-----"
    printf "\n%.0s" {1..2}
else
    echo "$NOTE Skipping NixOS rebuild"
    echo "-----"
fi

# ============================================================
# ZSHRC
# ============================================================
if $DO_ZSHRC; then
    # for initial zsh
    # Check if ~/.zshrc and  exists, create a backup, and copy the new configuration
    if [ -f "$HOME/.zshrc" ]; then
        cp -b "$HOME/.zshrc" "$HOME/.zshrc-backup" || true
    fi

    # Copying the preconfigured zsh themes and profile
    cp -r 'assets/.zshrc' ~/
    echo "$OK Copied .zshrc"
else
    echo "$NOTE Skipping .zshrc"
fi

# ============================================================
# GTK THEMES AND ICONS
# ============================================================
if $DO_GTK_THEMES; then
    # GTK Themes and Icons installation
    printf "Installing GTK-Themes and Icons..\n"

    if [ -d "GTK-themes-icons" ]; then
        echo "$NOTE GTK themes and Icons directory exist..deleting..."
        rm -rf "GTK-themes-icons"
    fi

    echo "$NOTE Cloning GTK themes and Icons repository..."
    if git clone --depth 1 https://github.com/JaKooLit/GTK-themes-icons.git; then
        cd GTK-themes-icons
        chmod +x auto-extract.sh
        ./auto-extract.sh
        cd ..
        echo "$OK Extracted GTK Themes & Icons to ~/.icons & ~/.themes directories"
    else
        echo "$ERROR Download failed for GTK themes and Icons.."
    fi

    echo "-----"
    printf "\n%.0s" {1..2}

    # Clean up
    # GTK Themes and Icons
    if [ -d "GTK-themes-icons" ]; then
        echo "$NOTE GTK themes and Icons directory exist..deleting..."
        rm -rf "GTK-themes-icons"
    fi
else
    echo "$NOTE Skipping GTK themes and icons"
fi

# ============================================================
# CONFIG DIRECTORIES (gtk-3.0, Thunar, xfce4)
# ============================================================
if $DO_CONFIG_DIRS; then
    # Check for existing configs and copy if does not exist
    for DIR1 in gtk-3.0 Thunar xfce4; do
        DIRPATH=~/.config/$DIR1
        if [ -d "$DIRPATH" ]; then
            echo -e "${NOTE} Config for $DIR1 found, no need to copy."
        else
            echo -e "${NOTE} Config for $DIR1 not found, copying from assets."
            cp -r assets/$DIR1 ~/.config/ && echo "Copy $DIR1 completed!" || echo "Error: Failed to copy $DIR1 config files."
        fi
    done

    echo "-----"
    printf "\n%.0s" {1..3}
else
    echo "$NOTE Skipping config directories"
fi

echo "-----"
printf "\n%.0s" {1..3}

# ============================================================
# HYPRLAND-DOTS
# ============================================================
if $DO_HYPRLAND_DOTS; then
    # Cloning Hyprland-Dots repo to home directory
    # Using personal fork with customizations
    printf "$NOTE Downloading Hyprland-Dots to HOME directory..\n"
    if [ -d ~/Hyprland-Dots ]; then
        cd ~/Hyprland-Dots
        git stash
        git pull
        chmod +x copy.sh
        ./copy.sh
    else
        if git clone --depth 1 https://github.com/HackNSnack/Hyprland-Dots.git ~/Hyprland-Dots; then
            cd ~/Hyprland-Dots || exit 1
            chmod +x copy.sh
            ./copy.sh
        else
            echo -e "$ERROR Can't download Hyprland-Dots"
        fi
    fi

    #return to NixOS-Hyprland
    cd ~/NixOS-Hyprland

    echo "-----"
    printf "\n%.0s" {1..1}
else
    echo "$NOTE Skipping Hyprland-Dots"
fi

# ============================================================
# NEOVIM CONFIGURATION
# ============================================================
if $DO_NEOVIM_CONFIG; then
    # Neovim configuration
    printf "$NOTE Setting up Neovim configuration..\n"
    if [ -d ~/.config/nvim ]; then
        echo "$NOTE Neovim config exists, pulling latest changes..."
        cd ~/.config/nvim
        git stash 2>/dev/null || true
        git pull
        cd ~/NixOS-Hyprland
    else
        echo "$NOTE Cloning Neovim configuration..."
        if git clone --depth 1 https://github.com/YOUR_USERNAME/nvim-config.git ~/.config/nvim; then
            echo "$OK Neovim configuration installed successfully"
        else
            echo "$ERROR Failed to clone Neovim configuration"
        fi
    fi

    echo "-----"
    printf "\n%.0s" {1..1}
else
    echo "$NOTE Skipping Neovim configuration"
fi

# ============================================================
# WAYBAR CONFIGURATION
# ============================================================
if $DO_WAYBAR_CONFIG; then
    # Waybar configuration
    printf "$NOTE Setting up Waybar configuration..\n"
    if [ -d ~/.config/waybar ]; then
        echo "$NOTE Waybar config exists, pulling latest changes..."
        cd ~/.config/waybar
        git stash 2>/dev/null || true
        git pull
        cd ~/NixOS-Hyprland
    else
        echo "$NOTE Cloning Waybar configuration..."
        if git clone --depth 1 https://github.com/YOUR_USERNAME/waybar-config.git ~/.config/waybar; then
            echo "$OK Waybar configuration installed successfully"
        else
            echo "$ERROR Failed to clone Waybar configuration"
        fi
    fi

    echo "-----"
    printf "\n%.0s" {1..1}
else
    echo "$NOTE Skipping Waybar configuration"
fi

# ============================================================
# FASTFETCH CONFIG
# ============================================================
if $DO_FASTFETCH; then
    # copy fastfetch config if nixos.png is not present
    if [ ! -f "$HOME/.config/fastfetch/nixos.png" ]; then
        cp -r assets/fastfetch "$HOME/.config/"
        echo "$OK Copied fastfetch config"
    else
        echo "$NOTE Fastfetch config already exists"
    fi
else
    echo "$NOTE Skipping fastfetch config"
fi

# ============================================================
# COMPLETION
# ============================================================
printf "\n%.0s" {1..2}

# Only check for Hyprland if we did a system rebuild
if $DO_NIXOS_REBUILD; then
    if command -v Hyprland &>/dev/null; then
        printf "\n${OK} Yey! Installation Completed.${RESET}\n"
        sleep 2
        printf "\n${NOTE} You can start Hyprland by typing Hyprland (note the capital H!).${RESET}\n"
        printf "\n${NOTE} It is highly recommended to reboot your system.${RESET}\n\n"

        # Prompt user to reboot
        read -rp "${CAT} Would you like to reboot now? (y/n): ${RESET}" HYP

        if [[ "$HYP" =~ ^[Yy]$ ]]; then
            # If user confirms, reboot the system
            systemctl reboot
        else
            # Print a message if the user does not want to reboot
            echo "Reboot skipped."
        fi
    else
        # Print error message if Hyprland is not installed
        printf "\n${WARN} Hyprland failed to install. Please check Install-Logs...${RESET}\n\n"
        exit 1
    fi
else
    printf "\n${OK} Installation Completed.${RESET}\n"
    echo "$NOTE No system rebuild was performed."
fi
