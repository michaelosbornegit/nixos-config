---
name: ghostty-state-tint
description: Install, verify, and repair the Ghostty background state tint for Claude Code — the terminal background goes faintly green while Claude is working and faintly rose while it waits on you, driven by settings.json hooks that call ~/.claude/ghostty-bg. Use this skill whenever the tint isn't working, stopped working, is stuck on one colour, fires on the wrong events, or needs setting up on a new or freshly rebuilt machine; also whenever the user wants the colours changed, fainter, stronger, or the tint switched off. Trigger on things like "the background isn't going green any more", "my terminal is stuck pink", "set the terminal tint up on this box", "why is my ghostty background changing colour", "the claude hooks aren't firing", or any mention of the terminal background reflecting Claude's state — even when the user names neither this skill nor the script.
---

# Ghostty state tint

The terminal background signals whether Claude is busy or waiting: faint green while
working (including subagents and workflows), faint rose the moment it wants input.
It works by writing an OSC 11 escape sequence to the tty from Claude Code hooks.

## The four moving parts

Knowing which part is broken is most of the work, because they fail in different ways.

| Part | Where | Notes |
|---|---|---|
| the script | `~/development/repos/nixos-config/dotfiles/ghostty-bg` | POSIX sh, writes OSC 11. Takes `working`, `idle`, `attention`, or `reset` |
| the colours | `…/dotfiles/ghostty-bg.conf` | sourced by the script; the script also carries identical built-in defaults as a fallback |
| the symlinks | `hosts/home-common.nix` | `home.file` + `mkOutOfStoreSymlink` puts both at `~/.claude/`, so edits flow back to git |
| the hooks | `~/.claude/settings.json` | **not** nix-managed |

`settings.json` is deliberately left out of nix. Claude Code writes to it itself, and if it
ever writes via temp-file-plus-rename, that would replace a symlink with a regular file and
silently strand the repo copy. Merging the hooks in (see below) avoids betting on that.

Because `~/.claude/ghostty-bg` is a **symlink into the repo**, editing it edits the repo
file. Never assume there is a separate local copy to change.

## Always start by diagnosing

```bash
scripts/check.sh
```

It verifies the environment, both files, the symlink target, every hook event, path
portability, and then actually fires the script and confirms it resolved a tty. Exit 0 means
there is nothing to fix — say so and stop rather than changing things. Otherwise fix only
what it reports. Run it from inside the Ghostty session being diagnosed, since several
checks read the calling process's environment and tty.

It leaves the background in the `working` tint, which is correct mid-turn — the `Stop` hook
restores `idle` when the turn ends.

## Fixing what it reports

**Hooks not wired**, or wired with an absolute path from another machine:

```bash
scripts/install-hooks.sh          # DRY_RUN=1 to preview
```

Idempotent, and it merges per-event rather than replacing `.hooks`, so unrelated hooks
survive — there is a sound/flash hook on `Stop` that must not be clobbered. It backs up
to `settings.json.tint-bak` and refuses to touch malformed JSON. Prefer it over hand-written
jq; getting the non-destructive merge right is exactly what it exists for.

**Hooks wired but nothing fires.** Claude Code's settings watcher may not have reloaded.
You cannot fix this from inside the session — tell the user to open `/hooks` once, or
restart. Confirm by `touch ~/.claude/ghostty-bg.debug`, doing anything that runs a tool,
then reading `~/.claude/ghostty-bg.log`. Remove the flag afterwards so the log stops growing.

**Files missing or the symlink dangles.** Either the repo isn't cloned at
`~/development/repos/nixos-config` (`dotfilesPath` hardcodes that path, so every symlink
dangles otherwise), or home-manager hasn't been rebuilt since the declaration was added.
Rebuilding needs sudo, so it is the user's to run: `osupgrade`. As a stopgap you may create
the symlinks by hand — `backupFileExtension = "hm-bak"` is set on both hosts, so activation
will move them aside rather than abort.

**Script not executable.** The hooks exec it directly, so `chmod +x` the repo file. Check
`git ls-files -s` shows `100755`; if the mode bit is lost in git it will break on the next
clone.

**`NO-TTY` in the log.** The ancestor walk found no controlling terminal. Hooks run detached
(`/dev/tty` is "device not configured"), which is why the script walks up the process tree to
the ancestor that still owns one — normally the `claude` process — and writes to that device
directly. If this fails, check `ps -o ppid=,tty= -p <pid>` works on this system.

**A tint stuck after a crash.** `~/.claude/ghostty-bg reset`. `SessionEnd` handles clean
exits, but a killed session leaves whatever was last set.

**Nothing happens at all, and check.sh said NOTE not FAIL.** Under a non-Ghostty terminal or
inside tmux/zellij the script exits 0 without writing, by design — tinting a multiplexer
would colour the whole window instead of the pane. Also check for `~/.claude/no-bg-tint`,
the deliberate off switch. `reset` ignores that switch on purpose, so turning tinting off
can still clear a tint that is already on screen.

## The event map

`references/hooks.json` is the canonical desired state. The reasoning behind it:

| Event | State | Why |
|---|---|---|
| `UserPromptSubmit` | working | turn begins |
| `PostToolUse`, `PostToolUseFailure` | working | also re-asserts green after a permission pause, which nothing else covers. `async` so it adds no latency |
| `Notification` | attention | permission prompt or question waiting |
| `Stop`, `StopFailure` | idle | turn over, including errored turns |
| `SessionStart` | idle | fresh session, `/clear`, resume |
| `SessionEnd` | reset | back to the theme background |

`SubagentStop` is deliberately absent: a finished subagent does not mean the main agent is
done, so wiring it would flash "your turn" mid-work. Nothing is wired to
`PermissionRequest` either — `Notification` already covers that case, and keeping hooks out
of the permission path avoids any risk of interfering with a permission decision.

Two known boundaries worth stating rather than debugging: interrupting with Esc may not fire
`Stop`, so green can linger until `Notification` trips on idle; and `SessionEnd` cannot be
verified from inside a live session.

## Changing the colours

Edit `ghostty-bg.conf`. Keep the script's built-in defaults in sync — they are the fallback
if the conf goes missing, and a silent mismatch is confusing later. The background is
`#f9f9f9` (Ghostty's Atom One Light theme), and the intent is **barely-there** tints — only
a hue cast off white, never a visible wash. Start subtler than instinct suggests; the usual
mistake is overshooting, and a tint that reads as "coloured" rather than "faintly lit" is
too strong.

For a neutral terminal when merely idle, with rose only when Claude actually needs
something, set `BG_IDLE='#f9f9f9'` and leave `BG_ATTENTION` tinted. That is a one-line
change and needs no hook edits.

## Cross-platform notes

Written for macOS and Linux; the tty naming differs and both are handled — macOS `ps` prints
`ttys005` and `??` for none, Linux prints `pts/3` and a single `?`. Hook commands use
`"$HOME/.claude/ghostty-bg"` in shell form rather than the exec form, because exec form does
not expand `~` or `$HOME` and would hardcode one machine's home directory.

The flash/sound hook on `Stop` is macOS-only (`afplay`), but it ends in `|| true`, so
it fails harmlessly elsewhere and is not this skill's problem.

## Reporting back

Fix what you can and be specific about what you could not. The three things that genuinely
need the user are: running `osupgrade` (sudo), reloading via `/hooks` or a restart when the
watcher is stale, and confirming the `SessionEnd` reset by exiting once. Say plainly which
of those remain, rather than implying everything is verified.
