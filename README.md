# bootstrap

Bare metal macOS to fully configured dev machine in one command.

## Usage

```sh
curl -fsSL https://raw.githubusercontent.com/azheng8/bootstrap/main/bootstrap.sh | bash
```

## What it does

1. Installs Xcode Command Line Tools
2. Installs Homebrew
3. Installs 1Password, gh, stow, just, git
4. Pauses for 1Password sign-in (manual step)
5. Runs `gh auth login` (SSH key + GitHub auth)
6. Clones [dotfiles](https://github.com/azheng8/dotfiles) and runs `just bootstrap`

## After bootstrap

```sh
# Work machine — add Rokt configs
cd ~/dotfiles && just work

# Restart shell
exec zsh
```
