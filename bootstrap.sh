#!/bin/bash
# bootstrap.sh — bare metal macOS to fully configured dev machine
#
# Usage (from a fresh machine):
#   curl -fsSL https://raw.githubusercontent.com/azheng8/bootstrap/main/bootstrap.sh | bash
#
# What this does:
#   1. Installs Xcode CLT + Homebrew
#   2. Installs 1Password, gh, stow, just, git
#   3. Pauses for 1Password sign-in (manual)
#   4. Runs gh auth login (SSH key setup)
#   5. Clones dotfiles and runs bootstrap

set -e

echo "=== macOS Bootstrap ==="
echo ""

# --- Xcode Command Line Tools ---
if xcode-select -p &>/dev/null; then
    echo "[ok] Xcode CLT already installed"
else
    echo "[..] Installing Xcode CLT..."
    xcode-select --install
    echo ""
    echo "Complete the Xcode CLT installation prompt, then re-run this script."
    exit 0
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
    echo "[..] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "[ok] Homebrew already installed"
fi

# Ensure Homebrew is in PATH (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- Core packages ---
echo "[..] Installing core packages..."
brew install --cask 1password
brew install 1password-cli gh stow just git

# --- 1Password setup (manual) ---
echo ""
echo "================================================"
echo "  1Password setup required (manual)"
echo "================================================"
echo ""
echo "  1. Open 1Password and sign in to your account(s)"
echo "  2. Settings -> Developer -> enable 'Integrate with 1Password CLI'"
echo ""
read -p "  Press enter when done... "

# --- GitHub auth ---
echo ""
echo "[..] Setting up GitHub authentication..."
gh auth login

# --- Clone dotfiles ---
echo ""
if [[ -d "$HOME/dotfiles" ]]; then
    echo "[ok] ~/dotfiles already exists"
else
    echo "[..] Cloning dotfiles..."
    git clone git@github.com:azheng8/dotfiles.git ~/dotfiles
fi

# --- Clean up files that conflict with stow ---
echo "[..] Cleaning up pre-existing configs that conflict with stow..."
rm -f ~/.zshrc ~/.tmux.conf ~/.p10k.zsh ~/Brewfile
rm -rf ~/.config/nvim ~/.config/ghostty ~/.config/aerospace
rm -rf ~/.config/kitty ~/.config/karabiner ~/.config/git
rm -rf ~/.config/opencode

# --- Bootstrap dotfiles ---
echo "[..] Running dotfiles bootstrap..."
cd ~/dotfiles && just bootstrap

# --- Work setup prompt ---
echo ""
echo "================================================"
echo "  Bootstrap complete!"
echo "================================================"
echo ""
echo "  If this is a work machine, run:"
echo "    cd ~/dotfiles && just work"
echo ""
echo "  Restart your shell:"
echo "    exec zsh"
echo ""
