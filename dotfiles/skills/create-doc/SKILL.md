---
name: create-doc
description: Create a technical doc in ~/docs based on the current conversation. Use with a topic argument to write about a specific subject, or with no arguments to auto-detect the most recently discussed topic.
allowed-tools: Read, Write, Glob, Grep
---

# Create Documentation Skill

Write a technical reference document to `~/docs/` based on the current conversation context.

## Behavior

### If ARGUMENTS are provided:
- Treat the argument as the **topic** to document
- Review the conversation history for everything discussed about that topic
- Gather all relevant details: decisions made, commands run, configurations, architecture, code changes, issues encountered, and solutions

### If NO arguments are provided:
- Identify the **most recently discussed topic** in the conversation
- Use that as the subject for the doc

## Process

1. **Always create a new file.** Never update an existing doc — each invocation produces a distinct file. If a file with the same name already exists, append a numeric suffix (e.g., `swa-linked-backend-2.md`).

2. **Check existing docs** for reference:
   ```
   Glob: ~/docs/*.md
   ```
   Read related docs for context and to avoid repeating background info unnecessarily, but still create a new file.

3. **Gather context** from the conversation:
   - What problem was being solved?
   - What decisions were made and why?
   - What commands or configurations were used?
   - What's the current state vs target state?
   - Any gotchas, issues encountered, or lessons learned?

4. **Write the doc** to `~/docs/<topic-name>.md` using kebab-case for the filename.

## Document Format

Follow this structure (include only sections that are relevant):

```markdown
# Title

Brief description of what this doc covers.

**Date:** YYYY-MM-DD

---

## Context / Problem Statement

Why this doc exists. What problem was being solved.

## Current State

What's in place today. Include resource names, configurations, architecture diagrams.

## Decisions Made

Key decisions and their rationale.

## Implementation Details

Commands, configurations, code changes. Include actual values used (resource names, settings) so this is a concrete reference, not abstract guidance.

## Architecture

ASCII diagrams showing how components connect.

## Issues & Lessons Learned

Problems encountered and how they were resolved. Gotchas for future reference.

## Next Steps / TODO

Outstanding work or future improvements.
```

## Style Guidelines

- **Be concrete, not abstract.** Use actual resource names, real commands, real config values. These docs are operational references, not tutorials.
- **Include CLI commands** that were run or would need to be run to reproduce the setup.
- **Use tables** for comparing options, listing resources, or showing configurations.
- **Use ASCII architecture diagrams** when the topic involves multiple components.
- **Use code blocks** with language hints for commands, SQL, JSON, C#, TypeScript, etc.
- **Keep it scannable.** Use headers, bullet points, and bold for key terms.
- **Date the doc** so it's clear when the information was captured.
- **No fluff.** Skip introductory paragraphs and get straight to the content.
