# shellcheck shell=bash
# GitLab CI : pipeline -> action

_gitlab_fzf_error() {
  printf '\ngitlab-fzf: %s\n' "$*" >&2
}

_gitlab_fzf_pipelines() {
  command glab ci list --output json --per-page 50 2>/dev/null |
    jq -r '.[] | [(.id|tostring), .status, .ref, (.updated_at // "-")] | join("|")'
}

gitlab_fzf() {
  local selected pipeline_id status ref action answer

  for executable in glab jq fzf; do
    command -v "$executable" >/dev/null 2>&1 || {
      _gitlab_fzf_error "${executable} est introuvable."
      return 1
    }
  done

  selected="$(
    _gitlab_fzf_pipelines |
      fzf \
        --height='70%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2,3,4 \
        --prompt='Pipeline GitLab > ' \
        --header='ID · état · branche · mise à jour' \
        --preview='glab ci get --pipeline-id {1} --with-job-details 2>/dev/null | head -160' \
        --preview-window='right:60%:wrap'
  )" || return

  [[ -n "$selected" ]] || {
    _gitlab_fzf_error 'aucun pipeline trouvé pour le projet courant.'
    return 1
  }
  IFS='|' read -r pipeline_id status ref _ <<<"$selected"

  action="$(
    printf '%s\n' \
      'view|Ouvrir la vue interactive des jobs' \
      'details|Afficher les détails et les jobs' \
      'trace|Choisir un job et suivre ses logs' \
      'retry|Choisir un job à relancer' \
      'cancel|Annuler le pipeline' |
      fzf \
        --height='55%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2.. \
        --prompt="Action pipeline ${pipeline_id} > " \
        --header="${status} · ${ref}"
  )" || return
  action="${action%%|*}"

  case "$action" in
    view)    command glab ci view --pipelineid "$pipeline_id" "$@" ;;
    details) command glab ci get --pipeline-id "$pipeline_id" --with-job-details "$@" ;;
    trace)   command glab ci trace --pipeline-id "$pipeline_id" "$@" ;;
    retry)   command glab ci retry --pipeline-id "$pipeline_id" "$@" ;;
    cancel)
      read -r -p "Annuler le pipeline ${pipeline_id} ? [y/N] " answer
      [[ "$answer" =~ ^[YyOo]$ ]] || return 1
      command glab ci cancel pipeline "$pipeline_id" "$@"
      ;;
    *) return 1 ;;
  esac
}
