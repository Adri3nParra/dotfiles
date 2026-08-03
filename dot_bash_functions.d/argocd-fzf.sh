# ───────────────────────────────────────────
# Argo CD CLI + FZF : application -> action
# Usage : argocd_fzf [options de l'action]
# ───────────────────────────────────────────

_argocd_app_actions() {
  local action

  while IFS= read -r action; do
    # `create` attend un nouveau nom, pas une application existante.
    [[ "$action" == "create" ]] && continue

    if command argocd app "$action" --help 2>/dev/null |
      sed -n '/^Usage:/,/^$/p' |
      grep -q 'APPNAME'; then
      printf '%s\n' "$action"
    fi
  done < <(
    command argocd __completeNoDesc app '' 2>/dev/null |
      sed '/^:[0-9][0-9]*$/d'
  )
}

argocd_fzf() {
  local app action

  command -v argocd >/dev/null 2>&1 || {
    printf '\nArgo CD CLI introuvable.\n' >&2
    return 1
  }

  command -v fzf >/dev/null 2>&1 || {
    printf '\nfzf introuvable.\n' >&2
    return 1
  }

  app="$(
    command argocd app list --output name |
      awk 'NF && !seen[$0]++' |
      fzf \
        --prompt='Application Argo CD > ' \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline \
        --preview='argocd app get {} 2>/dev/null | head -100' \
        --preview-window='right:60%:wrap'
  )" || return

  [[ -n "$app" ]] || return

  action="$(
    _argocd_app_actions |
      fzf \
        --prompt="Action pour ${app} > " \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline \
        --preview='argocd app {} --help 2>/dev/null | head -100' \
        --preview-window='right:60%:wrap'
  )" || return

  [[ -n "$action" ]] || return

  command argocd app "$action" "$app" "$@"
}
