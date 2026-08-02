# ─────────────────────────────────────────────
# AWS CLI + FZF
# Raccourci : Ctrl+G
# ─────────────────────────────────────────────

_aws_completions() {
  local line="$1"

  COMP_LINE="$line" \
  COMP_POINT="${#line}" \
    aws_completer 2>/dev/null |
    sed 's/[[:space:]]*$//' |
    awk 'NF && !seen[$0]++'
}

_aws_fzf_widget() {
  local service
  local operation
  local command

  command -v aws >/dev/null 2>&1 || {
    printf '\nAWS CLI introuvable.\n' >&2
    return 1
  }

  command -v aws_completer >/dev/null 2>&1 || {
    printf '\naws_completer introuvable.\n' >&2
    return 1
  }

  command -v fzf >/dev/null 2>&1 || {
    printf '\nfzf introuvable.\n' >&2
    return 1
  }

  service="$(
    _aws_completions 'aws ' |
      grep -vE '^(--|help$)' |
      fzf \
        --prompt='AWS service > ' \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline
  )" || return

  operation="$(
    _aws_completions "aws ${service} " |
      grep -vE '^(--|help$)' |
      fzf \
        --prompt="aws ${service} > " \
        --height='60%' \
        --layout=reverse \
        --border \
        --info=inline \
        --preview="
          AWS_PAGER='' \
          AWS_CLI_COLOR=off \
          GROFF_NO_SGR=1 \
          TERM=dumb \
            aws ${service} {} help 2>/dev/null |
            col -bx |
            head -100
        " \
        --preview-window='right:60%:wrap'
  )" || return

  command="aws ${service} ${operation} "

  READLINE_LINE="${READLINE_LINE:0:READLINE_POINT}${command}${READLINE_LINE:READLINE_POINT}"
  READLINE_POINT=$((READLINE_POINT + ${#command}))
}

bind -x '"\C-g":_aws_fzf_widget'
