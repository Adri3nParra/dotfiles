# ───────────────────────────────────────────
# Argo CD CLI + FZF
# Commande : argocd_fzf
# ───────────────────────────────────────────

_argocd_completions() {
  argocd __completeNoDesc "$@" 2>/dev/null |
    sed '/^:[0-9][0-9]*$/d' |
    awk 'NF && $0 !~ /^-/ && !seen[$0]++'
}

argocd_fzf() {
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

  command argocd "${group}" "${operation}" "$@"
}
