hook -once global KakBegin '' snippets-directory-reload

define-command snippets-directory-disable %{
    rmhooks global snippets-directory-.*
}

define-command snippets-directory-reload %{
    snippets-directory-disable
    # it might be more efficient to do everything in a single awk/perl/python subprocess
    # left as an exercise to the reader
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
        cd "$kak_config"
        if [ ! -d snippets ]; then
            echo 'echo -debug "No snippets directory"'
            exit
        fi
        cd snippets
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
                    printf "hook -group 'snippets-directory-"
                    doubleupsinglequotes "$filetype" 1
                    printf "' global BufSetOption 'filetype="
                    doubleupsinglequotes "$filetype" 1
                    printf "' 'set buffer snippets"
                    first=1
                fi

                printf " ''"
                doubleupsinglequotes "$name" 2
                printf "'' ''"
                doubleupsinglequotes "$trigger" 2
                printf "'' ''snippets-insert ''''"
                # we're hitting escaping levels that shouldn't even be possible
                firstline=0
                cat "$snippet" | while read line; do
                    if [ "$firstline" -eq 0 ]; then
                        firstline=1
                    else
                        printf "\n"
                    fi
                    doubleupsinglequotes "$line" 4
                done
                printf "'''' ''"
            done
            [ $first -eq 1 ] && printf "'\n"
            cd ..
        done
    }
    # TODO unset and re-set the 'filetype' of each open buffer so that it has the latest snippets
}
