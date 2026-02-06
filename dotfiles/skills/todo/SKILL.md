---
name: todo
description: Create or manage todo items as markdown files in ~/todos. Creates a new file per todo, named with the current project and a short description. Use with a description argument, or say "list" to see existing todos.
allowed-tools: Read, Write, Glob, Grep, Bash(ls *), Bash(rm *)
---

# Todo Skill

Manage todo items as individual markdown files in `~/todos/`.

## Creating a Todo

### File Naming

Each todo is a separate markdown file. The filename encodes the **project** and a **short description**:

```
~/todos/<project-name>--<short-description>.md
```

- **project-name**: Derived from the current working directory's folder name (e.g., if working in `/Users/mosborne/development/repos/bval_automation_portal`, use `bval-automation-portal`)
- **short-description**: A few kebab-case words summarizing the todo, derived from the user's request
- Use `--` (double dash) to separate project from description
- Example: `bval-automation-portal--add-managed-identity-to-sql.md`

### File Content

```markdown
# <Short description of the todo>

**Project:** <project folder name>
**Created:** YYYY-MM-DD

## Details

<Expanded description based on conversation context. Include relevant details like file paths, resource names, commands, or links that would be helpful when picking this up later.>
```

Keep the content concise but include enough context to act on it without needing to re-read the whole conversation.

### Rules

- **Always create a new file** for each todo. Never append to or modify an existing todo file.
- **Exception:** If the user explicitly asks to update, edit, or append to a specific existing todo, then modify that file.

## Listing Todos

If the user says "list todos", "show todos", or similar:

1. Glob for `~/todos/*.md`
2. Group by project prefix (everything before `--`)
3. Display as a simple list grouped by project

## Completing / Removing Todos

If the user says to complete, remove, or delete a todo:

1. List matching todos
2. Confirm which one
3. Delete the file
