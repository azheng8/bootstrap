#!/bin/bash
# bootstrap.sh — bare metal macOS to fully configured Nix-darwin dev machine
#
# Usage (from a fresh machine):
#   curl -fsSL https://raw.githubusercontent.com/azheng8/bootstrap/main/bootstrap.sh | bash
#
# What this does:
#   1. Installs Xcode CLT + Homebrew
#   2. Installs 1Password, gh, just, git
#   3. Pauses for 1Password sign-in (manual)
#   4. Runs gh auth login (SSH key setup)
#   5. Installs Determinate Nix
#   6. Clones dotfiles and runs nix-darwin bootstrap

set -e

echo "=== macOS Nix Bootstrap ==="
echo ""

# --- Select Profile ---
echo "Select the Nix-darwin profile to bootstrap:"
echo "1) MacBook (Work + Base)"
echo "2) MacBook (Personal Base)"
echo "3) Mac Mini (Work + Base)"
echo "4) Mac Mini (Personal Base)"
read -p "Enter choice [1-4]: " PROFILE_CHOICE
echo ""

case $PROFILE_CHOICE in
    1) PROFILE="macbook" ;;
    2) PROFILE="macbook-personal" ;;
    3) PROFILE="macmini" ;;
    4) PROFILE="personal" ;; # 'personal' corresponds to nix-bootstrap-personal
    *) echo "Invalid choice, defaulting to macbook-personal"; PROFILE="macbook-personal" ;;
esac

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
echo "[..] Installing bootstrap packages..."
brew install --cask 1password
brew install 1password-cli gh just git

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
if gh auth status &>/dev/null; then
    echo "[ok] GitHub CLI already authenticated"
else
    echo "[..] Setting up GitHub authentication..."
    gh auth login
fi

# --- Nix installation ---
echo ""
if ! command -v nix &>/dev/null; then
    echo "[..] Installing Nix via Determinate Systems installer..."
    curl -fsSL https://install.determinate.systems | sh -s -- install --no-confirm
    
    # Source the Nix daemon script immediately so we can use Nix in the rest of this session
    if [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    fi
else
    echo "[ok] Nix is already installed"
fi

# --- Clone dotfiles ---
echo ""
DOTFILES="$HOME/code/azheng8/dotfiles"
mkdir -p "$HOME/code/azheng8"
if [[ -d "$DOTFILES" ]]; then
    echo "[ok] $DOTFILES already exists, pulling latest..."
    git -C "$DOTFILES" pull
else
    echo "[..] Cloning dotfiles (az/migrate-to-nix branch)..."
    git clone -b az/migrate-to-nix git@github.com:azheng8/dotfiles.git "$DOTFILES"
fi

# --- Back up files that conflict with Home Manager ---
echo ""
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
for f in ~/.zshrc ~/.tmux.conf ~/.p10k.zsh ~/Brewfile; do
    [[ -e "$f" || -L "$f" ]] && mv "$f" "$BACKUP_DIR/" && echo "Backed up $f"
done
for d in ~/.config/nvim ~/.config/ghostty ~/.config/aerospace ~/.config/kitty ~/.config/karabiner ~/.config/git ~/.config/gh ~/.config/opencode; do
    [[ -e "$d" || -L "$d" ]] && mv "$d" "$BACKUP_DIR/" && echo "Backed up $d"
done
echo "[ok] Conflicting configs backed up to $BACKUP_DIR"

# --- Run Nix Bootstrap ---
echo ""
echo "[..] Setting up Oh-My-Zsh & Custom Plugins..."
cd "$DOTFILES" && just setup-omz

echo ""
echo "[..] Running Nix-darwin bootstrap with profile: $PROFILE..."
if [[ "$PROFILE" == "personal" ]]; then
    just nix-bootstrap-personal
else
    just nix-bootstrap-$PROFILE
fi

# --- Import secrets and cryptographic keys ---
echo ""
echo "[..] Restoring secrets & cryptographic keys..."
just secrets

echo ""
echo "================================================"
echo "  Nix Bootstrap Complete!"
echo "================================================"
echo ""
echo "  Restart your shell to activate your new environment:"
echo "    exec zsh"
echo ""
