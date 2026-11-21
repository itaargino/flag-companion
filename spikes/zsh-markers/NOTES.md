# zsh markers spike: notes

What I learned in the first item of backlog E5, while running the hook sketch from the spec inside a PTY and reading the bytes zsh prints with `cat -v`.

## How to run it

```bash
python3 -I capture.py zdotdir captures/basic.raw basic
cat -v captures/basic.raw | sed 's/\^G/^G\n/g'
```

`capture.py` starts `zsh` as a login shell inside a PTY, with `ZDOTDIR` pointing at the folder given as the first argument. It then types one of the scenarios (`basic`, `edges`, `vim`) and saves every byte to `captures/`, which git ignores. In `cat -v`, `^[` is ESC and `^G` is BEL, the byte that ends an OSC sequence.

| Folder | What it tests |
| --- | --- |
| `zdotdir/` | The spec as written: a `.zshrc` that loads `~/.zshrc`, then `hooks.zsh` |
| `zdotdir-starship/` | Starship without a `PROMPT` override |
| `zdotdir-rewrite/` | A theme that rebuilds `PS1` before every prompt, like Powerlevel10k |
| `zdotdir-forward/` + `hooks-forward.zsh` | The proposed fix, described at the end |
| `fake-user/` | A user config for the fix, chosen with `FC_USER_ZDOTDIR` |

## The sketch works

With my real `~/.zshrc` (Starship, then a fixed `PROMPT`), one command produces:

```
^[]7770;cmd;bHM=^G        preexec: "ls" in base64
^[]133;C^G                preexec: output starts
capture.py  hooks.zsh^M   the output
<PROMPT_SP noise>         see below
^[]133;D;0^G              precmd: exit code
^[]7;file://MacBook-Pro-67.local/Users/...^G
^[]133;A^G                precmd: prompt starts
isaque@MacBook-Pro-67 ~/... % ^[]133;B^G
```

`ls`, `false` and `python3 -c 'print(1)'` gave `D;0`, `D;1` and `D;0`, the same three pairs as the "Done when" for E5.

## Surprises the parser has to handle

- **A `D` arrives before the first prompt**, with no command open. The spec already says to ignore it.
- **An empty Enter also produces a `D`**, with no `7770` and no `C` before it. It carries the exit code of the previous command, so it must be ignored too. The spec's rule ("a `D` with no open command is ignored") covers this case, but the spec only mentions the first prompt.
- **`PROMPT_SP` noise comes before the `D`.** zsh prints `%`, a full line of spaces and `\r \r` after every command, so that output without a final newline is not hidden by the prompt. These bytes fall between `C` and `D`, so they become part of the command's output. After removing ANSI and applying the `\r` rule, they leave a trailing line of spaces that should be trimmed.
- **Line editor echo comes between `B` and `7770`**, for example `l^Hls`, plus bracketed paste mode (`ESC[?2004h` / `ESC[?2004l`). In the `prompt` state the parser drops everything except markers, so none of this reaches the log.
- **Ctrl+C gives `D;130`**, which is 128 + SIGINT. Output is just `^C`.
- **A multi-line command produces one `7770`** with the newline inside the base64. The continuation prompt (`PS2`, `∙` from Starship) emits no `A` or `B`.
- **`exit` gets `7770` and `C` but never a `D`**, because the shell is gone. `session_end` with `shell_exited` has to close the open command.
- **`vim` shows `ESC[?1049h` and `ESC[?1049l` between `C` and `D`**, as E7 expects.
- **`$HOST` is `MacBook-Pro-67.local`** in OSC 7, with the `.local` suffix.

## Problem 1: the spec's ZDOTDIR breaks the user's shell

With `ZDOTDIR` pointing at the app's folder, zsh reads every startup file from there, not only `.zshrc`:

- `HISTFILE` became `.../zdotdir/.zsh_history`. macOS's `/etc/zshrc` builds it from `${ZDOTDIR:-$HOME}`, so the user's history would disappear inside the app.
- The user's `~/.zshenv`, `~/.zprofile` and `~/.zlogin` would never load. I don't have them, but Homebrew's `brew shellenv` usually lives in `~/.zprofile`, so `PATH` would break for many people.

## Problem 2: themes that rebuild PS1 drop the B marker

The real Starship kept `B` on all 4 prompts, because it sets `PROMPT` only once. The theme in `zdotdir-rewrite/` sets `PS1` again in its own `precmd`, and `B` appeared on 0 of 4 prompts.

`B` is not essential, though: the state machine in the spec never uses it. `A`, `7770`, `C` and `D` are enough.

## Hook order

`precmd_functions` was `prompt_starship_precmd _fc_precmd`: the hooks run in the order they were registered. Our `D` still read the right `$?` after Starship's hook ran. (Later test: zsh restores `$?` before each `precmd` function, so a hook before ours cannot change it either; see "Real themes".)

## Proposed fix (tested)

`zdotdir-forward/` holds only a `.zshenv`. It sets `ZDOTDIR` back to the user's value (`$HOME` when they had none), loads their `.zshenv` and registers the hooks from `hooks-forward.zsh`. zsh evaluates `ZDOTDIR` again before each startup file, so it then reads the user's `.zprofile`, `.zshrc` and `.zlogin` from the usual place.

`hooks-forward.zsh` splits `precmd` in two:

- `_fc_status` writes `D` and, on every prompt, moves itself to the start of `precmd_functions` and `_fc_prompt` to the end.
- `_fc_prompt` writes `7` and `A`, and adds `B` back to `PS1` when a theme removed it.

Results:

- `HISTFILE` is `~/.zsh_history` again, and the user's `.zshenv` loads.
- With `fake-user/` (a theme that rebuilds `PS1` and a hook that runs `true`), exit codes stayed correct (`D;1` for `false`).
- `B` was missing only on the first prompt. zsh had already started walking the hook list when `_fc_status` reordered it, so the new order only applies from the second prompt on.
- My real `~/.zshrc` behaves exactly as with the spec's version.

## What to change in the spec

- Step 3 of "Terminal capture": the app's `ZDOTDIR` should hold only a `.zshenv` that hands `ZDOTDIR` back to the user, instead of a `.zshrc` that loads theirs.
- Point 4 of "Terminal capture": ignore any `D` with no open command, not only the first one.
- Point 5 of "Terminal capture": trim the `PROMPT_SP` line from the end of the output.
- A command still open when the shell exits (`exit`) is closed by `session_end`.

## Real themes (after the spike)

Run with the app's hooks (`hooks-forward.zsh`) and an isolated `HOME` per case, so nothing in the real `~` was read or changed. Oh My Zsh `c014070` and Powerlevel10k `50a35cc` were shallow clones kept outside the repo; the `order` scenario in `capture.py` prints `precmd_functions`.

| Setup | `C` + command text | `D` codes (`ls`, `false`, `python3`, Ctrl+C) | `B` |
| --- | --- | --- | --- |
| Default prompt, empty `HOME` | All commands | 0, 1, 0, 130 | Every prompt |
| Oh My Zsh, `robbyrussell`, `git` plugin | All commands | 0, 1, 0, 130 | Every prompt, sometimes twice in a row |
| Powerlevel10k (lean), instant prompt on | All commands | 0, 1, 0, 130 | Never |
| Oh My Zsh + Powerlevel10k | All commands | 0, 1, 0, 130 | Never |

What this showed:

- **The parser can rely on `A`, `C` and `D` with every setup tested.** The multi-line command, the empty Enter and `exit` behave as in the earlier captures.
- **Powerlevel10k never has `B`, not only on the first prompt.** It reorders `precmd_functions` itself before every prompt, to `_p9k_do_nothing … _p9k_precmd`, so `_p9k_precmd` always runs after `_fc_prompt` and rebuilds `PS1` without our marker. The two hooks would keep moving each other, so the app does not fight it: the parser already ignores `B`.
- **Oh My Zsh can emit `B` twice** when the prompt is redrawn without a new command. Another reason not to count on `B`.
- **zsh restores `$?` before each `precmd` function.** A hook whose only command is `false`, placed before ours, still let ours read the command's real status (`SAW=7` after `(exit 7)`), and `_p9k_do_nothing` (`true`) ran before `_fc_status` without changing `D`. This corrects "Hook order" above: putting `_fc_status` first is not needed for `$?`.
- **Instant prompt printed no warning** about console output during startup, because our hooks print only in `precmd` and `preexec`.
- **With an empty `HOME`, the first `D` is `D;1`**, the status left by the startup files. It comes before any command, so the rule that ignores a `D` with no open command covers it.

## Still open

- ~~Testing with a real Oh My Zsh and a real Powerlevel10k~~: done, see "Real themes" below.
- ~~Choosing the OSC number~~: decided after the spike. `7770` is used by the termprompt project, so the command text moved into `OSC 133;C;cmdline_url=<URL-escaped>` (kitty's extension). `hooks-forward.zsh` now matches the app; `hooks.zsh` and the captures above still show the original sketch.
