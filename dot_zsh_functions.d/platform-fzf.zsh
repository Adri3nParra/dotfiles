# Menu central des outils Platform/FZF.

platform_fzf() {
  local selection action

  command -v fzf >/dev/null 2>&1 || {
    print -u2 'fzf est introuvable.'
    return 127
  }

  selection="$(
    printf '%s\n' \
      'aws_fzf|AWS|Inventaire et construction de commandes AWS' \
      'argocd_fzf|Argo CD|Applications, projets, clusters et options' \
      'rollouts_fzf|Argo Rollouts|Suivi et pilotage des rollouts' \
      'gitlab_fzf|GitLab CI|Pipelines, jobs et traces' \
      'container_fzf|Conteneurs|Docker, images, Trivy et Cosign' \
      'iac_fzf|IaC|OpenTofu et Terragrunt' \
      'ansible_fzf|Ansible|Playbooks et actions' |
      fzf \
        --height='55%' \
        --layout=reverse \
        --border \
        --info=inline \
        --delimiter='|' \
        --with-nth=2,3.. \
        --prompt='Platform > '
  )" || return

  action="${selection%%|*}"
  (( $+functions[$action] )) || {
    print -u2 -- "Fonction introuvable : $action"
    return 127
  }
  "$action" "$@"
}

_platform_fzf_widget() {
  platform_fzf
  zle reset-prompt
}

if [[ -o interactive ]]; then
  zle -N _platform_fzf_widget
  bindkey '^X^P' _platform_fzf_widget
fi
