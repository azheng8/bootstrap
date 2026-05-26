# bootstrap

Bare metal macOS to fully configured modular Nix-darwin + Home Manager dev machine in one command.

## Usage

```sh
curl -fsSL https://raw.githubusercontent.com/azheng8/bootstrap/main/bootstrap.sh | bash
```

## What it does

1. Installs Xcode Command Line Tools
2. Installs Homebrew
3. Installs 1Password, gh, just, git
4. Pauses for 1Password sign-in & CLI Biometrics integration
5. Runs `gh auth login` (authenticates your GitHub account and links SSH key)
6. Installs Determinate Nix
7. Clones [dotfiles](https://github.com/azheng8/dotfiles) (on the `az/migrate-to-nix` branch)
8. Prompts you to select a profile (`macbook`, `macbook-personal`, `macmini`, `macmini-personal`)
9. Backs up conflicting configs under `~` to prevent Home Manager conflicts
10. Sets up Oh-My-Zsh & plugins
11. Launches `nix-darwin` bootstrap to compile and activate your profile
12. Restores GPG keys and secrets via 1Password CLI (`just secrets`)

## After bootstrap

Once the script completes, simply restart your shell:

```sh
exec zsh
```
