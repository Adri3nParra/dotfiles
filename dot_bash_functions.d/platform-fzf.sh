# shellcheck shell=bash
# Cockpit Cloud / Platform, sans navigateur Kubernetes ni Helm.

_platform_fzf_error() {
  printf '\nplatform-fzf: %s\n' "$*" >&2
}

_platform_fzf_section() {
  printf '\n\033[1;36m%s\033[0m\n' "$1"
}

platform_ctx() {
  local value

  _platform_fzf_section 'AWS'
  printf 'Profil : %s\n' "${AWS_PROFILE:-default}"
  printf 'Région : %s\n' "${AWS_REGION:-${AWS_DEFAULT_REGION:-auto}}"
  if command -v aws >/dev/null 2>&1; then
    AWS_PAGER='' timeout 8s aws sts get-caller-identity \
      --query '{Compte:Account,Utilisateur:UserId,ARN:Arn}' \
      --output table 2>&1 || printf 'Identité AWS indisponible.\n'
  else
    printf 'AWS CLI absente.\n'
  fi

  _platform_fzf_section 'Argo CD'
  if command -v argocd >/dev/null 2>&1; then
    timeout 5s argocd context 2>&1 || printf 'Contexte Argo CD indisponible.\n'
  else
    printf 'Argo CD CLI absente.\n'
  fi

  _platform_fzf_section 'Docker'
  if command -v docker >/dev/null 2>&1; then
    value="$(command docker context show 2>/dev/null)"
    printf 'Contexte : %s\n' "${value:-indisponible}"
  else
    printf 'Docker CLI absente.\n'
  fi

  _platform_fzf_section 'GitLab / dépôt'
  if command -v git >/dev/null 2>&1 &&
    value="$(command git remote get-url origin 2>/dev/null)"; then
    printf 'Origin : %s\n' "$value"
    value="$(command git branch --show-current 2>/dev/null)"
    printf 'Branche : %s\n' "${value:-HEAD détachée}"
  else
    printf 'Aucun dépôt Git détecté.\n'
  fi

  _platform_fzf_section 'Infrastructure as Code'
  if command -v rg >/dev/null 2>&1; then
    value="$(
      rg --files -g 'terragrunt.hcl' -g '*.tf' \
        -g '!**/.terragrunt-cache/**' -g '!**/.terraform/**' 2>/dev/null |
        wc -l
    )"
    printf 'Fichiers Terragrunt/OpenTofu sous ce répertoire : %s\n' "$value"
  else
    printf 'Comptage indisponible (rg absent).\n'
  fi
}

_platform_fzf_call() {
  local function_name="$1"

  declare -F "$function_name" >/dev/null 2>&1 || {
    _platform_fzf_error "le module ${function_name} n'est pas chargé. Recharge ~/.bash_functions.d/*.sh."
    return 1
  }
  "$function_name"
}

platform_fzf() {
  local selection module

  command -v fzf >/dev/null 2>&1 || {
    _platform_fzf_error 'fzf est introuvable.'
    return 1
  }

  selection="$(
    printf '%s\n' \
      'context|Contexte et identités|AWS, Argo CD, Docker, GitLab et IaC' \
      'aws|AWS|Inventaire rapide ou CLI complète' \
      'argocd|Argo CD|Applications, projets, clusters, dépôts et actions' \
      'rollouts|Argo Rollouts|État, promotion, pause, retry, undo et abort' \
      'iac|OpenTofu / Terragrunt|Modules, validation, plan, state et apply' \
      'gitlab|GitLab CI|Pipelines, jobs, logs, retry et annulation' \
      'containers|Docker / sécurité|Conteneurs, images, Trivy et Cosign' \
      'ansible|Ansible|Playbooks, check, diff, tags et exécution' |
      fzf \
        --height='65%' \
        --layout=reverse \
        --border \
        --info=inline \
        --cycle \
        --delimiter='|' \
        --with-nth=2,3.. \
        --prompt='Platform > ' \
        --header='Entrée : ouvrir  ·  Échap : annuler'
  )" || return
  module="${selection%%|*}"

  case "$module" in
    context)    platform_ctx ;;
    aws)        _platform_fzf_call aws_fzf ;;
    argocd)     _platform_fzf_call argocd_fzf ;;
    rollouts)   _platform_fzf_call rollouts_fzf ;;
    iac)        _platform_fzf_call iac_fzf ;;
    gitlab)     _platform_fzf_call gitlab_fzf ;;
    containers) _platform_fzf_call container_fzf ;;
    ansible)    _platform_fzf_call ansible_fzf ;;
    *)          return 1 ;;
  esac
}

# Ctrl+X puis Ctrl+P : ouvre le cockpit Platform sans écraser les raccourcis
# Readline courants ni le Ctrl+G réservé au navigateur AWS.
if [[ $- == *i* ]]; then
  bind -x '"\C-x\C-p":platform_fzf'
fi
