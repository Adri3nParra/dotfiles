# shellcheck shell=bash
# Argo Rollouts : rollout -> action

_rollouts_fzf_error() {
  printf '\nrollouts-fzf: %s\n' "$*" >&2
}

_rollouts_fzf_require() {
  local executable
  for executable in "$@"; do
    command -v "$executable" >/dev/null 2>&1 || {
      _rollouts_fzf_error "${executable} est introuvable."
      return 1
    }
  done
}

_rollouts_fzf_resources() {
  command kubectl get rollouts.argoproj.io --all-namespaces --no-headers \
    -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,STRATEGY:.spec.strategy' \
    2>/dev/null |
    awk 'NF { printf "%s|%s|%s|%s\n", $1, $2, $3, $4 }'
}

rollouts_fzf() {
  local selected namespace rollout action answer
  local -a command_args

  _rollouts_fzf_require kubectl kubectl-argo-rollouts fzf || return 1

  selected="$(
    _rollouts_fzf_resources |
      fzf \
        --height='70%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=2,1,3,4 \
        --prompt='Argo Rollout > ' \
        --header='Nom · namespace · état · stratégie' \
        --preview='kubectl-argo-rollouts get rollout {2} -n {1} 2>/dev/null | head -140' \
        --preview-window='right:60%:wrap'
  )" || return

  [[ -n "$selected" ]] || {
    _rollouts_fzf_error 'aucun rollout trouvé.'
    return 1
  }
  IFS='|' read -r namespace rollout _ <<<"$selected"

  action="$(
    printf '%s\n' \
      'get|Afficher le rollout' \
      'watch|Suivre le déploiement en direct' \
      'status|Afficher son état' \
      "promote|Promouvoir à l'étape suivante" \
      'promote-full|Promouvoir entièrement' \
      'pause|Mettre en pause' \
      'restart|Redémarrer les pods' \
      'retry|Réessayer le rollout' \
      'undo|Revenir à la révision précédente' \
      'abort|Abandonner le déploiement' |
      fzf \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2.. \
        --prompt="Action pour ${rollout} > " \
        --header="Namespace : ${namespace}"
  )" || return
  action="${action%%|*}"

  case "$action" in
    get)          command_args=(get rollout "$rollout") ;;
    watch)        command_args=(get rollout "$rollout" --watch) ;;
    status)       command_args=(status "$rollout") ;;
    promote)      command_args=(promote "$rollout") ;;
    promote-full) command_args=(promote "$rollout" --full) ;;
    pause)        command_args=(pause "$rollout") ;;
    restart)      command_args=(restart "$rollout") ;;
    retry)        command_args=(retry rollout "$rollout") ;;
    undo)         command_args=(undo "$rollout") ;;
    abort)        command_args=(abort "$rollout") ;;
    *)            return 1 ;;
  esac

  case "$action" in
    abort|undo)
      read -r -p "Action sensible (${action}) sur ${namespace}/${rollout}. Continuer ? [y/N] " answer
      [[ "$answer" =~ ^[YyOo]$ ]] || return 1
      ;;
  esac

  command kubectl-argo-rollouts "${command_args[@]}" --namespace "$namespace" "$@"
}
