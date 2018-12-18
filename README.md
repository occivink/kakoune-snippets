# kakoune-snippets

(Yet another) [kakoune](http://kakoune.org) plugin for handling snippets.

[![demo](https://asciinema.org/a/217470.png)](https://asciinema.org/a/217470)

## Setup

Add `snippets.kak` to your autoload dir: `~/.config/kak/autoload/`, or source it manually.

## Usage

The extension is configured via two options:
* `snippets` `[str-list]` is an alternating list of snippet names and commands (e.g. `snip-1` `snip-1-command` `snip-2` `snip-2-command`...). When the snippet is referenced by name, the associated command is run.
* `snippets_auto_expand` `[str-list]` is an alternating list of triggers and snippet names (e.g. `trig-1` `snip-1` `trig-2` `snip-2`...). The snippet names must match the ones in the other option. When one of the triggers is typed in insert mode, the associated snippet is run.

Snippets can be run manually with the commands `snippet` and `snippets-menu`. If you only want to use snippets manually, you do not have to set `snippets_auto_expand`.

At any moment, the `snippets-info` command can be used to show the available snippets and their triggers.

### Defining your own snippets

Snippet commands are just regular kakoune command, so you can do just about anything in them.

Ideally, your snippet command should work in both Insert and Normal mode, so that it can be used via auto-expansion and manual snippet call (be careful about this [kakoune issue](https://github.com/mawww/kakoune/issues/1916)).

`snippet-insert` is a builtin command of the script that can be used to insert text with proper indentation and optionally move/create cursors. For example, to define a simple for-loop snippet we can do like so:
```
set buffer snippets \
"Classic for-loop" \
%{ snippet-insert %{for (int i = {{SELECTION}}; i < {{SELECTION}}; ++i) {
{{INDENT}}{{SELECTION}}
}}}
```
The `{{INDENT}}` placeholder is used to appropriately set tab/spaces according to `indentwidth`, and `{{SELECTION}}` indicates where selections should be created.

## FAQ

### What's the performance impact of the extension?

If you use the auto-expansion feature (i.e. the option is not empty), there is a minimal setup of 1 shell-scope when the option is set. The runtime hook uses no shell scope, and exits quickly if there is no match.  
If you don't use it, there is no runtime cost (except when executing a snippet of course).

### What's with escaping, what kind of characters can I use and not use?

You shouldn't use unbalanced braces (`{}`) in snippet names, and auto-expansion triggers should be limited to alphanumeric characters. You can use `^` if you want a trigger to only match at the beginning of a line.

### Can you add snippets for language `X`?

No, but you're welcome to submit your own and I'll add them. TODO

### How did you do the demo?

It's done using kitty's remote control features, a 'manuscript' and a script to bridge the two. I'll upload them at some point.

### How do you iterate over the selections in the demo?

I use this [extension](https://github.com/occivink/kakoune-phantom-selection/)

## Similar extensions

https://github.com/alexherbo2/snippets.kak  
https://github.com/JJK96/kakoune-snippets  
https://github.com/shachaf/kak/blob/master/scripts/snippet.kak  

## License

Unlicense
