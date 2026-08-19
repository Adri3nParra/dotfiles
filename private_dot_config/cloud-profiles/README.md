# Cloud Profile Manager

Petit gestionnaire de profils cloud pour Bash.

Il permet de changer rapidement de contexte entre plusieurs fournisseurs cloud sans avoir à modifier manuellement les variables d’environnement ou à changer de dossier.

```bash
cloud use ovh-prod
cloud use aws-lab
cloud use scaleway-dev
```

Le gestionnaire ne stocke pas directement les secrets. Il sélectionne uniquement les profils configurés dans les outils natifs de chaque fournisseur.

## Fonctionnement

Lorsqu’un profil est activé :

```bash
cloud use aws-lab
```

le gestionnaire charge un fichier comme :

```bash
export CLOUD_PROVIDER="aws"
export AWS_PROFILE="lab"
export AWS_REGION="eu-west-3"
```

Lorsque la CLI AWS est ensuite utilisée :

```bash
aws sts get-caller-identity
```

elle lit automatiquement les credentials du profil `lab` dans ses fichiers natifs :

```text
~/.aws/config
~/.aws/credentials
```

Le fonctionnement est identique pour les autres fournisseurs :

| Fournisseur          | Variable sélectionnée         | Configuration native                    |
| -------------------- | ----------------------------- | --------------------------------------- |
| AWS                  | `AWS_PROFILE`                 | `~/.aws/config` et `~/.aws/credentials` |
| Scaleway             | `SCW_PROFILE`                 | `~/.config/scw/config.yaml`             |
| OpenStack / OVHcloud | Variables `OS_*`              | `~/.config/openstack/openrc.sh`         |
| GCP                  | `CLOUDSDK_ACTIVE_CONFIG_NAME` | `~/.config/gcloud/`                     |
| Azure                | Session Azure CLI             | `~/.azure/`                             |

## Structure

```text
~/.config/cloud-profiles/
├── cloud.sh
└── profiles/
    ├── aws-lab.env
    ├── ovh-prod.env
    └── scaleway-dev.env
```

* `cloud.sh` contient la fonction Bash `cloud`.
* `profiles/` contient les contextes disponibles.
* Les fichiers `*.env` ne doivent pas contenir de secrets.

## Installation

### Dépendance optionnelle

`fzf` permet d’afficher un menu interactif pour sélectionner un profil :

```bash
sudo apt install fzf
```

Les profils peuvent tout de même être activés directement sans `fzf` :

```bash
cloud use ovh-prod
```

### Chargement dans Bash

Ajouter dans `~/.bashrc` :

```bash
if [[ -f "$HOME/.config/cloud-profiles/cloud.sh" ]]; then
    source "$HOME/.config/cloud-profiles/cloud.sh"
fi
```

Recharger le shell :

```bash
source ~/.bashrc
```

Vérifier que la fonction est disponible :

```bash
type cloud
```

## Utilisation

### Sélection interactive

```bash
cloud use
```

Un menu `fzf` affiche les profils disponibles.

### Activation directe

```bash
cloud use ovh-prod
```

### Liste des profils

```bash
cloud list
```

Alias disponible :

```bash
cloud ls
```

### Profil actif

```bash
cloud current
```

### Variables actives

```bash
cloud show
```

Les principales variables cloud sont affichées. Les valeurs sensibles connues sont masquées.

### Rechargement du profil

Après avoir modifié le fichier du profil actif :

```bash
cloud reload
```

### Édition d’un profil

```bash
cloud edit ovh-prod
```

Sans nom, un menu interactif est affiché :

```bash
cloud edit
```

### Désactivation

```bash
cloud unset
```

Alias disponible :

```bash
cloud clear
```

Cette commande supprime les variables AWS, GCP, Azure, OpenStack, Scaleway, Kubernetes et Terraform gérées par le script.

### Aide

```bash
cloud help
```

## Création des profils

### AWS

Fichier :

```text
~/.config/cloud-profiles/profiles/aws-lab.env
```

Contenu :

```bash
export CLOUD_PROVIDER="aws"

export AWS_PROFILE="lab"
export AWS_REGION="eu-west-3"
export AWS_DEFAULT_REGION="$AWS_REGION"

export KUBECONFIG="$HOME/.kube/aws-lab.yaml"
export TF_VAR_environment="lab"
```

Configurer les credentials AWS séparément :

```bash
aws configure --profile lab
```

Ou utiliser AWS IAM Identity Center :

```bash
aws configure sso --profile lab
```

Test :

```bash
cloud use aws-lab
aws sts get-caller-identity
```

### OVHcloud / OpenStack

Fichier :

```text
~/.config/cloud-profiles/profiles/ovh-prod.env
```

Contenu :

```bash
export CLOUD_PROVIDER="ovhcloud"

# shellcheck disable=SC1091
source "$HOME/.config/openstack/openrc.sh"

export KUBECONFIG="$HOME/.kube/fabrique-prod.yaml"
export TF_VAR_environment="prod"
```

Les variables OpenStack et les credentials sont configurés dans :

```text
~/.config/openstack/openrc.sh
```

Protéger le fichier :

```bash
chmod 600 ~/.config/openstack/openrc.sh
```

Test :

```bash
cloud use ovh-prod
openstack token issue
openstack server list
```

### Scaleway

Fichier :

```text
~/.config/cloud-profiles/profiles/scaleway-dev.env
```

Contenu :

```bash
export CLOUD_PROVIDER="scaleway"

export SCW_PROFILE="dev"
export SCW_DEFAULT_REGION="fr-par"
export SCW_DEFAULT_ZONE="fr-par-1"

export KUBECONFIG="$HOME/.kube/scaleway-dev.yaml"
export TF_VAR_environment="dev"
```

Configurer le profil Scaleway avec :

```bash
scw init
```

Test :

```bash
cloud use scaleway-dev
scw info
```

### GCP

Fichier :

```text
~/.config/cloud-profiles/profiles/gcp-dev.env
```

Contenu :

```bash
export CLOUD_PROVIDER="gcp"

export CLOUDSDK_ACTIVE_CONFIG_NAME="dev"
export CLOUDSDK_CORE_PROJECT="my-project-dev"

export KUBECONFIG="$HOME/.kube/gcp-dev.yaml"
export TF_VAR_environment="dev"
```

Créer et configurer le profil GCP :

```bash
gcloud config configurations create dev
gcloud config configurations activate dev
gcloud config set project my-project-dev
gcloud auth login
```

Test :

```bash
cloud use gcp-dev
gcloud config list
gcloud auth list
```

## Gestion des secrets

Les fichiers de profils servent uniquement à sélectionner un contexte :

```bash
export AWS_PROFILE="lab"
source "$HOME/.config/openstack/openrc.sh"
export SCW_PROFILE="dev"
```

Ils ne doivent pas contenir de credentials permanents.

Ne pas ajouter ce type de variable :

```bash
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export SCW_SECRET_KEY="..."
export OS_PASSWORD="..."
export ARM_CLIENT_SECRET="..."
```

Les secrets restent gérés par les outils natifs :

```text
AWS        → ~/.aws/credentials
Scaleway   → ~/.config/scw/config.yaml
OpenStack  → ~/.config/openstack/openrc.sh
GCP        → ~/.config/gcloud/
Azure      → ~/.azure/
```

Le flux est donc :

```text
cloud use ovh-prod
        ↓
chargement de ~/.config/openstack/openrc.sh
        ↓
openstack server list
        ↓
OpenStack utilise les variables OS_* chargées
```

## Intégration avec chezmoi

Ajouter le gestionnaire dans chezmoi :

```bash
chezmoi add --recursive ~/.config/cloud-profiles
```

Vérifier les modifications :

```bash
chezmoi status
chezmoi diff
```

Commit et push :

```bash
chezmoi cd

git add .
git commit -m "feat(shell): add cloud profile manager"
git push
```

Les fichiers de profils peuvent être commités tant qu’ils ne contiennent aucun secret.

Vérification rapide avant un commit :

```bash
grep -RniE \
    'SECRET|PASSWORD|TOKEN|ACCESS_KEY|PRIVATE_KEY' \
    ~/.config/cloud-profiles
```

Sur une nouvelle machine :

```bash
chezmoi init --apply USERNAME
```

Les profils seront installés, mais les CLI devront être authentifiées localement :

```bash
aws configure sso --profile lab
scw init
gcloud auth login
az login
```

Pour OpenStack, il faudra également recréer ou restaurer localement :

```text
~/.config/openstack/openrc.sh
```

## Permissions

Appliquer des permissions restrictives :

```bash
chmod 700 ~/.config/cloud-profiles
chmod 700 ~/.config/cloud-profiles/profiles
chmod 600 ~/.config/cloud-profiles/profiles/*.env
```

Pour les fichiers contenant réellement des secrets :

```bash
chmod 600 ~/.aws/credentials
chmod 600 ~/.config/openstack/openrc.sh
chmod 600 ~/.config/scw/config.yaml
```

## Exemple de workflow

Connexion à OVHcloud :

```bash
cloud use ovh-prod

openstack server list
kubectl get nodes
```

Passage sur Scaleway :

```bash
cloud use scaleway-dev

scw instance server list
kubectl get nodes
```

Passage sur AWS :

```bash
cloud use aws-lab

aws sts get-caller-identity
kubectl get nodes
```

Nettoyage du contexte :

```bash
cloud unset
```

## Limites

Ce gestionnaire :

* ne réalise pas lui-même l’authentification ;
* ne renouvelle pas les tokens expirés ;
* ne remplace pas les CLI officielles ;
* ne chiffre pas les secrets ;
* sélectionne uniquement les profils et variables du shell courant.

La fonction doit être sourcée dans le shell. Elle ne doit pas être lancée comme un script classique, car un processus enfant ne peut pas modifier durablement les variables de son shell parent.
