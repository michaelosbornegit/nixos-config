# Posting mechanics

A user has at most one pending review per PR. Before creating one, check for an existing pending review of theirs (`pull_request_read` `get_reviews`, state `PENDING`) and add to it instead of failing.

Pin the review to the head commit you reviewed (`commitID` / `commit_id`). If the PR head moved since the hunk, re-check each anchor against the new head before adding comments.

## GitHub MCP tools (preferred when connected)

1. First approval: `pull_request_review_write` with `method: "create"`, `commitID`, and **no `event`**. That creates the pending review.
2. Each approved inline comment: `add_comment_to_pending_review` with `path`, `line`, `side: "RIGHT"`, `subjectType: "LINE"`, plus `startLine` and `startSide: "RIGHT"` for a range. Paths are repo-relative.
3. Each approved general comment: keep its text; it goes into the review body at submit, separated by a horizontal rule, in finding order.
4. At the end, after the user picks the event: `pull_request_review_write` with `method: "submit_pending"`, `event` (`COMMENT`, `REQUEST_CHANGES`, `APPROVE`), and `body` (the collected general comments, or empty).
5. Confirm with `pull_request_read` `get_reviews` / `get_review_comments` and give the user the review URL.

## `gh` fallback

Hold the approved comments locally, then post the whole review in one call at submit time:

```bash
cat > review.json <<'EOF'
{
  "commit_id": "<sha>",
  "event": "COMMENT",
  "body": "<collected general comments>",
  "comments": [
    { "path": "src/x.ts", "line": 95, "start_line": 77, "side": "RIGHT", "start_side": "RIGHT", "body": "..." }
  ]
}
EOF
gh api repos/<owner>/<repo>/pulls/<n>/reviews --method POST --input review.json
```

Omit `start_line` / `start_side` for a single-line comment. Write `review.json` in the temp directory, never in the repo.

## Anchors

An inline comment must land on a line inside a diff hunk on the chosen side. A line outside every hunk (an unchanged file, a line far from any change) is rejected; post that comment as general instead and name the `path:line` in its text.
