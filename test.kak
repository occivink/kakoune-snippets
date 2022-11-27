try %{
    require-module snippets
} catch %{
    source snippets.kak
    require-module snippets
}

define-command assert-selections-are -params 1 %{
    eval %sh{
        if [ "$1" != "$kak_quoted_selections" ]; then
            printf 'fail "Check failed"'
        fi
    }
}

edit -scratch *snippets-test-1*


# basic snippet
set -add buffer snippets 'snip1' 'trig1' %{ snippets-insert %{foo bar} }
exec -with-hooks 'itrig1<esc>'
assert-selections-are "'foo bar'"
exec '%d'

# snippet with placeholders
set -add buffer snippets 'snip2' 'trig2' %{ snippets-insert %{${foo} ${bar} ${baz}} }
exec -with-hooks 'itrig2<esc>'
assert-selections-are "'foo' 'bar' 'baz'"
exec '%H'
assert-selections-are "'foo bar baz'"
exec '%d'

# snippet with empty placeholders
set -add buffer snippets 'snip3' 'trig3' %{ snippets-insert %{foo ${} ${} bar} }
exec -with-hooks 'itrig3<esc>'
assert-selections-are "' ' ' '"
exec '%H'
assert-selections-are "'foo   bar'"
exec '%d'

# snippet with escaped placeholders placeholders
set -add buffer snippets 'snip4' 'trig4' %< snippets-insert %<foo $${} ${{bar}}}> >
exec -with-hooks 'itrig4<esc>'
assert-selections-are "'{bar}'"
exec '%H'
assert-selections-are "'foo ${} {bar}'"
exec '%d'

delete-buffer
