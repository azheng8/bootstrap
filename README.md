# bootstrap

Bare metal macOS to fully configured modular Nix-darwin + Home Manager dev machine in one command.

## Usage

Recommended (preserves standard input for interactive prompts):
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/azheng8/bootstrap/main/bootstrap.sh)"
```

Alternatively (piped):
```sh
curl -fsSL https://raw.githubusercontent.com/azheng8/bootstrap/main/bootstrap.sh | bash
```

## What it does

1. Installs Xcode Command Line Tools
2. Installs Homebrew
3. Installs 1Password, Chrome, Alfred, Ghostty, AeroSpace, `gh`, `just`, `git`
4. Pauses for 1Password sign-in, CLI Biometrics & SSH Agent setup
5. Runs `gh auth login --git-protocol https --web` (HTTPS git credentials via `gh`)
6. Installs Determinate Nix
7. Clones [dotfiles](https://github.com/azheng8/dotfiles) (`master`) via HTTPS
8. Prompts you to select a profile (`macbook`, `macbook-personal`, `macmini`, `macmini-personal`)
9. Backs up conflicting configs under `~` to prevent Home Manager conflicts
10. Sets up Oh-My-Zsh & plugins
11. Launches `nix-darwin` bootstrap to compile and activate your profile
12. Restores GPG keys via 1Password CLI (`just secrets`) and runs `just post-setup` + `just doctor`

## After bootstrap

Once the script completes, simply restart your shell:

```sh
exec zsh
```
