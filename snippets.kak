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
            printf "snippets %%{%s};" "$2"
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

face global SnippetsNextPlaceholders black,red+F
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
    eval %sh& # $kak_selections $kak_selections_desc
        perl -e '
use strict;
use warnings;
use Text::ParseWords();

my @sel_content = Text::ParseWords::shellwords($ENV{"kak_selections"});
my @sel_descs = Text::ParseWords::shellwords($ENV{"kak_selections_desc"});

my %placeholder_id_to_sel_ids;
my %placeholder_id_to_default;
my @placeholder_ids;

for my $i (0 .. $#sel_content) {
    my $sel = $sel_content[$i];
    $sel =~ s/\A\$\{?|\}\Z//g;
    my ($placeholder_id, $placeholder_default) = ($sel =~ /^(\d+)(?::(.*))?$/);
    if ($placeholder_id eq "0") {
        $placeholder_id = "9999";
    }
    $placeholder_ids[$i] = $placeholder_id;
    push (@{$placeholder_id_to_sel_ids{$placeholder_id}}, $i+1);
    if (defined($placeholder_default)) {
        $placeholder_id_to_default{$placeholder_id} = $placeholder_default;
    }
}
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
print("exec R\n");

print("set window snippets_placeholders %val{timestamp}\n");
print("set window snippets_placeholder_groups\n");

# iterate over the placeholder ids, sorted numerically
my $face = "SnippetsNextPlaceholders";
foreach my $placeholder_id (sort {$a <=> $b} keys %placeholder_id_to_sel_ids) {
    my $i = 0;
    foreach my $sel_id (@{$placeholder_id_to_sel_ids{$placeholder_id}}) {
        print("eval -draft %{ exec $sel_id<space>; set -add window snippets_placeholders \"%val{selection_desc}|$face\" }\n");
        $i++;
    }
    $face = "SnippetsOtherPlaceholders";
    print("set -add window snippets_placeholder_groups $i\n");
}
'
    &
!

def snippets-select-next-placeholders %{
    eval %sh{
        eval set -- "$kak_opt_snippets_placeholder_groups"
        if [ $# -eq 0 ]; then printf "fail 'There are no next placeholders'"; exit; fi
        number_to_select=$1
        shift
        number_next=$1
        printf 'set window snippets_placeholder_groups'
        for i do
            printf ' %s' "$i"
        done
        printf '\n'

        eval set -- "$kak_opt_snippets_placeholders"
        printf 'set window snippets_placeholders'
        printf ' %s' "$1"
        shift
        selections=''
        for i do
            if [ "$number_to_select" -gt 0 ]; then
                selections="${selections} ${i%%|*}"
                number_to_select=$((number_to_select-1))
            elif [ "$number_next" -gt 0 ]; then
                printf ' %s' "${i%%|*}|SnippetsNextPlaceholders"
                number_next=$((number_next-1))
            else
                printf ' %s' "$i"
            fi
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
