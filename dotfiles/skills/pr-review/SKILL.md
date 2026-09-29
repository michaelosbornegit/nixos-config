---
name: pr-review
description: Adversarially review someone's GitHub pull request, write a findings report, then walk the user through each finding one at a time in plain terms, drafting review comments they approve into a single pending review. Use when asked to review a PR, stress-test or try to break a PR, or draft review comments for one.
---

# PR review

You are the **reviewer**, trying to break the PR: every way it is wrong, incomplete, or misdescribed. Findings, not style verdicts. The work has two halves: a **hunt** that ends in a report file, then a **walk-through** where the user decides, finding by finding, what gets said on the PR.

Guardrails for the whole run:

- **Read-only on the PR.** Inspect and run code in a scratch worktree; the PR branch, the user's checkout, and every shared system (databases, trackers, the PR itself) stay untouched until the user approves an outward action.
- **Evidence or it isn't a finding.** Every claim carries `file:line` or command output you produced this session. Cite only what you verified; when later research changes an earlier claim, correct it openly, including in a later comment.

## 1. Orient

1. Identify the PR (number or URL; ask if none was given). Read `gh pr view <n> --json title,body,files,headRefName,baseRefName,commits` and the diff.
2. Create a scratch worktree of the PR head in a temp directory (`$CLAUDE_JOB_DIR/tmp` when set): `git fetch origin <head>` then `git worktree add --detach <dir> origin/<head>`. Install dependencies there if you will run code.
3. Read the **authority** for the change: the linked ticket (Linear, GitHub issue, Jira: whatever tool is connected) with its comments and blockers; any spec, ADR, or research the ticket cites; and, for a port or rewrite, the original source it claims fidelity to. If a source is unreachable, say so and verify against what the ticket states.
4. Read the repo's agent guide (`AGENTS.md` / `CLAUDE.md`) for the gate command, conventions, and lint fences.

Done when you can state the PR's definition of done (or, absent a ticket, its stated intent) as a checklist, and you know the command that is the repo's CI gate.

## 2. Hunt

Go through the change **adversarially** along every axis that applies:

- **Definition of done**: each bullet verified empirically, not by reading the PR body.
- **Fidelity**: for a port, diff each file against its source; a dropped edge case is a finding.
- **PR-body honesty**: every claim in the description checked against the diff and against what you ran.
- **Fence**: files touched outside the ticket's scope; out-of-scope consumers still compiling and behaving the same.
- **Blockers and merge**: blocking tickets actually resolved; `git merge-tree --write-tree origin/<base> HEAD` is clean.
- **Guards and tests**: each guard exists in code *and* has a test that fires it; probe the guard with inputs the tests don't cover.
- **Your own gate run**: run the repo's CI gate in the scratch worktree and record your counts, not the body's.

Probe with throwaway files inside the scratch worktree only (a scratch test file run by the repo's test runner is usually the fastest harness). Give each finding a severity (**blocker / major / minor / nit**), its evidence, and a one-line fix.

Done when every definition-of-done bullet and every PR-body claim has a verdict with evidence, and the gate has run.

## 3. Write the report

Always write a report file, the durable record other agents and later sessions read. Default path `/tmp/pr<n>-review.md` unless a brief names one. Use the layout in [references/report.md](references/report.md).

If you were spawned by another agent with a reporting contract, send the result it asks for (pointing at the report path) and stop here: the walk-through needs the human.

Done when the report is on disk and you have told the user its path, the verdict, and the count by severity.

## 4. Walk through, one finding per turn

Take the findings in severity order. For **each** finding, in its own turn:

1. **Research it further before drafting.** Reproduce it; try the proposed fix in the scratch worktree and run the affected tests; look for who already owns it (other tickets, follow-ups) and for counter-evidence. Research may **upgrade**, **downgrade**, or **drop** the finding; say which and why.
2. **Present** under these headings:
   - **In plain terms**: what is wrong and why it matters, in a few sentences a non-specialist follows. Lead with this, before any table or code.
   - **What the research showed**: the evidence, briefly.
   - **My take**: your honest recommendation, including "drop this" when the finding is weak.
   - **Draft comment**: the exact text, with its anchor (`path:line` or a line range on the PR head for an inline comment; "general" otherwise). Comment style: a bold one-sentence claim, what you tested, the suggested fix as code, kept short.
3. **Ask**: post it, change it, or skip it. Then wait for the user.

If the user is confused, re-explain in plainer terms and offer a plainer draft; the plain version is usually the better comment too.

Take each line number for an inline anchor from a single-file listing of the PR head (`grep -n`, or `sed -n` on that one file), never from a multi-file `cat`, and confirm the line sits inside a diff hunk.

Done when every finding has been posted, changed then posted, or skipped by the user.

## 5. Post as one review

"Post" means **add to one pending review**, not publish. Create the pending review on the first approval, add each approved inline comment to it, and collect approved general comments into the review body. After the last finding, show the user the full pending review (inline count, body text) and ask which event to submit with (Comment, Request changes, Approve), then submit once. Mechanics for the GitHub MCP tools and the `gh` fallback: [references/posting.md](references/posting.md).

Done when the review is submitted with the event the user chose and you have the review's URL.

## 6. Clean up and report back

Remove the scratch worktree (`git worktree remove --force <dir> && git worktree prune`), delete probe files outside it, and confirm the user's checkout shows only the changes it had before. Final message: the review link, what was posted, what was skipped and why, how findings changed during research, and follow-ups worth ticketing (offer; create nothing without approval).
