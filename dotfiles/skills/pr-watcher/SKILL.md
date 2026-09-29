---
name: pr-watcher
description: Stand up standing watches on the user's open PRs — keep each branch current with main, triage bot reviews (Copilot or other review bots) autonomously within tight bounds, merge when approved, and escalate human reviews, judgment calls, and disagreements to the user. The watch rides with the session that implemented the work, so comment responses reuse implementation context instead of re-analyzing the codebase. Trigger on "watch my PRs", "babysit my PRs", "nanny my open PRs", "pr-watcher my PRs", "keep my PRs current with main and merge when approved", or when a spawned build session's PR needs a standing watch.
---

# PR watcher — standing watches on open PRs

## The model

One watcher per open PR, and the watcher is the session that holds the PR's implementation context: the build session that shipped the branch, or the assess/review session that last worked it. Resume that session with the standing-watch brief (below); spawn a fresh session via the spawn-claude-subagent skill only when no context session is alive — a fresh watcher's brief must then bootstrap context (read the PR diff, the linked ticket, and any `/tmp/*-report.md` files from the sessions that built or assessed the PR).

Each watcher reports to the main thread its ticket work was spawned from — never to a thread it wasn't spawned from.

Why per-PR context sessions: responding to review comments requires the implementation context; a resumed session already has it, a fresh one re-analyzes the codebase on every comment. Why not one watcher for all PRs: per-PR context and per-thread continuity beat single-writer convenience. The one-session-per-branch rule still holds because each watcher touches only its own branch.

## Standing rules (bake all of them into every watcher brief)

1. **Merges are watcher-managed, not GitHub-managed.** Do NOT request or use the repo's "Allow auto-merge" setting; merges stay under the watcher's control. A watcher squash-merges its PR when ALL hold: not draft · an approving review satisfying branch protection · required checks green · every review thread resolved.
2. **Merge main forward, even with a live approval, when the repo requires up-to-date branches** (`strict` required status checks) — a stale branch can't merge otherwise, so the merge-forward is the required path. With `dismiss_stale_reviews_on_push`, a push may dismiss the approval: verify the review state after each push, and if an approval is dismissed, the re-approval ask goes through the user, never to the reviewer directly. The flow: merge forward → checks re-run → merge on approval + green + resolved threads.
3. **Merge main in, never rebase, never force-push.** Branches under review keep their history. Conflict resolution beyond trivial (import/ordering/adjacent-line) escalates.
4. **Bot findings** (Copilot, other review bots, scanners): refute-first assessment per finding, then **the watcher's own judgment decides whether a human weighs in** — "mechanical" is not the gate. Already-addressed or moot → reply citing the evidence commit + resolve. Real, and the watcher agrees and is confident in the fix → implement it (additive commit), reply citing the commit, resolve — substantive fixes included; the report line names the judgment call. Escalate only when the watcher itself judges a human should weigh in: it's unsure of the fix, two reasonable resolutions exist, the change touches behavior/security/data/contracts in a way a reviewer should bless, or it believes the bot is wrong but arguable. ("Mechanical," where the term is still useful, means verifiably correct without design judgment — a diff that cannot change behavior.)
5. **Human reviews are guided, never autonomous.** Any human comment, changes-requested, or review-requested-of-the-user → summarize, draft the reply, escalate via peer message AND PushNotification. The user drives the response; the watcher never replies to a human reviewer on its own.
6. **Escalate, don't repeat.** Known-red states (named per PR in the brief) are reported once, not on every poll. Same for a failure seen on 3+ consecutive runs.
7. **Scope.** Only the assigned PR and its branch. Never main, never other people's PRs, never issue-tracker writes, never PR-body or ticket edits. Drafts are watched but never merged; when a draft looks ready (green, threads resolved) → ask the user about flipping it.
8. **On merge**: send `MERGED — #<n> — <one line>` to the spawning thread + PushNotification, disarm the watch, go idle — the session remains the context-holder for that ticket's follow-ups.
9. **The spawning thread reconciles the ticket** after a watcher merge lands (ticket state, follow-on unblock messages), not the watcher.
10. **Signal-only reporting**, so the spawning thread stays readable. Peer messages only for MERGED events, escalations needing the user's decision, and BLOCKED. Routine main-merges, acks, watch-armed confirmations, and green check runs go to the watcher's report file, never the thread. PushNotifications are for escalation-class events only.
11. When in doubt, escalate. A wrong escalation costs thirty seconds; a wrong autonomous action costs a review cycle.

## The watch mechanism

The watcher arms a persistent Monitor (or background until-loop) polling every ~180s via `gh`, emitting one event line per state change on its PR: main's HEAD moved · new review, comment, or review thread · check-rollup state changed · approved / changes requested · draft flipped · PR merged or closed externally. List endpoints only; deep-read on change. Each event wakes the session to act per the rules. Quiet PRs cost nothing between events.

## Standing one watcher up

1. Inventory: `search_pull_requests repo:<org>/<repo> is:pr is:open author:<user>` — name the exact set to the user before dispatching (merged/closed PRs drop out; other people's PRs are out of scope).
2. Per PR, find its context session in `ListAgents` (build session first, then assess, then adversarial-review). Resume it with the brief template below via SendMessage. No live session → spawn via spawn-claude-subagent with the template plus: "First, build context: read the PR diff, the linked ticket, and these reports: <paths>."
3. Fill the template's slots: PR number/title/branch, the spawning thread's exact `ListAgents` name, the per-PR known-red list, and parked decisions (things the watcher must neither fix nor re-escalate).
4. Report the dispatch to the user in one or two lines: which PRs have watchers, which already merged, which are drafts.

## Expandability

Every future build/research spawn (spawn-claude-subagent) gets this line appended to its brief: "When your task completes and your work has an open PR, you become its standing watch — the spawning thread will send you the pr-watcher standing-watch brief; your context is why the watch lives with you." New PRs then acquire watchers without a design session, and ticket follow-ups stay in the thread that spawned the work.

## The standing-watch brief template

Send this to the chosen session with the slots filled:

```
You are now the standing PR watcher for PR #<N> (<title> — branch `<branch>`) in <org>/<repo>, owned by <user>. The watch lives with you because you hold this work's context. Standing role until the PR merges or <user> relieves you. Your reporting thread is "<spawning thread's exact ListAgents name>" — the thread your work was spawned from.

Watch loop: arm a persistent Monitor polling every ~180s via `gh`, emitting one event line per STATE CHANGE on your PR: main's HEAD moved; new review, comment, or review thread; check-rollup state changed; approved / changes requested; draft flipped; PR merged or closed by someone else. List endpoints only, deep-read on change. Act on each event per the rules below.

Autonomous (act, then one terse line to your thread):
- main moved → merge `origin/main` into `<branch>` (never rebase, never force-push), resolve only trivial conflicts (import/ordering/adjacent-line), push, confirm checks re-run. This applies even with a live approval when the repo requires up-to-date branches; after the push, verify the review state — if the approval was dismissed, escalate for re-approval rather than asking the reviewer.
- New Copilot / review-bot / scanner output → refute-first per finding: already-addressed or moot → reply citing the evidence commit + resolve the thread; real, and you agree and are confident in the fix → implement it (additive commit), reply citing the commit, resolve — substantive fixes included; "mechanical" is not the gate, your judgment is. Your one-line report names the judgment call you made.
- Not draft + approval satisfying branch protection + required checks green + all threads resolved → `gh pr merge <N> --squash`, then `MERGED — #<N> — <one line>` to your thread + PushNotification, disarm the watch, go idle.

Escalate (peer message to your thread AND PushNotification; act only on <user>'s reply):
- Any HUMAN review activity — a human comments, requests changes, or a review is requested of <user>. Summarize + draft the reply; <user> guides. Never reply to a human reviewer autonomously.
- A bot finding where a human should weigh in, by YOUR judgment: you're unsure of the fix, two reasonable resolutions exist, it touches behavior/security/data/contracts in a way a reviewer should bless, or you believe the bot is wrong but arguable — draft both sides.
- Non-trivial conflicts; the same failure on 3+ runs; a draft PR that looks ready to flip.

Never: rebase or force-push (merge main in instead); touch main or any other branch/PR; merge a draft; ask a human reviewer for anything yourself (re-approval asks go through <user>); use or request GitHub's auto-merge setting (merges are watcher-managed, deliberately); issue-tracker writes; PR-body edits.

Known states — report once, then do not re-escalate: <per-PR list>

When in doubt, escalate.
```
