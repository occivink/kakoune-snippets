# kakoune-snippets

(Yet another) [kakoune](http://kakoune.org) plugin for handling snippets.

[![demo](https://asciinema.org/a/217470.png)](https://asciinema.org/a/217470)

## Setup

Add `snippets.kak` to your autoload dir: `~/.config/kak/autoload/`, or source it manually.

Thie plugin has a dependency on `perl`.

## Usage

The extension is configured via three options:
* `snippets` `[str-list]` is an alternating list of snippet names and commands (e.g. `snip-1` `snip-1-command` `snip-2` `snip-2-command`...). When the snippet is referenced by name, the associated command is run.  
* `snippets_triggers` `[str-list]` is an alternating list of triggers and snippet names (e.g. `trig-1` `snip-1` `trig-2` `snip-2`...). The snippet names must match the ones in the other option.  
* `snippets_auto_expand` `[bool]` controls whether triggers are automatically expanded when they are typed in insert mode. `true` by default.  

Snippets can be selected manually with the commands `snippet` and `snippets-menu`. The triggers can also be expanded manually `snippets-expand-trigger`.

At any moment, the `snippets-info` command can be used to show the available snippets and their respective triggers.

### Defining your own snippets

Snippet commands are just regular kakoune command, so you can do just about anything in them.

Ideally, your snippet command should work in both Insert and Normal mode, so that it can be used via auto-expansion and manual snippet call (be careful about this [kakoune issue](https://github.com/mawww/kakoune/issues/1916)).

### `snippet-insert`

`snippet-insert` is a builtin command of the script that can be used to insert text with proper indentation and optionally move/create cursors. It accepts one argument which is the snippet to be inserted at the cursor(s). The snippet supports custom syntax (similar to that of [LSP's](https://github.com/Microsoft/language-server-protocol/blob/master/snippetSyntax.md)) to define placeholders. More specifically:

* numbered placeholders (with `$n` or `${n}`) which can be iterated over sequentially. The special placeholder `${indent}` is expanded to the appropriate indentation level (depending on `indentwidth`)
* default placeholder text (with `${n:default text}`). The placeholder will be initialized to the specified default text.

If multiple placeholders share the same number, multiple selections will be created when iterating, and the same default text will be used.

To use a literal `$` inside a snippet, or a literal `}` inside a placeholder's default text, simply double it up.

When a snippet is inserted with `snippet-insert`, the first placeholder(s) is automatically selected. It is then possible to iterate over the remaining placeholders using `snippets-select-next-placeholders`. The 0th placeholder will always be selected last.

## Changelog

* triggers can now be manually expanded by calling the `snippets-expand-trigger` command on a valid trigger
* `snippets_auto_expand` is now a boolean that controls whether auto-expansion of triggers is enabled
* `snippets_auto_expand` was renamed to `snippets_triggers`

## FAQ

### What's the performance impact of the extension?

If you use the auto-expansion feature, a runtime hook is run on each Insert mode key press. It only uses a shell scope in case of a match, and stop early otherwise.
If you don't use it, there is no runtime cost (except when executing a snippet of course).

### What's with escaping, what kind of characters can I use and not use?

You shouldn't use unbalanced braces (`{}`) in snippet names, and auto-expansion triggers should be limited to alphanumeric characters. You can use `^` if you want a trigger to only match at the beginning of a line.

### Can you add snippets for language `X`?

No, but you're welcome to submit your own and I'll add them. TODO

### How did you do the demo?

It's done using kitty's remote control features, a 'manuscript' and a script to bridge the two. I'll upload them at some point.

## Similar extensions

https://github.com/alexherbo2/snippets.kak  
https://github.com/JJK96/kakoune-snippets  
https://github.com/shachaf/kak/blob/master/scripts/snippet.kak  

## License

Unlicense
