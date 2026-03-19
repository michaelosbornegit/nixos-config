---
name: track-work
description: Log completed work to a weekly markdown file in ~/task-tracking. Use whenever a meaningful piece of work is done — generating a plan, implementing a feature, exploring a codebase, fixing a bug, etc. Also invocable manually via /track-work to add items from outside Claude. Entries are grouped by day within each week file, include timestamp, and one-line description.
allowed-tools: Read, Write, Glob, Bash(date *), Bash(mkdir *)
---

# Track Work Skill

Log completed work to weekly markdown files in `~/task-tracking/`.

## When to Use (Automatic)

Invoke this skill whenever a meaningful unit of work completes in a conversation, such as:
- Generating or finalizing a plan
- Implementing a feature or fix
- Exploratory investigation of a codebase or problem
- Creating documentation or a spec
- Debugging and resolving an issue
- Setting up infrastructure or configuration

Use good judgment — minor clarifications or back-and-forth don't warrant a log entry, but any concrete output does.

## Manual Invocation

When the user runs `/track-work <description>`, log that description as-is. If no description is provided, ask the user what they'd like to log.

## Process

### 1. Get Current Date & Time

```bash
date '+%Y %V %u %A %b %d %H:%M'
```

This returns: `YEAR ISO-WEEK-NUMBER DAY-OF-WEEK(1=Mon) FULL-DAY-NAME MONTH DAY TIME`

Example output: `2026 08 2 Tuesday Feb 17 14:32`

Parse:
- **Year**: field 1 (e.g., `2026`)
- **Week number**: field 2, zero-padded to 2 digits (e.g., `08`)
- **Day abbreviation**: first 3 letters of field 4, title-cased (e.g., `Tue`)
- **Date label**: `{Mon-abbrev}, {Month} {Day}` (e.g., `Tue, Feb 17`)
- **Time**: field 7 (e.g., `14:32`)

### 2. Determine File Path

```
~/task-tracking/YYYY-WNN.md
```

Example: `~/task-tracking/2026-W08.md`

### 3. Read Existing File (if it exists)

Use Glob to check: `~/task-tracking/*.md`
Then Read the week file if it exists.

### 4. Build the Entry Line

```
- HH:MM — <one-line description of what was done>
```

Example:
```
- 14:32 — Implemented JWT authentication middleware for the API
```

### 5. Update the File

#### File Structure

```markdown
# Week YYYY-WNN

## Mon, Feb 17
- 09:15 — Explored codebase structure for auth system

## Tue, Feb 18
- 14:32 — Implemented JWT authentication middleware
- 16:45 — Fixed token refresh bug in auth flow
```

#### Rules

- If the file doesn't exist, create it with the `# Week YYYY-WNN` header followed by the day section and entry.
- If the file exists but the **day section** (e.g., `## Tue, Feb 18`) doesn't exist, append a new day section at the end of the file.
- If the file exists and the day section exists, append the new entry line directly after the last existing entry under that day's section (before the next `##` heading or end of file).
- Never reorder or reformat existing content — only append.
- Use a blank line between day sections for readability.

### 6. Write the File

Write the updated content back to `~/task-tracking/YYYY-WNN.md`.

## Output to User

After logging, output a single confirmation line:

```
Logged: <description> [YYYY-WNN, Day HH:MM]
```

Example:
```
Logged: Implemented JWT authentication middleware [2026-W08, Tue 14:32]
```

No other output needed.
