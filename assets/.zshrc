# Load system zsh config (NixOS oh-my-zsh initialization)
[ -f /etc/zshrc ] && source /etc/zshrc

# ============================================================
# OH-MY-POSH
# ============================================================
export POSH="$HOME/.oh-my-posh"
eval "$(oh-my-posh init zsh --config ~/jandedobbeleer.omp.json)"

# ============================================================
# PLUGINS (if using oh-my-zsh)
# ============================================================
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# ============================================================
# HISTORY
# ============================================================
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
HISTCONTROL=ignoreboth
setopt appendhistory

# ============================================================
# FZF CONFIGURATION
# ============================================================

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# FZF Theme Colors
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# Use fd instead of find for fzf
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd for listing path candidates
_fzf_compgen_path() {
    fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
    fd --type=d --hidden --exclude .git . "$1"
}

# FZF git integration (requires fzf-git.sh in home directory)
[ -f ~/fzf-git.sh ] && source ~/fzf-git.sh

# Preview configuration
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
_fzf_comprun() {
    local command=$1
    shift

    case "$command" in
    cd) fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export | unset) fzf --preview "eval 'echo \${}'" "$@" ;;
    ssh) fzf --preview 'dig {}' "$@" ;;
    *) fzf --preview "$show_file_or_dir_preview" "$@" ;;
    esac
}

# ============================================================
# BAT (better cat)
# ============================================================
export BAT_THEME=tokyonight_night

# ============================================================
# EZA (better ls)
# ============================================================
alias ls="eza --icons=always --color=always --long --git --no-filesize --no-time --no-user --no-permissions"

# ============================================================
# NIXOS ALIASES
# ============================================================
alias nix_list_gen="sudo nix-env --list-generations -p /nix/var/nix/profiles/system"
alias nix_del_old="sudo nix-env --delete-generations -p /nix/var/nix/profiles/system"

# ============================================================
# STARTUP
# ============================================================
# Display system info on terminal launch
fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc
