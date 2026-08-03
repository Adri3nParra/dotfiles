# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# Argo CD CLI + FZF
#
# Parcours : commande (app, proj, cluster...) -> action -> cible -> options
# Usage    : argocd_fzf [arguments supplémentaires]
# ─────────────────────────────────────────────────────────────────────────────

_argocd_fzf_error() {
  printf '\nargocd-fzf: %s\n' "$*" >&2
}

_argocd_fzf_require() {
  local executable

  for executable in "$@"; do
    command -v "$executable" >/dev/null 2>&1 || {
      _argocd_fzf_error "${executable} est introuvable."
      return 1
    }
  done
}

_argocd_fzf_base_options() {
  printf '%s\n' \
    '--height=70%' \
    '--layout=reverse' \
    '--border' \
    '--info=inline' \
    '--cycle'
}

_argocd_join_command() {
  local word joined='argocd'

  for word in "$@"; do
    joined+=" ${word}"
  done
  printf '%s' "$joined"
}

# Utilise le texte de --help plutôt que __completeNoDesc : ce dernier peut ne
# rien retourner selon la version de la CLI ou le contexte du shell.
_argocd_subcommands() {
  command argocd "$@" --help 2>/dev/null |
    awk '
      /^Available Commands:$/ { in_commands = 1; next }
      in_commands && /^[[:alpha:]][[:alpha:] ]+:$/ { exit }

      in_commands && match($0, /^  [[:alnum:]][[:alnum:]-]*/) {
        line = substr($0, RSTART + 2)
        command = line
        sub(/[[:space:]].*$/, "", command)
        sub(/^[^[:space:]]+[[:space:]]+/, "", line)
        if (command != "help")
          printf "%s|%s\n", command, line
      }
    '
}

_argocd_choose_command() {
  local rows selection prefix prompt
  local -a path=() fzf_options

  mapfile -t fzf_options < <(_argocd_fzf_base_options)

  while :; do
    rows="$(_argocd_subcommands "${path[@]}")" || return
    [[ -n "$rows" ]] || break

    prefix="$(_argocd_join_command "${path[@]}")"
    if (( ${#path[@]} == 0 )); then
      prompt='Commande Argo CD > '
    else
      prompt="Action pour ${path[*]} > "
    fi

    selection="$(
      printf '%s\n' "$rows" |
        fzf \
          "${fzf_options[@]}" \
          --delimiter='|' \
          --with-nth=1,2.. \
          --prompt="$prompt" \
          --header='Entrée : choisir  ·  Échap : annuler' \
          --preview="${prefix} {1} --help 2>/dev/null | head -160" \
          --preview-window='right:55%:wrap'
    )" || return

    [[ -n "$selection" ]] || return 1
    path+=("${selection%%|*}")
  done

  _ARGOCD_FZF_COMMAND=("${path[@]}")
}

_argocd_usage_arguments() {
  local path_length="$1"
  shift

  command argocd "$@" --help 2>/dev/null |
    awk -v path_length="$path_length" '
      /^Usage:$/ { in_usage = 1; next }
      in_usage && /^  argocd / {
        for (i = 2 + path_length; i <= NF; i++) {
          argument = $i
          if (argument == "[flags]")
            break
          if (argument !~ /^-/ && argument !~ /^\[/)
            print argument
        }
        exit
      }
    '
}

_argocd_existing_resources() {
  local group="$1"

  case "$group" in
    app)       command argocd app list --output name ;;
    appset)    command argocd appset list --output name ;;
    cluster)   command argocd cluster list --output server ;;
    proj)      command argocd proj list --output name ;;
    repo)      command argocd repo list --output url ;;
    repocreds) command argocd repocreds list --output url ;;
    *)         return 1 ;;
  esac 2>/dev/null | awk 'NF && !seen[$0]++'
}

_argocd_can_select_resource() {
  local group="$1" action="$2" argument="$3"

  case "${group}:${action}" in
    app:create|appset:create|cluster:add|proj:create|repo:add|repocreds:add)
      return 1
      ;;
  esac

  case "${group}:${argument}" in
    app:APPNAME*|appset:APPSET*|appset:NAME*|cluster:SERVER*|cluster:CLUSTER*|proj:PROJECT*|repo:REPO*|repocreds:REPO*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_argocd_select_resource() {
  local group="$1" argument="$2" rows preview
  local -a fzf_options multi_options=()

  rows="$(_argocd_existing_resources "$group")" || return 1
  [[ -n "$rows" ]] || return 1

  mapfile -t fzf_options < <(_argocd_fzf_base_options)
  [[ "$argument" == *... ]] && multi_options=(--multi --bind='space:toggle+down,tab:toggle+down')

  preview="argocd ${group} get {} 2>/dev/null | head -120"
  printf '%s\n' "$rows" |
    fzf \
      "${fzf_options[@]}" \
      "${multi_options[@]}" \
      --prompt="${argument%...} > " \
      --header='Entrée : choisir  ·  Espace/Tab : choix multiple  ·  Échap : annuler' \
      --preview="$preview" \
      --preview-window='right:55%:wrap'
}

_argocd_collect_arguments() {
  local raw_argument label value selected group action
  local first_argument=1
  local -a arguments selected_resources

  group="${_ARGOCD_FZF_COMMAND[0]:-}"
  action="${_ARGOCD_FZF_COMMAND[1]:-${_ARGOCD_FZF_COMMAND[0]:-}}"
  mapfile -t arguments < <(
    _argocd_usage_arguments "${#_ARGOCD_FZF_COMMAND[@]}" "${_ARGOCD_FZF_COMMAND[@]}"
  )
  _ARGOCD_FZF_ARGUMENTS=()

  for raw_argument in "${arguments[@]}"; do
    label="${raw_argument//[\[\]<>]/}"

    if (( first_argument )) &&
      _argocd_can_select_resource "$group" "$action" "$label"; then
      selected="$(_argocd_select_resource "$group" "$label")" || {
        _argocd_fzf_error "impossible de lister les ressources pour ${label}."
        return 1
      }
      mapfile -t selected_resources <<<"$selected"
      _ARGOCD_FZF_ARGUMENTS+=("${selected_resources[@]}")
    else
      if ! read -e -r -p "Valeur pour ${label%...} : " value; then
        printf '\n' >&2
        return 1
      fi
      [[ -n "$value" ]] || {
        _argocd_fzf_error "${label%...} est obligatoire."
        return 1
      }
      _ARGOCD_FZF_ARGUMENTS+=("$value")
    fi
    first_argument=0
  done
}

_argocd_action_flags() {
  command argocd "$@" --help 2>/dev/null |
    awk '
      /^Flags:$/        { in_flags = 1; next }
      /^Global Flags:$/ { in_flags = 0 }

      in_flags && match($0, /--[[:alnum:]][[:alnum:]-]*/) {
        flag = substr($0, RSTART, RLENGTH)
        if (flag == "--help")
          next

        rest = substr($0, RSTART + RLENGTH)
        sub(/^[[:space:]]+/, "", rest)

        if (match(rest, /[[:space:]][[:space:]]+/)) {
          type = substr(rest, 1, RSTART - 1)
          description = substr(rest, RSTART + RLENGTH)
        } else {
          type = ""
          description = rest
        }

        printf "%s|%s|%s\n", flag, type, description
      }
    '
}

_argocd_select_flags() {
  local rows command_label
  local -a fzf_options

  rows="$(_argocd_action_flags "${_ARGOCD_FZF_COMMAND[@]}")" || return
  [[ -n "$rows" ]] || return 0

  command_label="$(_argocd_join_command "${_ARGOCD_FZF_COMMAND[@]}")"
  mapfile -t fzf_options < <(_argocd_fzf_base_options)
  {
    printf '__RUN__||▶ Exécuter sans option\n'
    printf '%s\n' "$rows"
  } | fzf \
    "${fzf_options[@]}" \
    --multi \
    --delimiter='|' \
    --with-nth=1,3.. \
    --prompt='Options > ' \
    --header='Espace/Tab : cocher  ·  Entrée : valider  ·  Échap : annuler' \
    --bind='space:toggle+down,tab:toggle+down' \
    --preview="${command_label} --help 2>/dev/null | head -160" \
    --preview-window='right:55%:wrap'
}

_argocd_build_flags() {
  local selections="$1"
  local flag value_type _description value row
  local -a rows

  _ARGOCD_FZF_FLAGS=()
  mapfile -t rows <<<"$selections"

  for row in "${rows[@]}"; do
    IFS='|' read -r flag value_type _description <<<"$row"
    [[ -n "$flag" && "$flag" != '__RUN__' ]] || continue

    if [[ -n "$value_type" ]]; then
      if ! read -e -r -p "Valeur pour ${flag} (${value_type}) : " value; then
        printf '\n' >&2
        return 1
      fi
      [[ -n "$value" ]] || {
        _argocd_fzf_error "${flag} ignorée : aucune valeur fournie."
        continue
      }
      _ARGOCD_FZF_FLAGS+=("$flag" "$value")
    else
      _ARGOCD_FZF_FLAGS+=("$flag")
    fi
  done
}

argocd_fzf() {
  local selections

  _argocd_fzf_require argocd fzf || return 1
  _argocd_choose_command || return
  (( ${#_ARGOCD_FZF_COMMAND[@]} > 0 )) || return

  _argocd_collect_arguments || return
  selections="$(_argocd_select_flags)" || return
  _argocd_build_flags "$selections" || return

  command argocd \
    "${_ARGOCD_FZF_COMMAND[@]}" \
    "${_ARGOCD_FZF_ARGUMENTS[@]}" \
    "${_ARGOCD_FZF_FLAGS[@]}" \
    "$@"
}
