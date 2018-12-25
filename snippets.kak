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
        printf "exec -draft 'b<a-k>%s(%s)%s<ret>'\n" '\A\b' "${concat%|}" '\b\z'

        eval set -- "$kak_opt_snippets_auto_expand"
        first=0
        while [ $# -ne 0 ]; do
            if [ $first -eq 0 ]; then
                printf 'try %%{'
                first=1
            else
                printf '} catch %%{'
            fi
            printf "exec -draft 'b<a-k>%s<ret>d'\n" "$1"
            printf "snippets %%{%s}\n" "$2"
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

decl -hidden range-specs snippets_placeholders
decl -hidden int-list snippets_placeholder_groups

face global SnippetsNextPlaceholders black,green+F
face global SnippetsOtherPlaceholders black,yellow+F

def snippets-insert -hidden -params 1 %<
    eval -draft -save-regs '^"' %<
        reg '"' %arg{1}
        exec <a-P>
        # align everything with the current line
        exec -itersel -draft '<a-s>1<a-&>'
        # replace ${indent} with the appropriate indent
        try %{
            reg '"' %sh{
                if [ $kak_opt_indentwidth -eq 0 ]; then
                    printf '\t'
                else
                    printf "%${kak_opt_indentwidth}s"
                fi
            }
            exec -draft 's((?<lt>!\$)(?:\$\$)*|\A)\K(\$\{indent\})<ret>R'
        }
        try %<
            # select things that look like placeholders
            # this regex is not as bad as it looks
            eval -draft %<
                exec s((?<lt>!\$)(\$\$)*|\A)\K(\$(\d+|\{(\d+(:(\}\}|[^}])+)?)\}))<ret>
                # tests
                # $1                - ok
                # ${2}              - ok
                # $1$2$3            - ok x3
                # $1${2}$3${4}      - ok x4
                # $1$${2}$$3${4}    - ok, not ok, not ok, ok
                # $$${3:abc}        - ok
                # $${3:abc}         - not ok
                # $$$${3:abc}def    - not ok
                # ${4:a}}b}def      - ok
                # ${5:ab}}}def      - ok
                # ${6:ab}}cd}def    - ok
                # ${7:ab}}}}cd}def  - ok
                # ${8:a}}b}}c}}}def - ok
                snippets-insert-perl-impl
            >
        >
        try %{
            # de-double up $
            exec 's\$\$<ret>;d'
        }
    >
    try snippets-select-next-placeholders
>

def -hidden snippets-insert-perl-impl %!
    eval %sh& # $kak_selections
        perl -e '
use strict;
use warnings;
use Text::ParseWords();

my @sel_content = Text::ParseWords::shellwords($ENV{"kak_selections"});

my %placeholder_id_to_default;
my @placeholder_ids;

print("set window snippets_placeholder_groups");
for my $i (0 .. $#sel_content) {
    my $sel = $sel_content[$i];
    $sel =~ s/\A\$\{?|\}\Z//g;
    my ($placeholder_id, $placeholder_default) = ($sel =~ /^(\d+)(?::(.*))?$/);
    if ($placeholder_id eq "0") {
        $placeholder_id = "9999";
    }
    $placeholder_ids[$i] = $placeholder_id;
    print(" $placeholder_id");
    if (defined($placeholder_default)) {
        $placeholder_id_to_default{$placeholder_id} = $placeholder_default;
    }
}
print("\n");

print("reg dquote");
foreach my $i (0 .. $#sel_content) {
    my $placeholder_id = $placeholder_ids[$i];
    if (exists $placeholder_id_to_default{$placeholder_id}) {
        my $def = $placeholder_id_to_default{$placeholder_id};
        # double up interrogation and exclamation points
        $def =~ s/!!/!!!!/g;
        $def =~ s/&&/&&&&/g;
        # de-double up closing braces
        $def =~ s/\}\}/}/g;
        # double up single-quotes
        $def =~ s/'\''/'\'''\''/g;
        print(" '\''$def'\''");
    } else {
        print(" '\'''\''");
    }
}
print("\n");
'
    &
    exec R
    set window snippets_placeholders %val{timestamp}
    # no need to set the NextPlaceholders face yet, select-next-placeholders will take care of that
    eval -itersel %{ set -add window snippets_placeholders "%val{selections_desc}|SnippetsOtherPlaceholders" }
!

def snippets-select-next-placeholders %{
    update-option window snippets_placeholders
    eval %sh{
        eval set -- "$kak_opt_snippets_placeholder_groups"
        if [ $# -eq 0 ]; then printf "fail 'There are no next placeholders'"; exit; fi
        next_id=9999
        second_next_id=9999
        for placeholder_id do
            if [ "$placeholder_id" -lt "$next_id" ]; then
                second_next_id="$next_id"
                next_id="$placeholder_id"
            elif [ "$placeholder_id" -lt "$second_next_id" ] && [ "$placeholder_id" -ne "$next_id" ]; then
                second_next_id="$placeholder_id"
            fi
        done
        next_descs_id=''
        second_next_descs_id='' # for highlighting purposes
        desc_id=0
        printf 'set window snippets_placeholder_groups'
        for placeholder_id do
            if [ "$placeholder_id" -eq "$next_id" ]; then
                next_descs_id="${next_descs_id} $desc_id"
            else
                printf ' %s' "$placeholder_id"
            fi
            if [ "$placeholder_id" -eq "$second_next_id" ]; then
                second_next_descs_id="${second_next_descs_id} $desc_id"
            fi
            desc_id=$((desc_id+1))
        done
        printf '\n'

        eval set -- "$kak_opt_snippets_placeholders"
        printf 'set window snippets_placeholders'
        printf ' %s' "$1"
        shift
        selections=''
        desc_id=0
        for desc do
            found=0
            for candidate_desc_id in $next_descs_id; do
                if [ "$candidate_desc_id" -eq "$desc_id" ]; then
                    found=1
                    selections="${selections} ${desc%%|*}"
                    break
                fi
            done
            if [ $found -eq 0 ]; then
                for candidate_desc_id in $second_next_descs_id; do
                    if [ "$candidate_desc_id" -eq "$desc_id" ]; then
                        found=1
                        printf ' %s' "${desc%%|*}|SnippetsNextPlaceholders" 
                        break
                    fi
                done
                if [ $found -eq 0 ]; then
                    printf ' %s' "$desc"
                fi
            fi
            desc_id=$((desc_id+1))
        done
        printf '\n'

        printf "select %s\n" "$selections"
    }
}

def snippets-impl -hidden -params 1.. %{
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

def snippets -params 1 -shell-script-candidates %{
    eval set -- "$kak_opt_snippets"
    while [ $# -ne 0 ]; do
        printf '%s\n' "$1"
        shift 2
    done
} %{
    snippets-impl %arg{1} %opt{snippets}
}

def snippets-menu-impl -hidden -params .. %{
    eval %sh{
        printf 'menu'
        i=1
        while [ $# -ne 0 ]; do
            printf " %%arg{%s}" $i
            printf " 'snippets %%arg{%s}'" $i
            i=$((i+2))
            shift 2
        done
    }
}

def snippets-menu %{
    snippets-menu-impl %opt{snippets}
}
