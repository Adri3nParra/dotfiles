# ─────────────────────────────────────────────
# CLOUD PROFILE MANAGER
# ─────────────────────────────────────────────

CLOUD_PROFILES_DIR="${CLOUD_PROFILES_DIR:-$HOME/.config/cloud-profiles/profiles}"

_cloud_reset_variables() {
    unset CLOUD_PROFILE
    unset CLOUD_PROVIDER

    # AWS
    unset AWS_PROFILE
    unset AWS_REGION
    unset AWS_DEFAULT_REGION
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN

    # GCP
    unset CLOUDSDK_ACTIVE_CONFIG_NAME
    unset CLOUDSDK_CORE_PROJECT
    unset GOOGLE_APPLICATION_CREDENTIALS

    # Azure
    unset AZURE_SUBSCRIPTION_ID
    unset ARM_SUBSCRIPTION_ID
    unset ARM_TENANT_ID
    unset ARM_CLIENT_ID
    unset ARM_CLIENT_SECRET

    # OpenStack / OVHcloud
    unset OS_CLOUD
    unset OS_REGION_NAME
    unset OS_AUTH_URL
    unset OS_PROJECT_ID
    unset OS_PROJECT_NAME
    unset OS_USERNAME
    unset OS_PASSWORD
    unset OS_USER_DOMAIN_NAME
    unset OS_PROJECT_DOMAIN_NAME

    # Scaleway
    unset SCW_PROFILE
    unset SCW_DEFAULT_PROJECT_ID
    unset SCW_DEFAULT_ORGANIZATION_ID
    unset SCW_DEFAULT_REGION
    unset SCW_DEFAULT_ZONE
    unset SCW_ACCESS_KEY
    unset SCW_SECRET_KEY

    # Kubernetes
    unset KUBECONFIG

    # Terraform / OpenTofu
    unset TF_WORKSPACE
    unset TF_VAR_environment
}

_cloud_profile_names() {
    [[ -d "$CLOUD_PROFILES_DIR" ]] || return 0

    find "$CLOUD_PROFILES_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.env' \
        -printf '%f\n' 2>/dev/null |
        sed 's/\.env$//' |
        sort
}

_cloud_select_profile() {
    local profiles

    profiles="$(_cloud_profile_names)"

    if [[ -z "$profiles" ]]; then
        echo "Aucun profil trouvé dans : $CLOUD_PROFILES_DIR" >&2
        return 1
    fi

    if command -v fzf >/dev/null 2>&1; then
        printf '%s\n' "$profiles" |
            fzf \
                --height=40% \
                --reverse \
                --border \
                --prompt='☁️  Profil cloud > '
    else
        echo "fzf n'est pas installé." >&2
        echo "Profils disponibles :" >&2
        printf '  %s\n' $profiles >&2
        return 1
    fi
}

_cloud_load_profile() {
    local profile="$1"
    local profile_file="$CLOUD_PROFILES_DIR/$profile.env"

    if [[ ! -f "$profile_file" ]]; then
        echo "Profil cloud inconnu : $profile" >&2
        echo >&2
        echo "Profils disponibles :" >&2
        _cloud_profile_names | sed 's/^/  - /' >&2
        return 1
    fi

    _cloud_reset_variables

    # shellcheck disable=SC1090
    source "$profile_file"

    export CLOUD_PROFILE="$profile"

    echo "☁️  Profil actif : $CLOUD_PROFILE"

    [[ -n "${CLOUD_PROVIDER:-}" ]] &&
        echo "   Provider      : $CLOUD_PROVIDER"

    [[ -n "${AWS_PROFILE:-}" ]] &&
        echo "   AWS profile   : $AWS_PROFILE"

    [[ -n "${OS_CLOUD:-}" ]] &&
        echo "   OpenStack     : $OS_CLOUD"

    [[ -n "${SCW_PROFILE:-}" ]] &&
        echo "   Scaleway      : $SCW_PROFILE"

    [[ -n "${CLOUDSDK_ACTIVE_CONFIG_NAME:-}" ]] &&
        echo "   GCP config    : $CLOUDSDK_ACTIVE_CONFIG_NAME"

    [[ -n "${KUBECONFIG:-}" ]] &&
        echo "   Kubeconfig    : $KUBECONFIG"
}

cloud() {
    local action="${1:-use}"
    local profile="${2:-}"

    case "$action" in
        use)
            if [[ -z "$profile" ]]; then
                profile="$(_cloud_select_profile)" || return 1
            fi

            _cloud_load_profile "$profile"
            ;;

        list | ls)
            _cloud_profile_names
            ;;

        current)
            echo "${CLOUD_PROFILE:-aucun}"
            ;;

        show)
            echo "Profil cloud : ${CLOUD_PROFILE:-aucun}"
            echo "Provider     : ${CLOUD_PROVIDER:-non défini}"

            env |
                grep -E \
                    '^(AWS_|CLOUDSDK_|GOOGLE_|AZURE_|ARM_|OS_|SCW_|KUBECONFIG=|TF_WORKSPACE=|TF_VAR_)' |
                sort |
                sed -E \
                    's/^(AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|ARM_CLIENT_SECRET|OS_PASSWORD|SCW_SECRET_KEY)=.*/\1=********/'
            ;;

        unset | clear)
            _cloud_reset_variables
            echo "☁️  Profil cloud désactivé"
            ;;

        reload)
            if [[ -z "${CLOUD_PROFILE:-}" ]]; then
                echo "Aucun profil cloud actif." >&2
                return 1
            fi

            profile="$CLOUD_PROFILE"
            _cloud_load_profile "$profile"
            ;;

        edit)
            if [[ -z "$profile" ]]; then
                profile="$(_cloud_select_profile)" || return 1
            fi

            "${EDITOR:-vim}" "$CLOUD_PROFILES_DIR/$profile.env"
            ;;

        path)
            echo "$CLOUD_PROFILES_DIR"
            ;;

        help | -h | --help)
            cat <<'EOF'
Usage :
  cloud use [profil]   Active un profil
  cloud list           Liste les profils
  cloud current        Affiche le profil actif
  cloud show           Affiche les variables actives
  cloud reload         Recharge le profil actif
  cloud edit [profil]  Édite un profil
  cloud unset          Désactive le profil
  cloud path           Affiche le dossier des profils
EOF
            ;;

        *)
            echo "Action inconnue : $action" >&2
            echo "Utilise : cloud help" >&2
            return 1
            ;;
    esac
}

_cloud_completion() {
    local current previous actions profiles

    current="${COMP_WORDS[COMP_CWORD]}"
    previous="${COMP_WORDS[COMP_CWORD - 1]}"

    actions="use list ls current show unset clear reload edit path help"

    case "$COMP_CWORD" in
        1)
            COMPREPLY=(
                $(compgen -W "$actions" -- "$current")
            )
            ;;

        2)
            case "$previous" in
                use | edit)
                    profiles="$(_cloud_profile_names)"
                    COMPREPLY=(
                        $(compgen -W "$profiles" -- "$current")
                    )
                    ;;
            esac
            ;;
    esac
}

complete -F _cloud_completion cloud
