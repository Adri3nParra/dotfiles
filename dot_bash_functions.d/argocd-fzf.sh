# ───────────────────────────────────────────
# Argo CD CLI + FZF
# Commande : argocd_fzf
# ───────────────────────────────────────────

_argocd_completions() {
  argocd __completeNoDesc "$@" 2>/dev/null |
    sed '/^:[0-9][0-9]*$/d' |
    awk 'NF && $0 !~ /^-/ && !seen[$0]++'
}

_argocd_app_required() {
  local operation="$1"

  [[ "${operation}" != 'create' ]] &&
    argocd app "${operation}" --help 2>/dev/null |
      sed -n '/^Usage:/,/^$/p' |
      grep -q 'APPNAME'
}

argocd_fzf() {
  local app
  local apps
  local group
  local operation
  local operations

  command -v argocd >/dev/null 2>&1 || {
    printf '\nArgo CD CLI introuvable.\n' >&2
    return 1
  }

  command -v fzf >/dev/null 2>&1 || {
    printf '\nfzf introuvable.\n' >&2
    return 1
  }

  group="$(
    _argocd_completions '' |
      grep -vE '^(completion|help)$' |
      fzf \
        --prompt='Argo CD commande > ' \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline \
        --preview='argocd {} --help 2>/dev/null | head -100' \
        --preview-window='right:60%:wrap'
  )" || return

  operations="$(_argocd_completions "${group}" '' | grep -vE '^help$')"

  if [[ -z "${operations}" ]]; then
    command argocd "${group}" "$@"
    return $?
  fi

  operation="$(
    printf '%s\n' "${operations}" |
      fzf \
        --prompt="argocd ${group} > " \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline \
        --preview="argocd ${group} {} --help 2>/dev/null | head -100" \
        --preview-window='right:60%:wrap'
  )" || return

  if [[ "${group}" == 'app' ]] && _argocd_app_required "${operation}"; then
    apps="$(command argocd app list --output name)" || return

    if [[ -z "${apps}" ]]; then
      printf 'Aucune application Argo CD trouvée.\n' >&2
      return 1
    fi

    app="$(
      printf '%s\n' "${apps}" |
        awk 'NF && !seen[$0]++' |
        fzf \
          --prompt="argocd app ${operation} > " \
          --height='60%' \
          --layout=reverse \
          --border \
          --info=inline \
          --preview='argocd app get {} 2>/dev/null | head -100' \
          --preview-window='right:60%:wrap'
    )" || return

    command argocd "${group}" "${operation}" "${app}" "$@"
    return $?
  fi

  command argocd "${group}" "${operation}" "$@"
}
