decl str-list snippets
decl str-list snippets_auto_expand

hook global WinSetOption 'snippets_auto_expand=$' %{
    rmhooks buffer snippets-auto-expand
}
hook global WinSetOption 'snippets_auto_expand=.+$' %{
    # kakoune/#2397 causes this to be run twice
    rmhooks buffer snippets-auto-expand
    hook -group snippets-auto-expand buffer InsertChar .* %sh{
        printf 'try %%{'
        concat=$(
            eval set -- "$kak_opt_snippets_auto_expand"
            while [ $# -ne 0 ]; do
                printf '%s|' "$1"
                shift 2
            done
        )
        printf "exec -draft 'b<a-k>%s(%s)%s<ret>';" '\A\b' "${concat%|}" '\b\z'

        eval set -- "$kak_opt_snippets_auto_expand"
        first=0
        while [ $# -ne 0 ]; do
            if [ $first -eq 0 ]; then
                printf 'try %%{'
                first=1
            else
                printf '} catch %%{'
            fi
            printf "exec -draft 'b<a-k>%s<ret>d';" "$1"
            printf "snippet %%{%s};" "$2"
            shift 2
        done
        printf '}}'
    }
}

def snippets-info %{
    info -title Snippets %sh{
        eval set -- "$kak_opt_snippets_auto_expand"
        maxlen=0
        while [ $# -ne 0 ]; do
            if [ ${#1} -gt $maxlen ]; then
                maxlen=${#1}
            fi
            shift 2
        done
        eval set -- "$kak_opt_snippets"
        if [ $# -eq 0 ]; then printf 'No snippets defined'; exit; fi
        shifted=0
        while [ $# -ne 0 ]; do
            if [ $maxlen -eq 0 ]; then
                printf '%s\n' "$1"
                shift 2
            else
                snipname="$1"
                eval set -- "$kak_opt_snippets_auto_expand"
                found=0
                while [ $# -ne 0 ]; do
                    if [ "$2" = "$snipname" ]; then
                        printf "%${maxlen}s ➡ %s\n" "$1" "$2"
                        found=1
                        break
                    fi
                    shift 2
                done
                if [ $found -eq 0 ]; then
                    printf "%${maxlen}s    %s\n" "" "$snipname"
                fi
                shifted=$((shifted+2))
                eval set -- "$kak_opt_snippets"
                shift "$shifted"
            fi
        done
    }
}

def snippet-insert -hidden -params 1 %{
    # the sprinkled <a-;> are a hack for kakoune/#1916
    eval -save-regs '"^' %{
        exec -draft -save-regs '' Z
        reg '"' %arg{1}
        exec '<a-;><a-P>'
        exec -itersel -draft '<a-s>1<a-&>'
        try %{
            eval -draft %{
                reg '"' %sh{
                    if [ $kak_opt_indentwidth -eq 0 ]; then
                        printf '\t'
                    else
                        printf "%${kak_opt_indentwidth}s"
                    fi
                }
                exec -draft 's\{\{INDENT\}\}<ret>R'
            }
        }
        try %{
            exec '<a-;>s\{\{SELECTION\}\}<ret>'
            exec '<a-;>d'
        } catch %{
            exec '<a-;>z'
            echo
        }
    }
}

def snippet-impl -hidden -params 1.. %{
    eval %sh{
        use=$1
        shift 1
        index=3
        while [ $# -ne 0 ]; do
            if [ "$1" = "$use" ]; then
                printf "eval %%arg{%s}" "$index"
                exit
            fi
            index=$((index + 2))
            shift 2
        done
        printf "fail 'Snippet not found'"
    }
}

def snippet -params 1 -shell-script-candidates %{
    eval set -- "$kak_opt_snippets"
    while [ $# -ne 0 ]; do
        printf '%s\n' "$1"
        shift 2
    done
} %{
    snippet-impl %arg{1} %opt{snippets}
}

def snippets-menu-impl -hidden -params .. %{
    eval %sh{
        printf 'menu'
        i=1
        while [ $# -ne 0 ]; do
            printf " %%arg{%s}" $i
            printf " 'snippet %%arg{%s}'" $i
            i=$((i+2))
            shift 2
        done
    }
}

def snippets-menu %{
    snippets-menu-impl %opt{snippets}
}
