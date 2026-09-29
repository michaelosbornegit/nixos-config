---
name: spawn-claude-subagent
description: Spawn a fresh, named Claude Code session in the background — visible and resumable in the session/agent panel (left arrow in the terminal) — with its own system prompt and a self-contained task, no forked context. Use whenever the user wants to create a new Claude session or agent "in the agent view", delegate a task to a separate named Claude session, run a helper with clean context, or avoid the messy inherited context of forking. Trigger on phrases like "spawn an agent", "start another Claude session", "give this task its own session", "create an agent I can see in the panel".
---

# Spawn a named background Claude session

## What this is for

Three delegation mechanisms exist, and they are not interchangeable:

| Mechanism | In the session panel | Context | Best for |
|---|---|---|---|
| Fork | yes | inherits the whole conversation | the human branching off interactively |
| Agent tool (in-session subagent) | no (`/tasks` only) | fresh, prompt-only | quick fire-and-forget work inside this session |
| `claude --bg` (this skill) | **yes** | **fresh, prompt-only** | a durable, named, resumable helper session |

Use this skill when the user wants a session they can see, open, and resume — but built from a clean slate with a purpose-written prompt, rather than forked from a conversation full of irrelevant context.

## The command

```bash
claude --bg \
  -n "<display name>" \
  --append-system-prompt "<the role this session plays>" \
  --dangerously-skip-permissions \
  "<the task, fully self-contained>"
```

- `--bg` starts the session in the background and prints its session id plus management commands.
- `-n` sets the display name shown in the session panel. Keep it short and human-readable.
- `--append-system-prompt` gives the session its role. This is the closest thing to a custom system prompt.
- `--dangerously-skip-permissions` is the default here (see Permissions below). Drop it for tasks where a stall is acceptable or the human plans to attach.
- The task is a **positional argument**. Do not pass `-p` / `--print` — it conflicts with `--bg` and the spawn will fail, because a headless print run never creates the attachable session the panel shows.

The new session starts in the current working directory with no memory of this conversation.

## The context package (the part that makes or breaks this)

The spawned session knows nothing about how the task came up. Before running the command, assemble everything it needs to succeed *from scratch*:

1. **The task itself**, stated completely — not "do the thing we discussed", which resolves to nothing in a fresh context.
2. **Concrete anchors**: absolute file paths or repo-relative paths, branch names, URLs, error text. It cannot ask "which file did you mean?" without a round-trip.
3. **Decisions and constraints from this conversation** it must honor: conventions to follow, approaches already rejected, definitions of done.
4. **Reporting instructions**: where to write its result, plus the reporting contract — who to message on completion or block, and the report path (see below).

For anything longer than a few sentences, don't fight shell quoting inside the command. Write the full brief to a file first and make the positional task a pointer:

```bash
claude --bg -n "<name>" --append-system-prompt "<role>" \
  "Read /tmp/<name>-brief.md and carry out what it says."
```

This keeps the command readable and the brief editable. Put the brief somewhere the new session can read: `/tmp`, the repo (if it should be committed), or its working directory.

## Permissions

A background session that hits a permission prompt stalls until a human attaches to answer it — which usually defeats the point of spawning it. So:

- **Default: `--dangerously-skip-permissions`** (yolo mode). The spawned session runs uninterrupted. Every session started in the same directory with the same user already shares the project and user `settings.json` allowlists, so configured permission rules still apply; this flag only removes the interactive asking.
- **A mode toggled interactively in the spawning session cannot be inherited** — there is no flag for "whatever mode the main thread is in right now". If you need something less than full bypass, pass `--permission-mode <mode>` explicitly (e.g. `acceptEdits` for edit-heavy work that should still gate dangerous Bash calls).
- **Omit the flag entirely** only when the user says they will attach and answer prompts themselves. **"The task is read-only" is not a reason to omit it** — read-only bounds the damage a bypassed session can do, not whether it gets prompted: MCP tool calls, CLI commands, and file access outside the project directory (the `/tmp` brief itself included) all raise prompts, and the session stalls on the first one it hits. A bypassed read-only session is safe *because of its brief* — put the constraints there (next paragraph).

Because the default is full bypass, the brief should be explicit about what the session is and is not allowed to do (e.g. "make changes on branch X only", "do not run migrations"). The session will follow written instructions the same way it follows the system prompt — that is the safety rail once permission gates are gone.

## Getting results back

The default is a **control-plane pattern**: the main thread never polls; the spawned session notifies it. Every spawn's brief carries a **reporting contract** with three parts:

1. **One peer message on completion or block**, via SendMessage, to the spawning session by name. The spawner must look up its own name (the `ListAgents` header line) and bake it into the brief — the new session cannot guess who to report to. The message is two lines or fewer, in a fixed terse format:

   ```
   DONE — <one line: what shipped / the result> — full report: <path>
   BLOCKED — <one line: what is in the way / what direction is needed> — full report: <path>
   ```

   Never paste the report body into the message. The main thread is a control plane: it relays status to the user in one or two lines and opens the report file only when depth is wanted.
2. **The full report still goes to a file regardless** — peer messaging can be unavailable; the file is the fallback record, not the notification.
3. **Interim messages are rationed**: at most one interim peer message per genuinely blocking question; everything else accumulates into the final report. The control plane must not be spammed.

When the completion message lands, give the user an extremely concise update — did the agent complete its task, does it need more direction — and name the report path. One or two lines. Do not summarize the report unprompted.

Alternatives when peer messaging is unavailable:

- **Pure file-based**: tell the session to write its final report to a specific path; the spawning session opens it when depth is wanted. This is why the contract above keeps the file regardless — nothing depends on messaging.
- **Human attach**: the user runs `claude attach <id>` (the id is printed at spawn time) and reads the transcript directly.

## Managing spawned sessions

The spawn output prints the id and these commands:

```bash
claude agents            # list sessions
claude attach <id>       # open it in this terminal
claude logs <id>         # recent output without attaching
claude stop <id>         # stop it
```

The session also appears in the panel the user opens with the left arrow, where it can be opened and resumed like any other session.

After spawning, **assume the session is running** — do not sleep, poll, or check its logs. With `--dangerously-skip-permissions` (the default) there is no permission prompt to stall on, and the completion message is the notification. `claude logs <id>` and `claude attach <id>` remain available purely as on-demand diagnostics if the human asks or a result is suspiciously late — never as a post-spawn ritual.

Do not arm a polling watcher on the report file — the completion message IS the notification (see Getting results back). The one legitimate exception: for long-running or crash-prone tasks, a **dead-man's-switch** — a background until-loop that fires once if the report file appears or the session dies silently without messaging. That is an option for tasks that can die quietly, not the pattern.

## When not to use this

- **Trivial tasks.** Every spawned session pays a baseline cost (its own system prompt and tool definitions, roughly 70k+ tokens) before doing any work. "What's 1+1" does not need a session; answer it inline.
- **Tight back-and-forth delegation.** If you just need work done and a result returned to this conversation, the in-session Agent tool is cheaper and simpler. Reach for this skill when *the session itself* is the point — a named, visible, resumable worker.
- **Tasks needing conversation history.** If the work only makes sense with the full context of this conversation, a fork (or an Agent tool `fork`) is the honest tool, messiness included.
- **Genuinely dangerous work under bypass mode.** The default `--dangerously-skip-permissions` removes the safety net, so for destructive or irreversible tasks (migrations, deletions, force-pushes), either drop the flag and accept that the session stalls until someone attaches, or don't delegate it this way at all.
