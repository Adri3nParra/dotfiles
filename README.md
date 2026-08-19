# Dotfiles Bash

Configuration Bash gérée avec chezmoi. Elle fournit Oh My Bash, le prompt Kubernetes, les fonctions Cloud/Platform et les raccourcis FZF.

## Installation minimale

Sur Ubuntu ou Debian :

```bash
sudo apt update
sudo apt install -y \
  bash git curl wget ripgrep jq eza bat btop figlet powerline tldr duf moreutils btop

# bat s'appelle batcat sur Ubuntu
mkdir -p ~/.local/bin
ln -s $(which batcat) ~/.local/bin/bat

brew install yazi

sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install -y eza
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
brew install fzf
~/.fzf/install --key-bindings --completion --no-update-rc

# Menu FZF pour les complétions Bash
git clone --depth 1 \
  https://github.com/lincheney/fzf-tab-completion.git \
  "$HOME/.local/share/fzf-tab-completion"

# Zoxide
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
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

```bash
# kubectl
VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLo ~/.local/bin/kubectl "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl"
chmod +x ~/.local/bin/kubectl

# kubectx & kubens
VERSION=$(curl -sL https://api.github.com/repos/ahmetb/kubectx/releases/latest | jq -r '.tag_name')
curl -sL "https://github.com/ahmetb/kubectx/releases/download/${VERSION}/kubectx_${VERSION}_linux_x86_64.tar.gz" | tar xz -C ~/.local/bin kubectx
curl -sL "https://github.com/ahmetb/kubectx/releases/download/${VERSION}/kubens_${VERSION}_linux_x86_64.tar.gz" | tar xz -C ~/.local/bin kubens

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash

# yq
VERSION=$(curl -sL https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.tag_name')
curl -sLo ~/.local/bin/yq "https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_amd64"
chmod +x ~/.local/bin/yq

# Opentofu
VERSION=$(curl -sL https://api.github.com/repos/opentofu/opentofu/releases/latest | jq -r '.tag_name')
curl -sL "https://github.com/opentofu/opentofu/releases/download/${VERSION}/tofu_${VERSION#v}_linux_amd64.tar.gz" | tar xz -C ~/.local/bin tofu

# Kubeseal
VERSION=$(curl -sL https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | jq -r '.tag_name')
curl -sL "https://github.com/bitnami-labs/sealed-secrets/releases/download/${VERSION}/kubeseal-${VERSION#v}-linux-amd64.tar.gz" | tar xz -C ~/.local/bin kubeseal

# Velero
VERSION=$(curl -sL https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r '.tag_name')
curl -sL "https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz" \
  | tar xz --strip-components=1 -C ~/.local/bin "velero-${VERSION}-linux-amd64/velero"
```
