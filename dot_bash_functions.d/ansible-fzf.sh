# shellcheck shell=bash
# Ansible : playbook -> action

_ansible_fzf_error() {
  printf '\nansible-fzf: %s\n' "$*" >&2
}

_ansible_fzf_playbooks() {
  rg -l \
    '^[[:space:]]*-[[:space:]]*(name:.*)?$|^[[:space:]]*hosts:' \
    -g '*.yml' -g '*.yaml' \
    -g '!**/roles/**' \
    -g '!**/.galaxy/**' \
    -g '!**/collections/**' 2>/dev/null |
    LC_ALL=C sort -u
}

ansible_fzf() {
  local playbook action answer

  for executable in ansible-playbook fzf rg; do
    command -v "$executable" >/dev/null 2>&1 || {
      _ansible_fzf_error "${executable} est introuvable."
      return 1
    }
  done

  playbook="$(
    _ansible_fzf_playbooks |
      fzf \
        --height='70%' \
        --layout=reverse \
        --border \
        --info=inline \
        --prompt='Playbook Ansible > ' \
        --header='Recherche depuis le répertoire courant' \
        --preview='sed -n "1,180p" {}' \
        --preview-window='right:60%:wrap'
  )" || return
  [[ -n "$playbook" ]] || {
    _ansible_fzf_error 'aucun playbook trouvé.'
    return 1
  }

  action="$(
    printf '%s\n' \
      'syntax|Vérifier la syntaxe' \
      'check|Simuler avec --check' \
      'check-diff|Simuler avec --check --diff' \
      'list-hosts|Afficher les hôtes ciblés' \
      'list-tags|Afficher les tags disponibles' \
      'run|Exécuter le playbook' |
      fzf \
        --height='50%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=1,2.. \
        --prompt='Action Ansible > ' \
        --header="$playbook"
  )" || return
  action="${action%%|*}"

  case "$action" in
    syntax)     command ansible-playbook "$playbook" --syntax-check "$@" ;;
    check)      command ansible-playbook "$playbook" --check "$@" ;;
    check-diff) command ansible-playbook "$playbook" --check --diff "$@" ;;
    list-hosts) command ansible-playbook "$playbook" --list-hosts "$@" ;;
    list-tags)  command ansible-playbook "$playbook" --list-tags "$@" ;;
    run)
      read -r -p "Exécuter ${playbook} réellement ? [y/N] " answer
      [[ "$answer" =~ ^[YyOo]$ ]] || return 1
      command ansible-playbook "$playbook" "$@"
      ;;
    *) return 1 ;;
  esac
}
