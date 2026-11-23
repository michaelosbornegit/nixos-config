---
name: status-sweep
description: One-shot status report for a repo with several agent threads in flight — every open session/worktree and PR, whether each PR is ready to merge, what can be closed out, loose ends, and preview links to test — in one fixed format ending with the calls the user needs to make. Read-only. Trigger on "what are all the open threads and PRs", "are they ready to merge", "which ones can we close out", "any loose ends", "give me preview links", "status sweep", "where are we", or any request to take stock of parallel work in the current project.
---

# Status sweep

Answer "what's open, what's ready, what can go, what's loose, where do I click" for the current repo, always in the same shape. **Read-only:** never merge, close, archive, delete branches or worktrees, or message sessions during the sweep — those are the calls the report hands back to the user.

## 1. Gather

Run both, in parallel:

- **PRs and git state:** `~/.claude/skills/status-sweep/scripts/gather.sh` from anywhere in the repo (takes ~1s per PR). Add `--all` if the user asks about everyone's PRs, `--days N` to widen the recently-merged window (default 3). It prints JSON: `openPRs` (checks, review, unresolved threads, preview links), `recentlyClosedPRs`, `worktrees` (each tagged with its open `pr` or `closedPR`), and `localBranches`.
- **Threads (agent sessions):** whatever this harness offers — `mcp__ccd_session_mgmt__list_sessions` (limit 50) in the desktop app, `ListAgents` in the CLI. Keep only sessions whose `cwd` is inside this repo's root (worktrees under `.claude/worktrees/` included). Each gives title, branch, `prNumber`/`prState`, `isRunning`, `lastActivityAt`. With neither tool, the worktrees are the threads.

Join threads ↔ PRs ↔ worktrees by branch name (and `prNumber` when the session has one).

Only for PRs that look ready or nearly ready, skim what's unknown from the JSON: `gh pr view <n> --comments` for the latest human comment and anything the bot reviewers flagged. Don't deep-read every PR.

## 2. Classify

**PR verdict** — exactly one each:

| Verdict | When |
|---|---|
| ✅ Ready | not draft · checks green (none failing or pending) · `mergeState` CLEAN · approved, or no review required · 0 unresolved threads |
| 🟡 Almost | one small thing: pending checks, behind base (`BEHIND`), awaiting a review, a draft that otherwise passes, or 1–2 unresolved threads |
| 🔴 Blocked | failing checks, `CONFLICTING`/`DIRTY`, changes requested, or stacked on another open PR that hasn't merged (its `base` is another open PR's `branch`) |
| 🗑 Close | superseded by another PR, its work already landed, abandoned (no activity in ~2 weeks and no thread working on it), or an experiment the user has moved past |

A PR whose base is another open PR's branch is stacked: say so and name the order the stack merges in. A base that is a long-lived branch other than the default (`try/uat`, `staging`) is not a stack — note the target in the Next step column instead (e.g. "Merge → uat").

**Thread state** — exactly one each: **Working** (running) · **Waiting on you** (idle with a question or approval pending) · **Done → archive** (its PR merged/closed, or its task finished with nothing open) · **Stale** (idle, no PR, nothing since ~3 days).

## 3. Loose ends

Look for, and list only what's actually present:

- Dirty or unpushed worktrees (`dirtyFiles > 0`, `unpushed > 0`), especially with no PR — work that only exists on this disk.
- Worktrees whose PR merged or closed (`closedPR`), and detached/scratch worktrees under `/private/tmp` — prunable.
- Local branches merged into the default branch or with upstream gone — give the count, not the list.
- Follow-ups promised in merged PRs or session recaps that have no PR or ticket.
- Failing checks on the default branch, and PRs that are green but behind base.

## 4. Report — always this format

```markdown
## Status sweep — <owner/repo> · <YYYY-MM-DD HH:MM>

**Bottom line:** <N> ready to merge · <N> almost · <N> blocked · <N> to close · <N> threads running · <N> threads to archive

### PRs
| PR | Verdict | Checks | Review | Preview | Next step |
|---|---|---|---|---|---|
| [#123](url) Short title | ✅ Ready | ✓ 18/18 | Approved | [branch](alias-url) | Merge |
| [#124](url) Short title | 🔴 Blocked | ✗ `lint`, `test` | — | [branch](alias-url) | Fix lint (thread `name` is on it) |

### Threads
| Thread | State | PR | Next step |
|---|---|---|---|
| [Title](#local_id) | Working | #124 | Let it finish |
| [Title](#local_id) | Done → archive | #120 merged | Archive |

### Close out
- #<n> — <why it can go> · or thread/worktree — <why>

### Loose ends
- <one line each, most important first>

### Calls for you
1. <the decision or action, one line, most valuable first — e.g. "Merge #123 (green, approved) → then #125 rebases cleanly">
2. ...
```

Format rules:

- **Order PR rows** ✅ → 🟡 → 🔴 → 🗑, then by most recently updated. Same for threads: Waiting on you → Working → Done → Stale.
- **Checks column:** `✓ passed/total` when green, `… n pending` when running, `✗` plus the failing check names when red.
- **Preview column:** prefer the branch alias from `previews.botLinks` (it tracks the latest push); fall back to `previews.deployments[].url`; if a deployment's `state` isn't `success`, write it (`building`, `failed`). `—` when there is none. Never invent a URL.
- **Links:** PRs as `[#n](url)`; in the desktop app, threads as `[title](#local_<id>)` using the exact id from `list_sessions`.
- Omit an empty section rather than writing "none", except **Calls for you**, which always appears (say "Nothing needs you right now" if so).
- More than ~15 PRs: show ✅/🟡/🔴 rows in full, and collapse 🗑 candidates into the Close out list.
- Keep every cell short; reasoning goes in Calls for you, not the tables.

## 5. After the report

Offer to carry out the calls the user picks — merge, close with a comment, archive sessions, prune worktrees and merged branches — and do each only on their go-ahead. Merging or closing a PR is outward-facing: confirm which PRs by number before acting.
