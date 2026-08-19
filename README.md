# Dotfiles Bash

Configuration Bash gérée avec chezmoi. Elle fournit Oh My Bash, le prompt Kubernetes, les fonctions Cloud/Platform et les raccourcis FZF.

## Installation minimale

Sur Ubuntu ou Debian :

```bash
sudo apt update
sudo apt install -y \
  bash git curl ripgrep jq eza bat btop figlet powerline
```

Installer chezmoi dans `~/.local/bin` :

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
```

## Dépendances du shell

```bash
# Oh My Bash
git clone --depth 1 \
  https://github.com/ohmybash/oh-my-bash.git \
  "$HOME/.oh-my-bash"

# Contexte Kubernetes dans le prompt
git clone --depth 1 \
  https://github.com/jonmosco/kube-ps1.git \
  "$HOME/.oh-my-bash/custom/kube-ps1"

# FZF et ses intégrations Bash
git clone --depth 1 \
  https://github.com/junegunn/fzf.git \
  "$HOME/.fzf"
"$HOME/.fzf/install" --bin

# Menu FZF pour les complétions Bash
git clone --depth 1 \
  https://github.com/lincheney/fzf-tab-completion.git \
  "$HOME/.local/share/fzf-tab-completion"
```

## Appliquer les dotfiles

```bash
chezmoi init git@github.com:Adri3nParra/dotfiles.git
chezmoi diff
chezmoi apply
exec bash
```

Pour recharger après une modification :

```bash
reload
```

## Raccourcis

| Touche | Action |
| --- | --- |
| `Tab` | Complétion Bash suivante |
| `Shift+Tab` | Complétion précédente |
| `Ctrl+Espace` | Menu de complétion FZF |
| `Ctrl+R` | Recherche dans l’historique |
| `Ctrl+T` | Sélection d’un fichier |
| `Alt+C` | Sélection d’un dossier |
| `Ctrl+G` | Navigateur AWS |
| `Ctrl+X Ctrl+P` | Menu Platform |

## Outils optionnels

Les complétions et fonctions associées s’activent si les commandes existent : `kubectl`, `helm`, `argocd`, `k9s`, `stern`, `glab`, `aws`, `ansible`, `tofu`, `terragrunt`, `docker`, `trivy` et `cosign`.
