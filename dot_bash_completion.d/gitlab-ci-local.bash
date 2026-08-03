###-begin-gitlab-ci-local-completions-###
#
# yargs command completion script
#
# Installation: /$bunfs/root/gitlab-ci-local completion >> ~/.bashrc
#    or /$bunfs/root/gitlab-ci-local completion >> ~/.bash_profile on OSX.
#
_gitlab-ci-local_yargs_completions()
{
    local cur_word args type_list

    cur_word="${COMP_WORDS[COMP_CWORD]}"
    args=("${COMP_WORDS[@]}")

    # ask yargs to generate completions.
    # see https://stackoverflow.com/a/40944195/7080036 for the spaces-handling awk
    mapfile -t type_list < <(/$bunfs/root/gitlab-ci-local --get-yargs-completions "${args[@]}")
    mapfile -t COMPREPLY < <(compgen -W "$( printf '%q ' "${type_list[@]}" )" -- "${cur_word}" |
        awk '/ / { print "\""$0"\"" } /^[^ ]+$/ { print $0 }')

    # if no match was found, fall back to filename completion
    if [ ${#COMPREPLY[@]} -eq 0 ]; then
      COMPREPLY=()
    fi

    return 0
}
complete -o bashdefault -o default -F _gitlab-ci-local_yargs_completions gitlab-ci-local
###-end-gitlab-ci-local-completions-###

