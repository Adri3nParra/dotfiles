# Signets de dossiers compatibles avec l'ancien plugin Bashmarks.

: "${BASHMARKS_SDIRS:=${SDIRS:-$HOME/.sdirs}}"

_bashmarks_names() {
  [[ -r "$BASHMARKS_SDIRS" ]] || return 0
  sed -n 's/^export DIR_\([A-Za-z0-9_]*\)=.*/\1/p' "$BASHMARKS_SDIRS" | LC_ALL=C sort
}

_bashmarks_value() {
  local bookmark="$1" line

  line="$(command grep -E "^export DIR_${bookmark}=" "$BASHMARKS_SDIRS" 2>/dev/null | tail -1)"
  [[ -n "$line" ]] || return 1
  line="${line#*=}"
  line="${line#\"}"
  line="${line%\"}"
  print -r -- "${line/#\$HOME/$HOME}"
}

_bashmarks_valid_name() {
  [[ -n "$1" && "$1" != *[^A-Za-z0-9_]* ]] || {
    print -u2 'Le nom du signet doit contenir uniquement lettres, chiffres et underscore.'
    return 1
  }
}

_bashmarks_delete() {
  local bookmark="$1" temporary

  _bashmarks_valid_name "$bookmark" || return
  [[ -e "$BASHMARKS_SDIRS" ]] || return 0
  temporary="$(mktemp "${BASHMARKS_SDIRS}.XXXXXX")" || return
  command grep -Ev "^export DIR_${bookmark}=" "$BASHMARKS_SDIRS" >| "$temporary" || true
  command mv -f -- "$temporary" "$BASHMARKS_SDIRS"
}

bm() {
  local action="${1:-}" bookmark="${2:-}" target stored_path

  case "$action" in
    -a)
      _bashmarks_valid_name "$bookmark" || return
      mkdir -p -- "${BASHMARKS_SDIRS:h}"
      touch "$BASHMARKS_SDIRS"
      _bashmarks_delete "$bookmark" || return
      stored_path="${PWD/#$HOME/\$HOME}"
      printf 'export DIR_%s="%s"\n' "$bookmark" "$stored_path" >> "$BASHMARKS_SDIRS"
      ;;
    -g)
      target="$(_bashmarks_value "$bookmark")" || {
        print -u2 -- "Signet inconnu : $bookmark"
        return 1
      }
      [[ -d "$target" ]] || {
        print -u2 -- "Dossier introuvable : $target"
        return 1
      }
      cd -- "$target"
      ;;
    -p)
      _bashmarks_value "$bookmark"
      ;;
    -d)
      _bashmarks_delete "$bookmark"
      ;;
    -l)
      local name
      for name in "${(@f)$(_bashmarks_names)}"; do
        printf '\e[0;33m%-20s\e[0m %s\n' "$name" "$(_bashmarks_value "$name")"
      done
      ;;
    -h|--help|'')
      print 'Usage : bm [-a|-g|-p|-d] <nom> | bm -l'
      ;;
    -*)
      print -u2 -- "Option inconnue : $action"
      return 2
      ;;
    *)
      bm -g "$action"
      ;;
  esac
}

_bashmarks_completion() {
  local -a names
  names=("${(@f)$(_bashmarks_names)}")

  if (( CURRENT == 2 )); then
    _arguments \
      '(-a -g -p -d -l)-a[enregistrer le dossier courant]:nom du signet:' \
      '(-a -g -p -d -l)-g[aller au signet]:signet:($names)' \
      '(-a -g -p -d -l)-p[afficher le chemin]:signet:($names)' \
      '(-a -g -p -d -l)-d[supprimer le signet]:signet:($names)' \
      '(-a -g -p -d -l)-l[lister les signets]' \
      '1:signet:($names)'
  elif (( CURRENT == 3 )); then
    case "${words[2]}" in
      -g|-p|-d) _describe 'signet' names ;;
    esac
  fi
}

compdef _bashmarks_completion bm

alias s='bm -a'
alias g='bm -g'
alias p='bm -p'
alias d='bm -d'
