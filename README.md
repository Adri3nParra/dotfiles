# Dotfiles Bash

Configuration Bash gérée avec chezmoi. Elle fournit Oh My Bash, le prompt
Kubernetes, les fonctions Cloud/Platform et les raccourcis FZF.

## Nouvelle machine

Installer chezmoi dans `~/.local/bin`, puis appliquer les dotfiles :

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
chezmoi init --apply git@github.com:Adri3nParra/dotfiles.git
exec bash
```

L'application installe d'abord mise, puis `mise bootstrap` installe les
paquets Apt et Homebrew et clone les dépendances du shell. Homebrew n'a pas
besoin d'être installé au préalable. Un mot de passe sudo peut être demandé
pour les paquets système et la création initiale du préfixe Homebrew.

## Maintenance

Depuis le répertoire source chezmoi :

```bash
# Rejouer le bootstrap complet
mise bootstrap

# Ajouter et installer un paquet dans la configuration source
mise bootstrap packages use \
  --path private_dot_config/mise/config.toml \
  brew:jq

# Appliquer une modification de dotfiles
chezmoi apply
```

Pour recharger Bash après une modification :

```bash
reload
```

## Raccourcis

| Touche | Action |
| --- | --- |
| `Tab` | Complétion Bash suivante |
| `Shift+Tab` | Complétion précédente |
| `Ctrl+Espace` | Menu de complétion FZF |
| `Ctrl+R` | Recherche dans l'historique |
| `Ctrl+T` | Sélection d'un fichier |
| `Alt+C` | Sélection d'un dossier |
| `Ctrl+G` | Navigateur AWS |
| `Ctrl+X Ctrl+P` | Menu Platform |
