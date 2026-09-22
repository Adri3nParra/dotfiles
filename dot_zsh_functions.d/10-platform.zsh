# Fonctions Zsh — Kubernetes, IaC et registres.
# Complète 00-core.zsh : uniquement ce que les CLI n'offrent pas en une commande.

# ─────────────────────────────────────────────
# KUBERNETES
# ─────────────────────────────────────────────

kevents() {
  [[ "$1" == "-h" ]] && _usage "kevents" "événements récents triés par date" "kevents [-w] [namespace]" && return 0
  _require_command kubectl || return

  local warnings_only=false
  if [[ "$1" == "-w" ]]; then
    warnings_only=true
    shift
  fi

  local ns="${1:--A}"
  local -a scope=(-A)
  [[ "$ns" == "-A" ]] || scope=(-n "$ns")
  [[ "$warnings_only" == true ]] && scope+=(--field-selector=type=Warning)

  # `lastTimestamp` est vide pour les events de l'API events.k8s.io : trier sur
  # la date de création reste fiable sur tous les clusters.
  kubectl get events "${scope[@]}" \
    --sort-by=.metadata.creationTimestamp \
    -o custom-columns='TIME:.metadata.creationTimestamp,NS:.metadata.namespace,TYPE:.type,REASON:.reason,KIND:.involvedObject.kind,OBJET:.involvedObject.name,MESSAGE:.message'
}

ktriage() {
  [[ "$1" == "-h" ]] && _usage "ktriage" "ce qui ne tourne pas, avec la raison" "ktriage [namespace]" && return 0
  _require_command kubectl jq || return

  local ns="${1:--A}"
  local -a scope=(-A)
  [[ "$ns" == "-A" ]] || scope=(-n "$ns")

  local output
  output="$(
    kubectl get pods "${scope[@]}" -o json |
      jq -r '
        .items[]
        | . as $pod
        | (($pod.status.containerStatuses // []) + ($pod.status.initContainerStatuses // [])) as $all
        | ($pod.status.containerStatuses // []) as $main
        | ($main | map(select(.ready)) | length) as $ready
        | ($main | length) as $total
        | ($main | map(.restartCount // 0) | add // 0) as $restarts
        # Un initContainer termine avec succes affiche `Completed` : ce nest pas
        # un symptome. Seuls les etats bloquants ou en echec sont retenus.
        | [ $all[]
            | if   .state.waiting != null then .state.waiting.reason
              elif (.state.terminated != null and .state.terminated.exitCode != 0)
                then (.state.terminated.reason // "Error")
              else empty end
          ] as $reasons
        # Un pod Succeeded est un Job termine : ce nest pas une anomalie.
        | select($pod.status.phase != "Succeeded")
        | select($pod.status.phase != "Running" or $ready < $total or ($reasons | length) > 0)
        | [ $pod.metadata.namespace,
            $pod.metadata.name,
            $pod.status.phase,
            "\($ready)/\($total)",
            ($restarts | tostring),
            (($reasons | unique | join(",")) | if . == "" then "-" else . end),
            ($pod.spec.nodeName // "-")
          ]
        | @tsv
      '
  )" || return

  if [[ -z "$output" ]]; then
    printf '✓ Aucun pod en anomalie.\n'
    return 0
  fi

  { printf 'NS\tPOD\tPHASE\tPRÊT\tRESTARTS\tRAISON\tNŒUD\n'; printf '%s\n' "$output" } |
    column -t -s $'\t'
}

kyaml() {
  [[ "$1" == "-h" ]] && _usage "kyaml" "YAML épuré d'une ressource via fzf" "kyaml [type] [namespace]" && return 0
  _require_command kubectl fzf yq || return

  local kind="${1:-}" ns="${2:--A}"

  if [[ -z "$kind" ]]; then
    kind="$(
      kubectl api-resources --verbs=get --no-headers 2>/dev/null |
        awk '{print $1}' | LC_ALL=C sort -u |
        fzf --prompt='type > ' --height='50%' --layout=reverse --border
    )" || return 0
  fi
  [[ -n "$kind" ]] || return 0

  local -a scope=(-A)
  [[ "$ns" == "-A" ]] || scope=(-n "$ns")

  local selected
  selected="$(
    kubectl get "$kind" "${scope[@]}" --no-headers \
      -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name 2>/dev/null |
      fzf --prompt="$kind > " --height='60%' --layout=reverse --border |
      awk '{print $1"|"$2}'
  )" || return 0
  [[ -n "$selected" ]] || return 0

  local object_ns="${selected%%|*}" name="${selected##*|}"
  local -a target
  # Les ressources non namespacées affichent `<none>` dans la colonne NS.
  if [[ -z "$object_ns" || "$object_ns" == "<none>" ]]; then
    target=("$kind" "$name")
  else
    target=("$kind" "$name" -n "$object_ns")
  fi

  # Retire tout ce que l'API ajoute et qu'on ne veut ni lire ni réappliquer.
  kubectl get "${target[@]}" -o yaml |
    yq '
      del(.metadata.managedFields) |
      del(.metadata.resourceVersion) |
      del(.metadata.uid) |
      del(.metadata.generation) |
      del(.metadata.creationTimestamp) |
      del(.metadata.selfLink) |
      del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
      del(.status)
    '
}

kcapacity() {
  [[ "$1" == "-h" ]] && _usage "kcapacity" "requests vs allocatable par nœud" "kcapacity" && return 0
  _require_command kubectl jq || return

  {
    kubectl get nodes -o json || return
    kubectl get pods -A -o json || return
  } | jq -rs '
    def cpu($v):
      if $v == null then 0
      elif ($v | tostring | test("m$")) then ($v | tostring | rtrimstr("m") | tonumber)
      else (($v | tostring | tonumber) * 1000) end;
    def mem($v):
      if $v == null then 0 else ($v | tostring) as $s |
        if   ($s | test("Ki$")) then ($s | rtrimstr("Ki") | tonumber) * 1024
        elif ($s | test("Mi$")) then ($s | rtrimstr("Mi") | tonumber) * 1048576
        elif ($s | test("Gi$")) then ($s | rtrimstr("Gi") | tonumber) * 1073741824
        elif ($s | test("Ti$")) then ($s | rtrimstr("Ti") | tonumber) * 1099511627776
        elif ($s | test("k$"))  then ($s | rtrimstr("k")  | tonumber) * 1000
        elif ($s | test("M$"))  then ($s | rtrimstr("M")  | tonumber) * 1000000
        elif ($s | test("G$"))  then ($s | rtrimstr("G")  | tonumber) * 1000000000
        else ($s | tonumber) end
      end;
    def pct($used; $total): if $total == 0 then "-" else "\(($used * 100 / $total) | round)%" end;
    def gib($bytes): "\((($bytes / 1073741824) * 10 | round) / 10)Gi";

    .[0].items as $nodes
    | .[1].items as $pods
    | $nodes[]
    | .metadata.name as $node
    | (.status.allocatable // {}) as $alloc
    # Les pods termines ne reservent plus rien sur le noeud.
    | ($pods | map(select(.spec.nodeName == $node and (.status.phase != "Succeeded") and (.status.phase != "Failed")))) as $on_node
    | ($on_node | map([(.spec.containers // [])[] | cpu(.resources.requests.cpu)] | add // 0) | add // 0) as $cpu_req
    | ($on_node | map([(.spec.containers // [])[] | mem(.resources.requests.memory)] | add // 0) | add // 0) as $mem_req
    | (cpu($alloc.cpu)) as $cpu_alloc
    | (mem($alloc.memory)) as $mem_alloc
    | [ $node,
        "\($on_node | length)/\($alloc.pods // "?")",
        "\(($cpu_req / 1000 * 10 | round) / 10)/\($cpu_alloc / 1000)",
        pct($cpu_req; $cpu_alloc),
        "\(gib($mem_req))/\(gib($mem_alloc))",
        pct($mem_req; $mem_alloc)
      ]
    | @tsv
  ' | {
    printf 'NŒUD\tPODS\tCPU req/alloc\tCPU%%\tMEM req/alloc\tMEM%%\n'
    cat
  } | column -t -s $'\t'
}

# ─────────────────────────────────────────────
# IAC ET REGISTRES
# ─────────────────────────────────────────────

tfclean() {
  [[ "$1" == "-h" ]] && _usage "tfclean" "purge les caches .terraform et .terragrunt-cache" "tfclean [-f] [répertoire]" && return 0

  local force=false
  if [[ "$1" == "-f" ]]; then
    force=true
    shift
  fi

  local root="${1:-.}"
  [[ -d "$root" ]] || {
    printf 'Répertoire introuvable : %s\n' "$root" >&2
    return 2
  }

  local -a caches
  caches=("$root"/**/.terraform(N/) "$root"/**/.terragrunt-cache(N/))
  (( ${#caches} )) || {
    printf 'Aucun cache à purger sous %s.\n' "$root"
    return 0
  }

  local total
  total="$(du -sh --total -- "${caches[@]}" 2>/dev/null | tail -1 | awk '{print $1}')"
  printf '%d cache(s), %s à libérer :\n' "${#caches}" "${total:-?}"
  printf '  %s\n' "${caches[@]}"

  if [[ "$force" != true ]]; then
    local answer
    read -r "answer?Supprimer ? [y/N] "
    [[ "$answer" == [yY] ]] || {
      printf 'Annulé.\n'
      return 1
    }
  fi

  command rm -rf -- "${caches[@]}" && printf '✓ %s libérés.\n' "${total:-?}"
}

imgtags() {
  [[ "$1" == "-h" ]] && _usage "imgtags" "tags d'une image distante sans la tirer" "imgtags <image> [filtre]" && return 0
  _require_args 1 "$@" || return
  _require_command skopeo jq || return

  local image="$1" filter="${2:-}"
  # `skopeo` veut un transport explicite ; on accepte `nginx` comme `docker.io/nginx`.
  [[ "$image" == *://* ]] || image="docker://$image"

  local tags
  tags="$(skopeo list-tags "$image" 2>&1)" || {
    printf '%s\n' "$tags" >&2
    return 1
  }

  printf '%s\n' "$tags" | jq -r '.Tags[]' |
    { [[ -n "$filter" ]] && command grep -- "$filter" || cat } |
    LC_ALL=C sort -V
}

# ─────────────────────────────────────────────
# DIVERS
# ─────────────────────────────────────────────

_jwt_decode_segment() {
  local segment="${1//-/+}"
  segment="${segment//_//}"

  # base64url omet le remplissage, que `base64 -d` exige.
  local missing=$(( (4 - ${#segment} % 4) % 4 ))
  (( missing )) && segment+="${(l:$missing::=:)}"

  printf '%s' "$segment" | base64 -d 2>/dev/null
}

jwt() {
  [[ "$1" == "-h" ]] && _usage "jwt" "décode un JSON Web Token" "jwt [token]" && return 0
  _require_command jq || return

  local token="${1:-}"
  [[ -n "$token" ]] || token="$(cat)"
  token="${token#Bearer }"
  token="${token//[[:space:]]/}"

  local -a segments
  segments=(${(s:.:)token})
  (( ${#segments} >= 2 )) || {
    printf 'Ceci ne ressemble pas à un JWT (il faut au moins deux segments).\n' >&2
    return 2
  }

  local header payload
  header="$(_jwt_decode_segment "${segments[1]}")"
  payload="$(_jwt_decode_segment "${segments[2]}")"

  printf '\e[36m── header\e[0m\n'
  printf '%s' "$header" | jq . || { printf '%s\n' "$header"; return 1 }
  printf '\e[36m── payload\e[0m\n'
  printf '%s' "$payload" | jq . || { printf '%s\n' "$payload"; return 1 }

  # Les dates Unix des claims standards sont illisibles telles quelles.
  local claim value
  for claim in iat nbf exp; do
    value="$(printf '%s' "$payload" | jq -r --arg c "$claim" '.[$c] // empty' 2>/dev/null)"
    [[ -n "$value" ]] || continue
    printf '\e[90m%-4s %s\e[0m' "$claim" "$(date -d "@$value" '+%d/%m/%Y %H:%M:%S' 2>/dev/null)"
    if [[ "$claim" == exp ]]; then
      (( value < $(date +%s) )) && printf '\e[31m  (expiré)\e[0m' || printf '\e[32m  (valide)\e[0m'
    fi
    printf '\n'
  done
}
