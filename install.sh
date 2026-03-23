#!/bin/bash

# mac-dotfiles installer
# Catppuccin Macchiato Peach rice: AeroSpace + SketchyBar + JankyBorders

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

ask() {
    printf "\n\033[1;38;2;245;169;127m▸ %s\033[0m [y/N] " "$1"
    read -r answer
    [ "$answer" = "y" ] || [ "$answer" = "Y" ]
}

info() {
    printf "\033[1;38;2;138;173;244m  %s\033[0m\n" "$1"
}

success() {
    printf "\033[1;38;2;166;218;149m  ✓ %s\033[0m\n" "$1"
}

# ─── Homebrew ───
if ! command -v brew &>/dev/null; then
    if ask "Homebrew not found. Install it?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        success "Homebrew installed"
    else
        echo "Homebrew is required. Exiting."
        exit 1
    fi
else
    success "Homebrew already installed"
fi

# ─── Packages ───
if ask "Install packages? (aerospace, sketchybar, borders, lutgen, nowplaying-cli, fonts)"; then
    info "Tapping FelixKratz/formulae..."
    brew tap FelixKratz/formulae

    info "Installing borders and sketchybar..."
    brew install borders sketchybar

    info "Installing AeroSpace..."
    brew install --cask nikitabobko/tap/aerospace

    info "Installing lutgen and nowplaying-cli..."
    brew install lutgen nowplaying-cli

    info "Installing SF Symbols (may require password)..."
    brew install --cask sf-symbols

    info "Installing JetBrains Mono Nerd Font..."
    brew install --cask font-jetbrains-mono-nerd-font

    success "All packages installed"
fi

# ─── Symlinks ───
link() {
    local src="$1"
    local dest="$2"
    local dest_dir="$(dirname "$dest")"

    mkdir -p "$dest_dir"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.backup"
        info "Backed up existing $dest to ${dest}.backup"
    fi

    ln -sf "$src" "$dest"
    success "Linked $dest"
}

if ask "Symlink config files?"; then
    link "$DOTFILES_DIR/aerospace/.aerospace.toml" "$HOME/.aerospace.toml"
    link "$DOTFILES_DIR/borders/.bordersrc" "$HOME/.bordersrc"
    link "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    link "$DOTFILES_DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    link "$DOTFILES_DIR/sketchybar/sketchybarrc" "$HOME/.config/sketchybar/sketchybarrc"
    link "$DOTFILES_DIR/sketchybar/colors.sh" "$HOME/.config/sketchybar/colors.sh"

    mkdir -p "$HOME/.config/sketchybar/plugins"
    for plugin in "$DOTFILES_DIR/sketchybar/plugins/"*.sh; do
        link "$plugin" "$HOME/.config/sketchybar/plugins/$(basename "$plugin")"
    done

    mkdir -p "$HOME/.local/bin"
    link "$DOTFILES_DIR/bin/catppuccinify" "$HOME/.local/bin/catppuccinify"

    success "All configs linked"
fi

# ─── Shell config ───
if ask "Add EDITOR and PATH to ~/.zshrc?"; then
    if ! grep -q 'export EDITOR="fresh"' "$HOME/.zshrc" 2>/dev/null; then
        echo '' >> "$HOME/.zshrc"
        echo 'export EDITOR="fresh"' >> "$HOME/.zshrc"
        success "Added EDITOR=fresh to .zshrc"
    else
        info "EDITOR already set in .zshrc"
    fi

    if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        success "Added ~/.local/bin to PATH in .zshrc"
    else
        info "~/.local/bin already in PATH"
    fi
fi

# ─── Start services ───
if ask "Start services? (borders, sketchybar, aerospace)"; then
    brew services start borders
    success "Borders started"

    brew services start sketchybar
    success "SketchyBar started"

    info "Opening AeroSpace (grant Accessibility permissions when prompted)..."
    open -a AeroSpace
    success "AeroSpace launched"
fi

# ─── Menu bar ───
printf "\n\033[1;38;2;245;169;127m▸ Remember to hide your menu bar in System Settings > Control Center\033[0m\n"

printf "\n\033[1;38;2;166;218;149m  ✓ All done! Enjoy your rice 🍚\033[0m\n\n"
