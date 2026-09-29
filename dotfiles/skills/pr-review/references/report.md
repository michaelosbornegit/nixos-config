# Report layout

The report is the hand-off: another agent or a later session should be able to act on it without this conversation. Write it as Markdown, facts first, each claim with its evidence.

```markdown
# Review: PR #<n> (<ticket>, <title>)

Reviewed head `<sha>` (branch `<head>`, merge-base `<sha>`) in a scratch worktree. Sources read: <ticket, spec, original source; say which were unreachable>.

**Verdict: <approve / approve with changes / request changes>.** <counts by severity, one or two sentences on the biggest findings and what holds up>.

## Findings (severity-ranked)

| # | Sev | Finding | Evidence | Fix (one line) |
|---|---|---|---|---|

## Definition of done, bullet by bullet

| DoD | Status | Evidence |
|---|---|---|

## Fidelity (for a port or rewrite)

What matches the source, what was added deliberately, what was dropped.

## Fence, blockers, merge

## PR-body claims checked

| Claim | Holds? |
|---|---|

## Gate run

The exact command and your counts (files, tests passed / failed / skipped, exit code).
```

Keep probe descriptions reproducible: the input you built, the command, the output line that proves the finding.

During the walk-through, update the report when a finding is upgraded, downgraded, or dropped, so the file stays the source of truth after the conversation ends.
