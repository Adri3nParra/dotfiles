# Dotfiles Zsh

Configuration Zsh gérée avec chezmoi. Elle fournit Oh My Zsh, le prompt
Git/Kubernetes, les fonctions Cloud/Platform, ZLE et les raccourcis FZF.

## Nouvelle machine

Installer chezmoi dans `~/.local/bin`, puis appliquer les dotfiles :

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
chezmoi init --apply Adri3nParra
exec zsh
```

L'application installe d'abord mise et Homebrew, puis `mise bootstrap`
installe Zsh, les paquets et les plugins du shell. Un mot de passe sudo peut
être demandé pour les prérequis système et la création initiale du préfixe
Homebrew.

Pour faire de Zsh le shell de connexion, exécuter une fois :

```bash
chsh -s "$(command -v zsh)"
```

Lors de la migration, l'historique `~/.bash_history` est repris dans
`~/.zsh_history` si ce dernier n'existe pas encore.

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

Pour recharger Zsh après une modification :

```bash
reload
```

## Raccourcis

| Touche | Action |
| --- | --- |
| `Tab` | Complète le préfixe courant |
| `Tab Tab` | Insère puis parcourt les complétions en ligne |
| `Shift+Tab` | Complétion précédente |
| `Ctrl+Espace` | Menu de complétion FZF |
| `Ctrl+R` | Recherche dans l'historique |
| `Ctrl+T` | Sélection d'un fichier |
| `Alt+C` | Sélection d'un dossier |
| `Ctrl+G` | Navigateur AWS |
| `Ctrl+X Ctrl+P` | Menu Platform |
