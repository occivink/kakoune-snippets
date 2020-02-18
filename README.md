# kakoune-snippets

**Warning**: this plugin is still in its early stages so expect breakages. I'll try to keep the changelog (see below) up-to-date.

(Yet another) [kakoune](http://kakoune.org) plugin for handling snippets. For a comprehensive collection of snippets for various languages, see [kakoune-snippet-collection](https://github.com/andreyorst/kakoune-snippet-collection).

[![demo](https://asciinema.org/a/217470.png)](https://asciinema.org/a/217470)

## Setup

Add `snippets.kak` to your autoload dir: `~/.config/kak/autoload/`, or source it manually.

This plugin requires kakoune version >= `v2019.07.01`.

## Usage

The extension is configured via two options:
* `snippets` `[str-list]` is a list of {name, trigger, command} tuples. The name is the identifier of the snippet, the trigger is a short string that identifies the snippet, and the command is what gets `eval`'d when the snippet is activated. In practice it is just a flat list that looks like `snip1` `snip1-trigger` `snip1-command` `snip2` `snip2-trigger` `snip2-command`...  
* `snippets_auto_expand` `[bool]` controls whether triggers are automatically expanded when they are typed in insert mode. `false` by default.  

Snippets can be selected manually with the commands `snippet` and `snippets-menu`.

At any moment, the `snippets-info` command can be used to show the available snippets and their respective triggers.

### Triggers

Snippets can be executed when a certain string is written directly in the buffer with the help of triggers. To each snippet is associated a regex which we call a trigger.

Triggers can be automatically expanded by setting `snippets_auto_expand` to true, or they can be expanded manually by using the `snippets-expand-trigger` command. By default, this command tries to expand the current selection if it is a trigger, but you can also pass it an argument to select a different part of the buffer. 
The option `snippets_triggers_regex` can be used to help select triggers. It's a simple alternation of all triggers as a single regex.

For example, this call will try to select a trigger on the current line and expand it. If it fails, the selection stays unmodified.
```
snippets-expand-trigger %{
    reg / "%opt{snippets_triggers_regex}"
    # select to the beginning of the line, and then subselect for one of the triggers
    exec 'hGhs<ret>'
}
```

If a snippet does not have a trigger (i.e. it is empty), you won't be able to use it via expansion, but the basic commands `snippet` and `snippet-menu` can still be used.

### Defining your own snippets

Snippet commands are just regular kakoune command, so you can do just about anything in them.

Ideally, your snippet command should work in both Insert and Normal mode, so that it can be used via auto-expansion and manual snippet call (be careful about this [kakoune issue](https://github.com/mawww/kakoune/issues/1916)).

## Changelog

* **`snippets-insert` and `snippets-directory` have been removed**
* `${indent}` has been removed in favor of changing leading tabs to the preferred indentation  
* any value can now be used as a trigger. They're regexes, so escape them accordingly  
* implicit `\b` are not inserted anymore before and after triggers. The internal option `%opt{snippets_expand_triggers}` has been renamed to `%opt{snippets_triggers_regex}`  
* `snippets_triggers` and `snippets` have been merged into a single option  
* triggers can now be manually expanded by calling the `snippets-expand-trigger` command on a valid trigger  
* `snippets_auto_expand` is now a boolean that controls whether auto-expansion of triggers is enabled  
* `snippets_auto_expand` was renamed to `snippets_triggers`  

## FAQ

### What is the performance impact of the extension?

If you use the auto-expansion feature, a runtime hook is run on each Insert mode key press. It only uses a shell scope in case of a match, and stops early otherwise.  
If you do not use it, there is no runtime cost (except when executing a snippet of course).

### What is with escaping, what kind of characters can I use and not use?

You should be able to use anything. Triggers are currently restricted to at most 20 characters (at least for auto-expansion), but the number is arbitrary and we could raise it. Note that triggers are regexes, so you have to escape characters wherever necessary.

### My snippets are expanding too greedily. If I type 'before', I do not want my 'for' snippet to be expanded.

You should use a stricter trigger for the snippet. For example, `\bfor` will only expand if `for` starts at a word boundary. Similarly, you can use `^` to match the start of a line.

### How did you do the demo?

It's done using kitty's remote control features, a 'manuscript' and a script to bridge the two. I'll upload them at some point.

## Similar extensions

https://github.com/alexherbo2/snippets.kak  
https://github.com/shachaf/kak/blob/master/scripts/snippet.kak  

## License

Unlicense
