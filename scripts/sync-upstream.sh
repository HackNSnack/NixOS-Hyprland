#!/usr/bin/env bash
# Sync with upstream repository and handle conflicts
# Usage: ./scripts/sync-upstream.sh [--dry-run] [--claude]

set -e

# Colors
OK="$(tput setaf 2)[OK]$(tput sgr0)"
WARN="$(tput setaf 3)[WARN]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 4)[NOTE]$(tput sgr0)"
CYAN="$(tput setaf 6)"
RESET="$(tput sgr0)"

DRY_RUN=false
USE_CLAUDE=false

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --claude) USE_CLAUDE=true ;;
    esac
done

echo "$NOTE Fetching upstream changes..."
git fetch upstream

# Show what's new
UPSTREAM_COMMITS=$(git rev-list HEAD..upstream/main --count)
echo "$NOTE Upstream has $UPSTREAM_COMMITS new commits"

if [ "$UPSTREAM_COMMITS" -eq 0 ]; then
    echo "$OK Already up to date!"
    exit 0
fi

# Show summary of changes
echo ""
echo "$NOTE Upstream changes summary:"
git log HEAD..upstream/main --oneline | head -20
echo ""

# Show files that will be affected
echo "$NOTE Files changed in upstream:"
git diff --stat HEAD..upstream/main | tail -20
echo ""

if $DRY_RUN; then
    echo "$NOTE Dry run - checking for potential conflicts..."

    # Attempt merge without committing
    if git merge --no-commit --no-ff upstream/main 2>/dev/null; then
        echo "$OK No conflicts expected - merge would succeed"
        git merge --abort 2>/dev/null || true
    else
        echo "$WARN Potential conflicts detected in:"
        git diff --name-only --diff-filter=U 2>/dev/null || true
        git merge --abort 2>/dev/null || true
    fi
    exit 0
fi

echo "$NOTE Attempting merge..."
if git merge upstream/main -m "Merge upstream changes"; then
    echo "$OK Merge successful!"
    echo ""
    echo "$NOTE Next steps:"
    echo "  1. Run 'nix flake check' to verify configuration"
    echo "  2. Test with 'sudo nixos-rebuild dry-run --flake .#default'"
    echo "  3. Push with 'git push origin main'"
else
    CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
    echo ""
    echo "$WARN Merge has conflicts in the following files:"
    echo "$CONFLICT_FILES"
    echo ""

    if $USE_CLAUDE; then
        echo "$NOTE Launching Claude Code to help resolve conflicts..."
        echo ""

        # Build context for Claude
        CLAUDE_PROMPT="I need help resolving merge conflicts in my NixOS-Hyprland fork.

## Current Situation
I'm merging upstream changes from JaKooLit/NixOS-Hyprland into my personal fork.

## Files with conflicts:
$CONFLICT_FILES

## My Fork's Key Customizations (DO NOT LOSE THESE):
1. **Modular packages** in modules/packages/*.nix (upstream uses monolithic modules/packages.nix)
2. **Norwegian defaults**: keyboard 'no', timezone 'Europe/Oslo'
3. **Install mode selection** in install.sh (Full/System/Dotfiles/Custom)
4. **Personal repo URLs**: HackNSnack/Hyprland-Dots, HackNSnack/nvim2, HackNSnack/waybar_configs
5. **Additional flake inputs**: claude-code, neovim-nightly, nixpkgs-latest
6. **Extra modules**: nix-ld.nix, Docker config, custom /etc/hosts
7. **Shell setup**: oh-my-posh theme download, fzf-git.sh download

## Resolution Guidelines:
- Personal customizations ALWAYS take priority
- New upstream features should be integrated if they don't conflict
- If upstream adds packages to modules/packages.nix, add them to the appropriate modular file instead
- Keep the install mode selection and Norwegian defaults
- Accept upstream bug fixes and Hyprland/NixOS compatibility updates

Please read the CLAUDE.md file for full context, then help me resolve each conflict file.
Start by showing me the conflicts in each file and suggest resolutions."

        # Launch Claude Code with the prompt
        claude "$CLAUDE_PROMPT"
    else
        echo "$NOTE Options to resolve:"
        echo ""
        echo "  ${CYAN}1. Manual resolution:${RESET}"
        echo "     - Edit each file to resolve conflicts"
        echo "     - Look for <<<<<<< HEAD (your changes) and >>>>>>> upstream/main"
        echo "     - Then: git add . && git commit"
        echo ""
        echo "  ${CYAN}2. Use Claude Code:${RESET}"
        echo "     Run: ./scripts/sync-upstream.sh --claude"
        echo "     Or:  claude 'help me resolve merge conflicts in this repo'"
        echo ""
        echo "  ${CYAN}3. Abort merge:${RESET}"
        echo "     git merge --abort"
        echo ""
        echo "$NOTE Tip: Read CLAUDE.md for context on what customizations to preserve"
    fi
fi
