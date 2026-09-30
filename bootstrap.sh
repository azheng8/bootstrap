#!/bin/bash
# bootstrap.sh — bare metal macOS to fully configured Nix-darwin dev machine
#
# Usage (from a fresh machine):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/azheng8/bootstrap/main/bootstrap.sh)"
#   or:
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

# --- TTY and Input Helpers ---
# Helper to check if a controlling terminal is available
has_tty() {
    ( exec 3< /dev/tty ) 2>/dev/null
}

# Helper to read user input even when the script is piped (e.g. curl ... | bash)
prompt_read() {
    if has_tty; then
        read "$@" < /dev/tty
    elif [[ -t 0 ]]; then
        read "$@"
    else
        return 1
    fi
}

echo "=== macOS Nix Bootstrap ==="
echo ""

# --- Select Profile ---
echo "Select the Nix-darwin profile to bootstrap:"
echo "1) MacBook (Work + Base)"
echo "2) MacBook (Personal Base)"
echo "3) Mac Mini (Work + Base)"
echo "4) Mac Mini (Personal Base)"

PROFILE=""
while [[ -z "$PROFILE" ]]; do
    if ! prompt_read -p "Enter choice [1-4]: " PROFILE_CHOICE; then
        echo "Non-interactive session detected, defaulting to macbook-personal"
        PROFILE="macbook-personal"
        break
    fi
    case $PROFILE_CHOICE in
        1) PROFILE="macbook" ;;
        2) PROFILE="macbook-personal" ;;
        3) PROFILE="macmini" ;;
        4) PROFILE="personal" ;; # 'personal' corresponds to nix-bootstrap-personal
        *) echo "Invalid choice '$PROFILE_CHOICE'. Please enter 1, 2, 3, or 4." ;;
    esac
done
echo "Selected profile: $PROFILE"
echo ""

# --- MDM enrollment reminder (work profiles only, non-blocking) ---
if [[ "$PROFILE" == "macbook" || "$PROFILE" == "macmini" ]]; then
    echo "------------------------------------------------"
    echo "  FYI: Work machine"
    echo "------------------------------------------------"
    echo "  This bootstrap does NOT require MDM or the VPN."
    echo "  But you will need MDM enrollment later for VPN"
    echo "  and internal services (e.g. the Rokt MCP gateway)."
    echo "  Enroll any time at go/mdm (see docs/nix-setup.md)."
    echo "------------------------------------------------"
    echo ""
fi

# --- Xcode Command Line Tools ---
is_clt_installed() {
    if xcode-select -p &>/dev/null; then
        local dev_path
        dev_path="$(xcode-select -p 2>/dev/null)"
        if [[ -d "$dev_path" && ( -x "$dev_path/usr/bin/git" || -x "$dev_path/usr/bin/clang" ) ]]; then
            return 0
        fi
    fi
    if [[ -x "/Library/Developer/CommandLineTools/usr/bin/git" ]]; then
        return 0
    fi
    return 1
}

if is_clt_installed; then
    echo "[ok] Xcode Command Line Tools already installed"
else
    echo "[..] Installing Xcode Command Line Tools..."

    # Create temporary placeholder to prompt softwareupdate to list Command Line Tools
    CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$CLT_PLACEHOLDER"

    # Find the latest Command Line Tools package in softwareupdate
    CLT_LABEL=$(softwareupdate -l 2>/dev/null | grep -B 1 -E 'Command Line Tools' | awk -F'*' '/^ *\*/ {print $2}' | sed -e 's/^ *Label: //' -e 's/^ *//' | tr -d '\r' | sort -V | tail -n1)

    if [[ -n "$CLT_LABEL" ]]; then
        echo "[..] Found '$CLT_LABEL', installing via softwareupdate..."
        if sudo -n true 2>/dev/null; then
            sudo softwareupdate -i "$CLT_LABEL" || true
        else
            softwareupdate -i "$CLT_LABEL" || true
        fi
    fi
    rm -f "$CLT_PLACEHOLDER"

    # If headless install did not complete, fall back to GUI prompt and wait for it
    if ! is_clt_installed; then
        echo "[..] Opening Xcode Command Line Tools installer dialog..."
        xcode-select --install 2>/dev/null || true
        echo "[..] Waiting for Xcode Command Line Tools installation to finish..."
        echo "     (Please click 'Install' on the popup dialog if prompted)"
        until is_clt_installed; do
            sleep 5
        done
    fi

    # Switch developer path to CommandLineTools if available
    if [[ -d "/Library/Developer/CommandLineTools" ]]; then
        sudo xcode-select --switch /Library/Developer/CommandLineTools 2>/dev/null || true
    fi
    echo "[ok] Xcode Command Line Tools installed successfully"
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
    echo "[..] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "[ok] Homebrew already installed"
fi

# Ensure Homebrew is in PATH (Apple Silicon & Intel)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# --- Core packages ---
echo "[..] Installing bootstrap packages..."
if ! [[ -d "/Applications/1Password.app" ]]; then
    brew install --cask 1password
else
    echo "[ok] 1Password is already installed in /Applications"
fi
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
open -a "1Password" 2>/dev/null || true
prompt_read -p "  Press enter when done... " || true

# --- GitHub auth ---
echo ""
if gh auth status &>/dev/null; then
    echo "[ok] GitHub CLI already authenticated"
else
    echo "[..] Setting up GitHub authentication..."
    if has_tty && [[ ! -t 0 ]]; then
        gh auth login < /dev/tty
    else
        gh auth login
    fi
fi

# --- Nix installation ---
echo ""
if ! command -v nix &>/dev/null; then
    echo "[..] Installing Nix via Determinate Systems installer..."
    curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
    
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
    echo "[..] Cloning dotfiles..."
    git clone git@github.com:azheng8/dotfiles.git "$DOTFILES"
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
if [ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "[ok] Conflicting configs backed up to $BACKUP_DIR"
else
    rmdir "$BACKUP_DIR" 2>/dev/null || true
    echo "[ok] No conflicting configs found"
fi

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
