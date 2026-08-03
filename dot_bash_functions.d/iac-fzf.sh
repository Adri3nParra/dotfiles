# shellcheck shell=bash
# OpenTofu / Terragrunt : module -> action

_iac_fzf_error() {
  printf '\niac-fzf: %s\n' "$*" >&2
}

_iac_fzf_modules() {
  local file directory

  command -v rg >/dev/null 2>&1 || {
    _iac_fzf_error 'rg est introuvable.'
    return 1
  }

  while IFS= read -r file; do
    directory="${file%/*}"
    [[ "$directory" == "$file" ]] && directory='.'
    printf 'terragrunt|%s\n' "$directory"
  done < <(
    rg --files \
      -g 'terragrunt.hcl' \
      -g '!**/.terragrunt-cache/**' \
      -g '!**/.terraform/**' 2>/dev/null
  )

  while IFS= read -r file; do
    directory="${file%/*}"
    [[ "$directory" == "$file" ]] && directory='.'
    [[ -f "${directory}/terragrunt.hcl" ]] || printf 'tofu|%s\n' "$directory"
  done < <(
    rg --files \
      -g '*.tf' \
      -g '!**/.terragrunt-cache/**' \
      -g '!**/.terraform/**' 2>/dev/null
  ) | awk '!seen[$0]++'
}

iac_fzf() {
  local selected engine module action answer
  local -a actions

  command -v fzf >/dev/null 2>&1 || {
    _iac_fzf_error 'fzf est introuvable.'
    return 1
  }

  selected="$(
    _iac_fzf_modules |
      LC_ALL=C sort -t '|' -k2,2 -u |
      fzf \
        --height='70%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=2,1 \
        --prompt='Module IaC > ' \
        --header='Répertoire · moteur' \
        --preview='find {2} -maxdepth 1 -type f \( -name "*.tf" -o -name "*.hcl" \) -print 2>/dev/null | sort | head -80' \
        --preview-window='right:50%:wrap'
  )" || return

  [[ -n "$selected" ]] || {
    _iac_fzf_error 'aucun module OpenTofu ou Terragrunt trouvé sous ce répertoire.'
    return 1
  }
  IFS='|' read -r engine module <<<"$selected"

  if [[ "$engine" == 'terragrunt' ]]; then
    command -v terragrunt >/dev/null 2>&1 || {
      _iac_fzf_error 'terragrunt est introuvable.'
      return 1
    }
  else
    command -v tofu >/dev/null 2>&1 || {
      _iac_fzf_error 'tofu est introuvable.'
      return 1
    }
  fi

  actions=(
    'validate|Valider la configuration'
    'plan|Afficher les changements prévus'
    'output|Afficher les outputs'
    "show|Afficher l'état courant"
    'providers|Afficher les providers'
    'state-list|Lister les ressources du state'
    'init|Initialiser ou mettre à jour les dépendances'
    'apply|Appliquer les changements'
    'destroy|Détruire les ressources'
  )
  action="$(
    printf '%s\n' "${actions[@]}" |
      fzf \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2.. \
        --prompt="Action ${engine} > " \
        --header="Module : ${module}"
  )" || return
  action="${action%%|*}"

  case "$action" in
    apply|destroy)
      read -r -p "Tape ${action} pour confirmer sur ${module} : " answer
      [[ "$answer" == "$action" ]] || {
        _iac_fzf_error 'action annulée.'
        return 1
      }
      ;;
  esac

  if [[ "$engine" == 'terragrunt' ]]; then
    if [[ "$action" == 'state-list' ]]; then
      (cd "$module" && command terragrunt state list "$@")
    else
      (cd "$module" && command terragrunt "$action" "$@")
    fi
  elif [[ "$action" == 'state-list' ]]; then
    command tofu -chdir="$module" state list "$@"
  else
    command tofu -chdir="$module" "$action" "$@"
  fi
}
