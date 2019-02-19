hook -once global KakBegin '' snippets-directory-reload

decl str-list snippets_directories "%val{config}/snippets"

define-command snippets-directory-disable %{
    rmhooks global snippets-directory
    eval -buffer * "unset buffer snippets"
}

define-command snippets-directory-reload %{
    snippets-directory-disable
    # it might be more efficient to do everything in a single awk/perl/python subprocess
    # left as an exercise to the reader
    hook -group snippets-directory global BufSetOption filetype=.* %{ unset buffer snippets }
    eval %sh{
        doubleupsinglequotes()
        {
            rest="$1"
            levels="$2" # "levels" grows in powers of 2 as more escaping is needed
            while :; do
                beforequote="${rest%%"'"*}"
                if [ "$rest" = "$beforequote" ]; then
                    printf %s "$rest"
                    break
                fi
                cur="$levels"
                printf "%s" "$beforequote"
                while [ "$cur" -gt 0 ]; do
                    printf "''"
                    cur=$((cur-1))
                done
                rest="${rest#*"'"}"
            done
        }
        IFS='
'
        eval set -- $kak_opt_snippets_directories
        for dir; do
        ( # subshell to automatically go back to the starting dir
            if [ ! -d "$dir" ]; then
                printf "echo -debug 'Snippets directory ''%s'' does not exist'\n" "$dir"
                continue
            fi
            cd "$dir"
            for filetype in *; do
                [ ! -d $filetype ] && continue
                first=0
                cd "$filetype"
                for snippet in *; do  # this won't include triggers beginning with '.' but those make little sense anyway
                    [ ! -f "$snippet" ] && continue      # not a regular file
                    name="${snippet#* - }"
                    [ "$name" = "" ] && continue         # no valid snippet name
                    if [ "$name" = "$snippet" ]; then    # no ' - ' in filename -> no trigger
                        trigger=""
                    else
                        trigger="${snippet%% - *}"
                    fi

                    if [ "$first" -eq 0 ]; then
                        printf "hook -group 'snippets-directory' global BufSetOption 'filetype="
                        doubleupsinglequotes "$filetype" 1
                        printf "' 'set -add buffer snippets"
                        first=1
                    fi

                    printf " ''"
                    doubleupsinglequotes "$name" 2
                    printf "'' ''"
                    doubleupsinglequotes "$trigger" 2
                    printf "'' ''snippets-insert ''''"
                    # we're hitting escaping levels that shouldn't even be possible
                    firstline=0
                    while read -r line; do
                        if [ "$firstline" -eq 0 ]; then
                            firstline=1
                        else
                            printf "\n"
                        fi
                        doubleupsinglequotes "$line" 4
                    done < "$snippet"
                    printf "'''' ''"
                done
                [ $first -eq 1 ] && printf "'\n"
                cd ..
            done
        )
        done
    }
    # TODO unset and re-set the 'filetype' of each open buffer so that it has the latest snippets
}


define-command -docstring "snippets-add-snippet <trigger> <description> [<filetype>]: Create new snippet for given filetype.
If filetype is ommited, current active filetype is used.
If no current filetype available, snippet is added in global scope.
If all parameters were ommited function will ask for <trigger> and <description> via prompt." \
snippets-add-snippet -params 0..3 %{ evaluate-commands %sh{
    if [ $# -ge 2 ]; then
        printf "snippets-add-snippet-impl %%arg{1} %%arg{2} %%arg{3}"
    else
        printf "snippets-add-snippet-prompt"
    fi
}}

define-command -hidden snippets-add-snippet-prompt %{ evaluate-commands %{
    prompt "Trigger: " %{
        declare-option -hidden str snippets_new_trigger %val{text}
        prompt "Snippet Description: " %{
            snippets-add-snippet-impl %opt{snippets_new_trigger} %val{text} %opt{filetype}
        }
    }
}}

define-command -hidden snippets-add-snippet-impl -params 2.. %{ evaluate-commands %sh{
    trigger=$1; description=$2; filetype=$3
    [ -z "$filetype" ] && filetype="${kak_opt_filetype:-.*}"
    if [ -z "$kak_opt_snippets_directories" ]; then
        printf "echo -markup %%{{Error}There's no snippet directory set in 'snippets_directories' option}"
        exit
    fi
    if [ -z "${trigger##*/*}" ]; then
        printf "echo -markup %%{{Error}Trigger can't contain '/' character}"
    elif [ -z "${description##*/*}" ]; then
        printf "echo -markup %%{{Error}Description can't contain '/' character}"
    else
        eval "set -- $kak_opt_snippets_directories"
        while [ $# -gt 0 ]; do
            menu="$menu %{$1/$filetype} %{evaluate-commands %{edit %{$1/$filetype/$trigger - $description}}}"
            shift
        done
        printf "%s\n" "menu -auto-single $menu"
    fi
}}
