# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# AWS CLI, en plus humain
#
#   Ctrl+G   construit ou complète une commande AWS avec fzf
#   aws_fzf  inventaire rapide ou parcours service -> opération -> options
#   awsi     ouvre l'auto-prompt AWS (pratique pour les valeurs des options)
#   awsp     choisit le profil AWS courant
#   awsctx   affiche le contexte et l'identité AWS courants
# ─────────────────────────────────────────────────────────────────────────────

_aws_fzf_error() {
  printf '\naws-fzf: %s\n' "$*" >&2
}

_aws_fzf_require() {
  local executable

  for executable in "$@"; do
    command -v "$executable" >/dev/null 2>&1 || {
      _aws_fzf_error "${executable} est introuvable."
      return 1
    }
  done
}

_aws_fzf_context() {
  local profile region

  profile="${AWS_PROFILE:-default}"
  region="${AWS_REGION:-${AWS_DEFAULT_REGION:-auto}}"
  printf 'Profil: %s  ·  Région: %s' "$profile" "$region"
}

_aws_completions() {
  local line="$1"

  COMP_LINE="$line" \
  COMP_POINT="${#line}" \
    aws_completer 2>/dev/null |
    sed 's/[[:space:]]*$//' |
    awk 'NF && !seen[$0]++' |
    LC_ALL=C sort
}

_aws_fzf_pick() {
  local prompt="$1"
  local preview="${2:-}"
  local -a options

  options=(
    --prompt="$prompt"
    --height='70%'
    --layout=reverse
    --border
    --info=inline
    --cycle
    --header="$(_aws_fzf_context)  ·  Entrée: choisir  ·  Échap: annuler"
  )

  if [[ -n "$preview" ]]; then
    options+=(
      --preview="$preview"
      --preview-window='right:60%:wrap'
    )
  fi

  fzf "${options[@]}"
}

_aws_fzf_new_command() {
  local service operation

  service="$(
    _aws_completions 'aws ' |
      grep -vE '^(--|help$)' |
      _aws_fzf_pick \
        'Service AWS > ' \
        "AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws {} help 2>/dev/null | col -bx | head -120"
  )" || return

  [[ -n "$service" ]] || return 1

  operation="$(
    _aws_completions "aws ${service} " |
      grep -vE '^(--|help$)' |
      _aws_fzf_pick \
        "aws ${service} > " \
        "AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws ${service} {} help 2>/dev/null | col -bx | head -120"
  )" || return

  [[ -n "$operation" ]] || return 1
  printf 'aws %s %s ' "$service" "$operation"
}

_aws_fzf_command_words() {
  local line="$1"
  local -a words

  # Les noms de services et d'opérations AWS ne contiennent pas d'espaces.
  # Ce découpage ne sert qu'à déterminer le libellé et l'aide à afficher.
  read -r -a words <<<"$line"
  printf '%s\n' "${words[@]}"
}

_aws_fzf_continue_command() {
  local line="$1"
  local service operation prompt preview selected
  local -a words

  mapfile -t words < <(_aws_fzf_command_words "$line")
  service="${words[1]:-}"
  operation="${words[2]:-}"

  if (( ${#words[@]} <= 1 )) ||
    (( ${#words[@]} == 2 )) && [[ "$line" != *[[:space:]] ]]; then
    prompt='Service AWS > '
    preview="AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws {} help 2>/dev/null | col -bx | head -120"
  elif (( ${#words[@]} == 2 )) ||
    (( ${#words[@]} == 3 )) && [[ "$line" != *[[:space:]] ]]; then
    prompt="aws ${service} > "
    if [[ "$service" =~ ^[a-z0-9-]+$ ]]; then
      preview="AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws ${service} {} help 2>/dev/null | col -bx | head -120"
    fi
  else
    prompt="Option pour ${service} ${operation} > "
    if [[ "$service" =~ ^[a-z0-9-]+$ && "$operation" =~ ^[a-z0-9-]+$ ]]; then
      preview="AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws ${service} ${operation} help 2>/dev/null | col -bx | head -160"
    fi
  fi

  selected="$(_aws_completions "$line" | _aws_fzf_pick "$prompt" "$preview")" || return
  [[ -n "$selected" ]] || return 1
  printf '%s' "$selected"
}

_aws_fzf_insert_completion() {
  local left="$1" completion="$2"
  local token_start

  if [[ "$left" == *[[:space:]] ]]; then
    printf '%s%s ' "$left" "$completion"
    return
  fi

  token_start="${left%"${left##*[[:space:]]}"}"
  printf '%s%s ' "$token_start" "$completion"
}

_aws_fzf_widget() {
  local left right command completion mode new_left trimmed_left

  _aws_fzf_require aws aws_completer fzf || return 1

  left="${READLINE_LINE:0:READLINE_POINT}"
  right="${READLINE_LINE:READLINE_POINT}"
  trimmed_left="${left#"${left%%[![:space:]]*}"}"

  if [[ "$trimmed_left" == aws || "$trimmed_left" == aws[[:space:]]* ]]; then
    completion="$(_aws_fzf_continue_command "$trimmed_left")" || return
    new_left="$(_aws_fzf_insert_completion "$left" "$completion")"
  else
    mode="$(_aws_fzf_main_menu)" || return
    if [[ "$mode" == 'inventory' ]]; then
      _aws_fzf_run_inventory
      return
    fi

    command="$(_aws_fzf_new_command)" || return
    new_left="${left}${command}"
  fi

  READLINE_LINE="${new_left}${right}"
  READLINE_POINT="${#new_left}"
}

_aws_fzf_select_service_operation() {
  local service operation

  service="$(
    _aws_completions 'aws ' |
      grep -vE '^(--|help$)' |
      _aws_fzf_pick \
        'Service AWS > ' \
        "AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws {} help 2>/dev/null | col -bx | head -120"
  )" || return
  [[ -n "$service" ]] || return 1

  operation="$(
    _aws_completions "aws ${service} " |
      grep -vE '^(--|help$)' |
      _aws_fzf_pick \
        "Opération ${service} > " \
        "AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws ${service} {} help 2>/dev/null | col -bx | head -120"
  )" || return
  [[ -n "$operation" ]] || return 1

  _AWS_FZF_SERVICE="$service"
  _AWS_FZF_OPERATION="$operation"
}

_aws_fzf_operation_options() {
  local service="$1" operation="$2"

  _aws_completions "aws ${service} ${operation} " |
    awk '/^--/ && $0 != "--help" && !seen[$0]++'
}

_aws_fzf_select_options() {
  local service="$1" operation="$2" rows
  local -a fzf_options

  rows="$(_aws_fzf_operation_options "$service" "$operation")" || return
  [[ -n "$rows" ]] || return 0
  mapfile -t fzf_options < <(
    printf '%s\n' \
      '--height=70%' \
      '--layout=reverse' \
      '--border' \
      '--info=inline' \
      '--cycle'
  )

  {
    printf '▶ Exécuter sans option\n'
    printf '%s\n' "$rows"
  } | fzf \
    "${fzf_options[@]}" \
    --multi \
    --prompt="Options pour ${service} ${operation} > " \
    --header="$(_aws_fzf_context)  ·  Espace/Tab : cocher  ·  Entrée : valider" \
    --bind='space:toggle+down,tab:toggle+down' \
    --preview="AWS_PAGER='' AWS_CLI_COLOR=off GROFF_NO_SGR=1 TERM=dumb aws ${service} ${operation} help 2>/dev/null | col -bx | head -180" \
    --preview-window='right:60%:wrap'
}

_aws_fzf_option_needs_value() {
  local service="$1" operation="$2" option="$3" opposite

  case "$option" in
    --debug|--no-verify-ssl|--no-paginate|--no-sign-request|--no-cli-pager|--cli-auto-prompt|--no-cli-auto-prompt)
      return 1
      ;;
    --no-*)
      return 1
      ;;
  esac

  opposite="--no-${option#--}"
  if _aws_fzf_operation_options "$service" "$operation" |
    grep -Fqx -- "$opposite"; then
    return 1
  fi

  return 0
}

_aws_fzf_choose_known_value() {
  local option="$1"

  case "$option" in
    --output)
      printf '%s\n' json yaml yaml-stream text table |
        _aws_fzf_pick 'Format de sortie > '
      ;;
    --color)
      printf '%s\n' auto on off |
        _aws_fzf_pick 'Couleur > '
      ;;
    --cli-binary-format)
      printf '%s\n' base64 raw-in-base64-out |
        _aws_fzf_pick 'Format binaire > '
      ;;
    --profile)
      command aws configure list-profiles 2>/dev/null |
        awk 'NF && !seen[$0]++' |
        _aws_fzf_pick 'Profil AWS > '
      ;;
    *)
      return 1
      ;;
  esac
}

_aws_fzf_build_options() {
  local service="$1" operation="$2" selections="$3"
  local option value
  local -a selected_options

  _AWS_FZF_OPTIONS=()
  mapfile -t selected_options <<<"$selections"

  for option in "${selected_options[@]}"; do
    [[ -n "$option" && "$option" == --* ]] || continue

    if _aws_fzf_option_needs_value "$service" "$operation" "$option"; then
      case "$option" in
        --output|--color|--cli-binary-format|--profile)
          value="$(_aws_fzf_choose_known_value "$option")" || return
          ;;
        *)
        if ! read -e -r -p "Valeur pour ${option} : " value; then
          printf '\n' >&2
          return 1
        fi
          ;;
      esac

      if [[ -z "$value" ]]; then
        _aws_fzf_error "${option} ignorée : aucune valeur fournie."
        continue
      fi
      _AWS_FZF_OPTIONS+=("$option" "$value")
    else
      _AWS_FZF_OPTIONS+=("$option")
    fi
  done
}

_aws_fzf_confirm_sensitive_operation() {
  local operation="$1" answer

  case "$operation" in
    delete-*|deregister-*|disable-*|remove-*|revoke-*|stop-*|terminate-*)
      read -r -p "Opération sensible (${operation}). Continuer ? [y/N] " answer
      [[ "$answer" =~ ^[YyOo]$ ]]
      ;;
    *)
      return 0
      ;;
  esac
}

_aws_fzf_main_menu() {
  local selection
  local -a options

  options=(
    --height='40%'
    --layout=reverse
    --border
    --info=inline
    --delimiter='|'
    '--with-nth=2,3..'
    --prompt='AWS > '
    --header="$(_aws_fzf_context)  ·  Entrée : choisir  ·  Échap : annuler"
  )

  selection="$(
    printf '%s\n' \
      'inventory|Inventaire rapide|Les ressources courantes dans des tableaux lisibles' \
      'complete|CLI complète|Tous les services, opérations et paramètres AWS' |
      fzf "${options[@]}"
  )" || return

  [[ -n "$selection" ]] || return 1
  printf '%s' "${selection%%|*}"
}

_aws_fzf_inventory_menu() {
  local selection
  local -a options

  options=(
    --height='65%'
    --layout=reverse
    --border
    --info=inline
    --cycle
    --delimiter='|'
    '--with-nth=2,3..'
    --prompt='Inventaire AWS > '
    --header="$(_aws_fzf_context)  ·  Entrée : afficher  ·  Échap : annuler"
  )

  selection="$(
    printf '%s\n' \
      'identity|Compte et identité|Compte, utilisateur ou rôle actuellement utilisé' \
      'rds|Bases RDS|Moteur, version, état, classe et endpoint' \
      's3|Buckets S3|Nom et date de création' \
      'ecs|Clusters ECS|ARN des clusters accessibles' \
      'eks|Clusters EKS|Nom des clusters accessibles' \
      'lambda|Fonctions Lambda|Runtime, état, mémoire et dernière modification' \
      'ec2|Instances EC2|Nom, ID, état, type, adresses IP et zone' \
      'secrets|Secrets Manager|Nom, description et dernière modification' \
      'cloudformation|Stacks CloudFormation|État, création et dernière mise à jour' \
      'iam|Utilisateurs IAM|Création et dernière connexion' |
      LC_ALL=C sort -t '|' -k2,2 |
      fzf "${options[@]}"
  )" || return

  [[ -n "$selection" ]] || return 1
  printf '%s' "${selection%%|*}"
}

_aws_fzf_inventory_definition() {
  local inventory="$1"

  case "$inventory" in
    identity)
      _AWS_FZF_INVENTORY_COMMAND=(sts get-caller-identity)
      _AWS_FZF_INVENTORY_QUERY='{Compte:Account,Utilisateur:UserId,ARN:Arn}'
      ;;
    ec2)
      _AWS_FZF_INVENTORY_COMMAND=(ec2 describe-instances)
      _AWS_FZF_INVENTORY_QUERY="Reservations[].Instances[].{Nom:Tags[?Key=='Name']|[0].Value,ID:InstanceId,Etat:State.Name,Type:InstanceType,IPPrivee:PrivateIpAddress,IPPublique:PublicIpAddress,Zone:Placement.AvailabilityZone}"
      ;;
    s3)
      _AWS_FZF_INVENTORY_COMMAND=(s3api list-buckets)
      _AWS_FZF_INVENTORY_QUERY='Buckets[].{Nom:Name,Creation:CreationDate}'
      ;;
    rds)
      _AWS_FZF_INVENTORY_COMMAND=(rds describe-db-instances)
      _AWS_FZF_INVENTORY_QUERY='DBInstances[].{Nom:DBInstanceIdentifier,Moteur:Engine,Version:EngineVersion,Etat:DBInstanceStatus,Classe:DBInstanceClass,Endpoint:Endpoint.Address}'
      ;;
    eks)
      _AWS_FZF_INVENTORY_COMMAND=(eks list-clusters)
      _AWS_FZF_INVENTORY_QUERY='clusters[].{Nom:@}'
      ;;
    ecs)
      _AWS_FZF_INVENTORY_COMMAND=(ecs list-clusters)
      _AWS_FZF_INVENTORY_QUERY='clusterArns[].{Cluster:@}'
      ;;
    lambda)
      _AWS_FZF_INVENTORY_COMMAND=(lambda list-functions)
      _AWS_FZF_INVENTORY_QUERY='Functions[].{Nom:FunctionName,Runtime:Runtime,Etat:State,Memoire:MemorySize,DerniereModification:LastModified}'
      ;;
    cloudformation)
      _AWS_FZF_INVENTORY_COMMAND=(cloudformation describe-stacks)
      _AWS_FZF_INVENTORY_QUERY='Stacks[].{Nom:StackName,Etat:StackStatus,Creation:CreationTime,DerniereModification:LastUpdatedTime}'
      ;;
    iam)
      _AWS_FZF_INVENTORY_COMMAND=(iam list-users)
      _AWS_FZF_INVENTORY_QUERY='Users[].{Nom:UserName,Creation:CreateDate,DerniereConnexion:PasswordLastUsed}'
      ;;
    secrets)
      _AWS_FZF_INVENTORY_COMMAND=(secretsmanager list-secrets)
      _AWS_FZF_INVENTORY_QUERY='SecretList[].{Nom:Name,Description:Description,DerniereModification:LastChangedDate}'
      ;;
    *)
      _aws_fzf_error "inventaire inconnu : ${inventory}."
      return 1
      ;;
  esac
}

_aws_fzf_run_inventory() {
  local inventory

  inventory="$(_aws_fzf_inventory_menu)" || return
  _aws_fzf_inventory_definition "$inventory" || return

  AWS_PAGER='' command aws \
    "${_AWS_FZF_INVENTORY_COMMAND[@]}" \
    --query "$_AWS_FZF_INVENTORY_QUERY" \
    --output table \
    "$@"
}

# Navigateur complet, similaire à argocd_fzf. Les arguments donnés à la
# fonction sont ajoutés à la fin de la commande pour les cas très spécifiques.
aws_fzf() {
  local mode selections

  _aws_fzf_require aws aws_completer fzf || return 1
  mode="$(_aws_fzf_main_menu)" || return

  if [[ "$mode" == 'inventory' ]]; then
    _aws_fzf_run_inventory "$@"
    return
  fi

  _aws_fzf_select_service_operation || return

  selections="$(
    _aws_fzf_select_options "$_AWS_FZF_SERVICE" "$_AWS_FZF_OPERATION"
  )" || return
  _aws_fzf_build_options \
    "$_AWS_FZF_SERVICE" \
    "$_AWS_FZF_OPERATION" \
    "$selections" || return

  _aws_fzf_confirm_sensitive_operation "$_AWS_FZF_OPERATION" || {
    _aws_fzf_error 'opération annulée.'
    return 1
  }

  AWS_PAGER='' command aws \
    "$_AWS_FZF_SERVICE" \
    "$_AWS_FZF_OPERATION" \
    "${_AWS_FZF_OPTIONS[@]}" \
    "$@"
}

# Lance le prompt interactif officiel de la CLI AWS v2. Les arguments déjà
# connus peuvent être fournis, par exemple : awsi ec2 describe-instances.
awsi() {
  _aws_fzf_require aws || return 1
  AWS_CLI_AUTO_PROMPT=on AWS_PAGER='' command aws "$@"
}

# Sélectionne un profil pour le shell courant. Un argument permet aussi de le
# choisir directement : awsp production.
awsp() {
  local profile="${1:-}"

  _aws_fzf_require aws || return 1

  if [[ -z "$profile" ]]; then
    _aws_fzf_require fzf || return 1
    profile="$(
      command aws configure list-profiles 2>/dev/null |
        awk 'NF && !seen[$0]++' |
        _aws_fzf_pick 'Profil AWS > '
    )" || return
  fi

  [[ -n "$profile" ]] || return 1
  export AWS_PROFILE="$profile"
  printf 'Profil AWS actif : %s\n' "$AWS_PROFILE"

  if [[ -n "${AWS_ACCESS_KEY_ID:-}" || -n "${AWS_SECRET_ACCESS_KEY:-}" || -n "${AWS_SESSION_TOKEN:-}" ]]; then
    printf '%s\n' \
      "Attention : des identifiants AWS sont aussi présents dans l'environnement et peuvent être prioritaires." >&2
  fi
}

# Affiche à la fois la configuration locale et l'identité réellement obtenue.
awsctx() {
  _aws_fzf_require aws || return 1
  printf '%s\n' "$(_aws_fzf_context)"
  AWS_PAGER='' command aws sts get-caller-identity --output table "$@"
}

if [[ $- == *i* ]]; then
  bind -x '"\C-g":_aws_fzf_widget'
fi
