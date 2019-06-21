hook global KakBegin .* snippets-directory-reload

declare-option str-list snippets_directories "%val{config}/snippets"

define-command snippets-directory-disable %{
    remove-hooks global snippets-directory
    evaluate-commands -buffer * "unset-option buffer snippets"
}

define-command snippets-directory-reload %{
    snippets-directory-disable
    hook -group snippets-directory global BufSetOption filetype=.* %{ unset-option buffer snippets }
    evaluate-commands %sh{
        snippets_info_to_kak_commands() {
            awk_script=$(cat <<'EOF'
                function multiply_single_quotes(text, levels){
                    substitute = "''"
                    for(; levels > 1; levels--) { substitute = substitute "''" }
                    gsub("'", substitute, text)
                    return text
                }
                $1 ~ /^SNIPMARK_MISSING_DIR$/ {
                    sub("SNIPMARK_MISSING_DIR ", "")
                    printf "%s\n", "echo -debug 'Snippets directory ''" $0 "'' does not exist'"
                    next
                }
                $1 ~ /^SNIPMARK_NEW_FILETYPE$/ {
                    sub("SNIPMARK_NEW_FILETYPE ", "")
                    printf "hook -group 'snippets-directory' global BufSetOption 'filetype="
                    printf "%s", multiply_single_quotes($0, 1)
                    printf "' 'set -add buffer snippets"
                    next
                }
                $1 ~ /^SNIPMARK_NEW_SNIPPET$/ {
                    sub("SNIPMARK_NEW_SNIPPET ", "")
                    printf "%s", " ''" multiply_single_quotes($0, 2) "''"
                    expected_line = "trigger"
                    next
                }
                $1 ~ /^SNIPMARK_END_SNIPPET$/ {
                    printf "'''' ''"
                    next
                }
                $1 ~ /^SNIPMARK_END_FILETYPE$/ {
                    print "'"
                    next
                }
                {
                    if(expected_line == "trigger") {
                        printf "%s", " ''" multiply_single_quotes($0, 2) "''"
                        printf " ''snippets-insert ''''"
                        expected_line = "snippets_first_line"
                    } else if (expected_line == "snippets_first_line") {
                        printf "%s", multiply_single_quotes($0, 4)
                        expected_line = "snippets_line"
                    } else {
                        printf "\n%s", multiply_single_quotes($0, 4)
                    }
                }
EOF
            )
            awk "${awk_script}"
        }

        NL='
'
        IFS="${NL}"
        eval set -- $kak_opt_snippets_directories
        ( for dir; do
            snippets_info=''
            if [ ! -d "$dir" ]; then
                printf '%s\n' "SNIPMARK_MISSING_DIR ${dir}"
                exit
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
                        snippets_info="${snippets_info}SNIPMARK_NEW_FILETYPE ${filetype}${NL}"
                        first=1
                    fi

                    snippets_info="${snippets_info}SNIPMARK_NEW_SNIPPET ${name}${NL}${trigger}${NL}"
                    while read -r line; do
                        snippets_info="${snippets_info}${line}${NL}"
                    done < "${snippet}"
                    snippets_info="${snippets_info}SNIPMARK_END_SNIPPET${NL}"
                done
                [ $first -eq 1 ] && snippets_info="${snippets_info}SNIPMARK_END_FILETYPE${NL}"
                cd ..
            done
            printf '%s' "${snippets_info}"
        done ) | snippets_info_to_kak_commands
    }
    # TODO unset and re-set the 'filetype' of each open buffer so that it has the latest snippets
}


define-command -docstring "snippets-add-snippet <trigger> <description> [<filetype>]: Create new snippet for given filetype.
If filetype is ommited, the current active filetype is used.
If 'filetype' is not currently defined, the snippet is added in global scope.
If all parameters were ommited, <trigger> and <description> are asked via prompt." \
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

define-command -hidden snippets-add-snippet-impl -params 2..3 %{ evaluate-commands %sh{
    trigger=$1; description=$2; filetype=$3
    [ -z "$filetype" ] && filetype="${kak_opt_filetype:-.*}"
    if [ -z "$kak_opt_snippets_directories" ]; then
        printf "echo -markup %%{{Error}The 'snippets_directories' option must be defined}"
        exit
    fi
    if [ -z "${trigger##*/*}" ]; then
        printf "echo -markup %%{{Error}Trigger cannot contain '/' character}"
    elif [ -z "${description##*/*}" ]; then
        printf "echo -markup %%{{Error}Description cannot contain '/' character}"
    else
        eval "set -- $kak_opt_snippets_directories"
        printf 'menu -auto-single --'
        for dir do
            directory="$dir/$filetype"
            [ -z "${directory##*\'*}" ] && directory=$(printf %s "$directory" | sed "s/'/''/g")
            printf " '%s' " "$directory"

            filename="$dir/$filetype/$trigger - $description"
            [ -z "${filename##*\'*}" ] && filename=$(printf %s "$filename" | sed "s/'/''''/g")
            printf " ' snippets-add-menu-action ''%s'' ' " "$filename"
        done
    fi
}}

define-command -hidden snippets-add-menu-action -params 1 %{
    nop %sh{
        mkdir -p $(dirname "$1")
    }
    edit %arg{1}
    hook -group snippets-add-watchers buffer BufWritePost .* snippets-directory-reload
}
