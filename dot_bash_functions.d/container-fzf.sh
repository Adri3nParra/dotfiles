# shellcheck shell=bash
# Docker et sécurité : conteneurs, images et scans Trivy/Cosign

_container_fzf_error() {
  printf '\ncontainer-fzf: %s\n' "$*" >&2
}

_container_fzf_choose_area() {
  local selected

  selected="$(
    printf '%s\n' \
      'containers|Conteneurs|Logs, shell, inspection, statistiques et cycle de vie' \
      'images|Images|Inspection, historique, scan Trivy et vérification Cosign' \
      'filesystem|Répertoire courant|Scanner les vulnérabilités, secrets et configurations' |
      fzf \
        --height='45%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=2,3.. \
        --prompt='Docker / sécurité > '
  )" || return
  printf '%s' "${selected%%|*}"
}

_container_fzf_containers() {
  local selected id name status image action answer

  selected="$(
    command docker ps --all --format '{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}' |
      fzf \
        --height='70%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=2,3,4,1 \
        --prompt='Conteneur > ' \
        --header='Nom · état · image · ID' \
        --preview='docker inspect {1} 2>/dev/null | jq . | head -160' \
        --preview-window='right:55%:wrap'
  )" || return
  [[ -n "$selected" ]] || return 1
  IFS='|' read -r id name status image <<<"$selected"

  action="$(
    printf '%s\n' \
      'logs|Suivre les logs' \
      'shell|Ouvrir un shell' \
      'inspect|Inspecter le conteneur' \
      'stats|Afficher les statistiques' \
      'start|Démarrer le conteneur' \
      'stop|Arrêter le conteneur' \
      'restart|Redémarrer le conteneur' \
      'remove|Supprimer le conteneur' |
      fzf \
        --height='55%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2.. \
        --prompt="Action pour ${name} > " \
        --header="${status} · ${image}"
  )" || return
  action="${action%%|*}"

  case "$action" in
    logs)    command docker logs --follow --tail 200 "$id" ;;
    shell)   command docker exec --interactive --tty "$id" sh ;;
    inspect) command docker inspect "$id" | jq . ;;
    stats)   command docker stats "$id" ;;
    start)   command docker start "$id" ;;
    stop)    command docker stop "$id" ;;
    restart) command docker restart "$id" ;;
    remove)
      read -r -p "Supprimer ${name} ? [y/N] " answer
      [[ "$answer" =~ ^[YyOo]$ ]] || return 1
      command docker rm "$id"
      ;;
    *) return 1 ;;
  esac
}

_container_fzf_images() {
  local selected id reference action answer

  selected="$(
    command docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}' |
      awk '!seen[$0]++' |
      fzf \
        --height='70%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=2,3,4,1 \
        --prompt='Image > ' \
        --header='Référence · taille · création · ID' \
        --preview='docker image inspect {1} 2>/dev/null | jq . | head -160' \
        --preview-window='right:55%:wrap'
  )" || return
  [[ -n "$selected" ]] || return 1
  IFS='|' read -r id reference _ <<<"$selected"

  action="$(
    printf '%s\n' \
      "inspect|Inspecter l'image" \
      'history|Afficher son historique' \
      'scan|Scanner avec Trivy' \
      'verify|Vérifier la signature Cosign' \
      "remove|Supprimer l'image locale" |
      fzf \
        --height='50%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2.. \
        --prompt="Action pour ${reference} > "
  )" || return
  action="${action%%|*}"

  case "$action" in
    inspect) command docker image inspect "$id" | jq . ;;
    history) command docker history "$id" ;;
    scan)
      command -v trivy >/dev/null 2>&1 || {
        _container_fzf_error 'trivy est introuvable.'
        return 1
      }
      command trivy image "$reference"
      ;;
    verify)
      command -v cosign >/dev/null 2>&1 || {
        _container_fzf_error 'cosign est introuvable.'
        return 1
      }
      [[ "$reference" != '<none>:<none>' ]] || {
        _container_fzf_error 'cette image ne possède pas de référence vérifiable.'
        return 1
      }
      command cosign verify "$reference"
      ;;
    remove)
      read -r -p "Supprimer l’image ${reference} ? [y/N] " answer
      [[ "$answer" =~ ^[YyOo]$ ]] || return 1
      command docker image rm "$id"
      ;;
    *) return 1 ;;
  esac
}

_container_fzf_filesystem() {
  local action

  command -v trivy >/dev/null 2>&1 || {
    _container_fzf_error 'trivy est introuvable.'
    return 1
  }
  action="$(
    printf '%s\n' \
      'filesystem|Vulnérabilités et secrets du répertoire' \
      'config|Mauvaises configurations IaC' \
      'repository|Scanner le dépôt comme repository' |
      fzf \
        --height='40%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2.. \
        --prompt='Scan Trivy > '
  )" || return
  action="${action%%|*}"
  command trivy "$action" .
}

container_fzf() {
  local area

  for executable in docker fzf jq; do
    command -v "$executable" >/dev/null 2>&1 || {
      _container_fzf_error "${executable} est introuvable."
      return 1
    }
  done

  area="$(_container_fzf_choose_area)" || return
  case "$area" in
    containers) _container_fzf_containers "$@" ;;
    images)      _container_fzf_images "$@" ;;
    filesystem)  _container_fzf_filesystem "$@" ;;
    *) return 1 ;;
  esac
}
