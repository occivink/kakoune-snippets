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
        eval set -- "$kak_quoted_opt_snippets_directories"
        one_exists=0
        for dir do
            if [ -d "$dir" ]; then
                one_exists=1
                break
            fi
        done
        if [ "$one_exists" = 0 ]; then
            exit
        fi
        cat <<'EOF' | perl - "$@"
use strict;
use warnings;

foreach my $dir (@ARGV) {
    if(! -d $dir) {
        print "echo -debug 'Snippets directory ''$dir'' does not exist'\n";
        next;
    }

    opendir(my $dh, $dir) || die "Can't open $dir: $!";
    my @filetypes = readdir($dh);
    closedir($dh);
    foreach my $filetype (@filetypes) {
        next if ($filetype eq '.' || $filetype eq '..');
        $filetype = "$dir/$filetype";

        next if (! -d $filetype);
        print_kak_commands_for_filetype_dir($filetype);
    }
}

sub print_kak_commands_for_filetype_dir {
    my $filetype = shift;
    my $printed_filetype_intro = 0;
    opendir(my $dh, $filetype) || die "Can't open $filetype: $!";
    my @snippets = readdir($dh);
    closedir($dh);
    foreach my $snippet (sort @snippets) {
        next if ($snippet eq '.' || $snippet eq '..');
        my $name = $snippet;
        my $trigger = $snippet;
        $snippet = "$filetype/$snippet";

        next if (! -f $snippet);
        $name =~ s/.*? - //;
        next if ($name eq "");               # no valid snippet name
        if("$filetype/$name" eq $snippet) {  # no ' - ' in filename -> no trigger
            $trigger = "";
        } else {
            $trigger =~ s/ - .*//;
        }

        if($printed_filetype_intro == 0) {
            print_filetype_intro($filetype);
            $printed_filetype_intro = 1;
        }
        print_snippet($trigger, $name, $snippet);
    }
    print_filetype_outro() if ($printed_filetype_intro == 1);
}

sub print_filetype_intro {
    my $filetype = shift;
    print "hook -group 'snippets-directory' global BufSetOption 'filetype=";
    $filetype =~ s/.*\///;  # Poor mans basename() to avoid the extra import
    print multiply_single_quotes($filetype, 1);
    print "' 'set -add buffer snippets"
}

sub print_snippet {
    my $trigger = shift;
    my $name = shift;
    my $snippet = shift;
    print " ''", multiply_single_quotes($name, 2), "''";
    print " ''", multiply_single_quotes($trigger, 2), "''";
    print " ''snippets-insert ''''";
    open(my $fh, "<", $snippet) || die "Can't open < $snippet: $!";
    while (<$fh>) {
        chomp if eof;
        print multiply_single_quotes($_, 4);
    }
    print "'''' ''";
    close($fh) || warn "close failed: $!";
}

sub print_filetype_outro {
    print "'\n";
}

sub multiply_single_quotes {
    my $text = shift;
    my $levels = shift;  # "levels" grows in powers of 2 as more escaping is needed
    my $substitute = "''" x $levels;
    $text =~ s/'/$substitute/g;
    return $text;
}
EOF
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
        eval "set -- $kak_quoted_opt_snippets_directories"
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
