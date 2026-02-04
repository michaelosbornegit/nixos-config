---
name: pr-review
description: Review and fix issues from a GitHub Pull Request code review. Use when addressing PR feedback, fixing review comments, or resolving code review threads.
disable-model-invocation: true
allowed-tools: Bash(gh *), Read, Edit, Grep, Glob
---

# PR Review Workflow

Review and fix issues from a GitHub Pull Request code review, handling each issue one at a time with immediate commit, push, and thread resolution.

## Process

### 1. List Open PRs and Ask User to Select

```bash
gh pr list --state open
```

Prompt the user to select which PR to review.

### 2. Get Repository Info

Get the owner and repo name for API calls:

```bash
gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
```

### 3. Fetch PR Review Comments

Get all review comments. **Save the `id` field from each comment** - this is the comment_id needed to reply to that specific thread.

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments
```

Each comment in the JSON response has:
- `id` - **THIS IS THE COMMENT ID YOU NEED FOR REPLIES**
- `path` - the file path
- `line` or `original_line` - line number
- `body` - the reviewer's comment text

### 4. Process Each Issue ONE AT A TIME

**CRITICAL: Complete ALL steps (A through H) for each issue before moving to the next.**

#### Step A: Present the Issue

```
## Issue #1 of N

**Reviewer Comment:** [exact comment text]
**File:** path/to/file.ts:47
**Comment ID:** 1234567890

**Current Code:**
[show code]

**Proposed Fix:**
[show fix]

**Apply this fix?**
```

#### Step B: Get User Approval

Wait for approval before proceeding.

#### Step C: Apply the Fix

Make the code change.

#### Step D: Commit

```bash
git add path/to/file.ts
git commit -m "Fix: description of fix"
```

#### Step E: Push

```bash
git push
```

#### Step F: Reply to the Review Comment Thread

**⚠️ CRITICAL: DO NOT USE `gh pr comment` - that comments on the PR, NOT the thread!**

You MUST use the GitHub API to reply directly to the review comment thread:

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments/COMMENT_ID/replies -f body="Fixed in commit abc1234.

Explanation of what was changed."
```

**Example with real values:**
```bash
gh api repos/VMG-Health/bval_automation_portal/pulls/8/comments/1234567890/replies -f body="Fixed in commit abc1234.

Added null check before accessing the property."
```

The COMMENT_ID is the `id` field from the comment JSON you fetched in Step 3.

#### Step G: Resolve the Thread (Optional)

If you have permission to resolve threads:

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "PRRT_xxxx"}) {
      thread { isResolved }
    }
  }
'
```

#### Step H: Move to Next Issue

Only after completing A-G, proceed to the next comment.

### 5. Final Summary

After all issues:
- Total issues found
- Issues fixed (with commits)
- Issues skipped
- PR link

## ⚠️ Common Mistakes to Avoid

1. **WRONG:** `gh pr comment 8 --body "Fixed"` - This comments on the PR, not the thread!
2. **RIGHT:** `gh api repos/OWNER/REPO/pulls/8/comments/COMMENT_ID/replies -f body="Fixed"`

3. **WRONG:** Batching all commits and pushing at the end
4. **RIGHT:** Commit and push after EACH fix

5. **WRONG:** Using placeholder text like `<comment-id>` in commands
6. **RIGHT:** Use the actual numeric ID from the comment JSON (e.g., `1234567890`)
