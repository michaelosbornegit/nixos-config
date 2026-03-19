---
name: regression-suite
description: Run extraction regression tests across multiple USPI projects. Manages baselines, runs extraction, compares against answer keys, and detects regressions.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__read_console_messages, mcp__claude-in-chrome__read_network_requests, mcp__claude-in-chrome__navigate
---

# Regression Suite — Multi-Project Extraction Testing

Run one or all USPI projects through the extraction pipeline, compare against analyst answer keys, and detect regressions from baselines.

## Usage

```
/regression-suite                     → Run all projects, compare against answer keys
/regression-suite merced              → Run only Merced
/regression-suite rock-hill --baseline → Compare against both answer key AND baseline
/regression-suite all --baseline      → Full regression with baseline comparison
/regression-suite --reextract         → Skip upload, just re-extract + download + compare (fastest iteration)
/regression-suite merced --reextract  → Re-extract single project
/regression-suite --status            → Show current state of all projects (engagement IDs, baseline dates, last run)
```

## Prerequisites

- **Local server running** at `http://localhost:5224` in Development mode
- **Auth token** at `/tmp/.bval_token` — only needed for **fresh engagement creation** (Steps 3-5). Re-extraction, download, and comparison all use dev endpoints (no auth).
- **Projects config** at `~/.claude/skills/regression-suite/projects.json` (symlinked to `~/.bval-toolkit/projects.json`)
- **No API key needed** — comparison uses Claude Code subagents (free)

## Projects Config

The projects config at `~/.claude/skills/regression-suite/projects.json` stores per-project metadata. Load it at the start of every run.

```json
{
  "projects": {
    "merced": {
      "displayName": "Merced",
      "orgId": "USPI",
      "valuationYear": 2025,
      "sourceDir": "~/.bval-toolkit/merced/source-files",
      "answerKey": "~/.bval-toolkit/merced/output/answer-key.xlsb",
      "baselineDir": "~/.bval-toolkit/merced/baselines",
      "outputDir": "~/.bval-toolkit/merced/runs",
      "engagementId": null,
      "fileMapping": {}
    }
  }
}
```

### Config fields

| Field | Description |
|-------|-------------|
| `displayName` | Human-readable project name |
| `orgId` | Organization ID for engagement creation (`"USPI"`) |
| `valuationYear` | Valuation year — determines period slots. **Never guess this.** |
| `valuationDate` | (Optional) ISO date for stub-year engagements (e.g., `"2025-06-30"`). Controls YTD period end dates. Omit for Dec 31 fiscal years. |
| `companyState` | (Optional) State abbreviation (e.g., `"CA"`, `"TN"`) |
| `sourceDir` | Directory containing source Excel files to upload |
| `answerKey` | Path to the analyst-completed reference model |
| `baselineDir` | Directory for storing baseline outputs and reports |
| `outputDir` | Directory for storing run outputs (timestamped) |
| `engagementId` | Saved engagement ID for re-extraction (null = needs fresh engagement) |
| `fileMapping` | Map of `documentType` → `fileName` (established on first run) |

### First-time setup for a new project

When `engagementId` is null or `fileMapping` is empty, run the full setup flow:

1. Ask user for `valuationYear` if not set
2. Create engagement via `/api/engagements`
3. Get document slots
4. Ask user to map source files to document types (or infer from filenames + prior mappings)
5. Upload files
6. Trigger extraction for all documents
7. Download full model
8. Save `engagementId` and `fileMapping` back to projects.json
9. Run comparison against answer key
10. If `--baseline` flag: save the output as the baseline

## Workflow

### Step 0: Token Check

```bash
if [ -f /tmp/.bval_token ]; then
  EXP=$(cat /tmp/.bval_token | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('exp',0))")
  NOW=$(date +%s)
  if [ "$EXP" -gt "$NOW" ]; then
    echo "Token valid until $(date -r $EXP)"
  else
    echo "Token expired — need refresh"
  fi
else
  echo "No token found — need to acquire"
fi
```

If expired/missing, extract from Chrome using the same method as extraction-test:
1. `mcp__claude-in-chrome__tabs_context_mcp`
2. `mcp__claude-in-chrome__javascript_tool` to extract MSAL token from sessionStorage
3. `mcp__claude-in-chrome__read_console_messages` with pattern `__BVAL_TOKEN__`
4. Save to `/tmp/.bval_token`

### Step 1: Load Projects Config

```bash
cat ~/.claude/skills/regression-suite/projects.json
```

Determine which projects to run based on arguments:
- No args or `all` → run all projects
- Project name → run only that project

### Step 2: For Each Project — Extract or Re-extract

**Run projects sequentially** (one at a time) to avoid LLM API throttling. Concurrent extraction across multiple projects overwhelms the OpenAI API rate limits and causes extremely slow runs.

**If `--reextract` flag (fastest iteration loop):**

Skip upload. Use saved `engagementId`. Use the **batch extraction endpoint** — one call extracts all docs in parallel, no auth needed:

```bash
curl -s -X POST "http://localhost:5224/api/dev/extract-all/$ENGAGEMENT_ID?force=true" | \
  jq '{succeeded, failed, documents: [.documents[] | {documentType, success, fieldsExtracted, elapsedMs}]}'
```

This is ~6x faster than extracting documents one at a time. Each document gets its own DI scope for thread safety. The endpoint is synchronous — wait for it to return before downloading.

**If fresh run (no engagement ID):**

Requires auth token for Steps 1-3 only. Check/refresh token first, then:
1. Create engagement with project's orgId and valuationYear (auth)
2. Get document slots (auth)
3. Upload files per fileMapping (auth)
4. Trigger batch extraction: `POST /api/dev/extract-all/{engId}?force=true` (no auth)
5. Save engagementId to projects.json

### Step 3: Download Full Model

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/model_${TIMESTAMP}.xlsm"
mkdir -p "$OUTPUT_DIR"

# Dev endpoint — no auth needed
curl -s -o "$OUTPUT_FILE" -w "%{http_code}" \
  "http://localhost:5224/api/dev/download-full-model/$ENGAGEMENT_ID"
```

### Step 3.5: MANDATORY — Open Model in Excel for Formula Recalculation

**CRITICAL: You MUST prompt the user to open the downloaded `.xlsm` file in Excel and save it (Cmd+S) before comparing.** The downloaded model contains formulas that haven't been recalculated — restated sections, reconciliation totals, projections, and balance checks will ALL show as zeros until Excel recalculates them.

**Do NOT skip this step. Do NOT proceed to comparison without user confirmation that the file has been opened and saved.**

Tell the user:
```
Please open the downloaded model in Excel and save it (Cmd+S) to recalculate formulas:
open "$OUTPUT_FILE"
```

Wait for the user to confirm before proceeding to Step 4.

### Step 4: Compare Against Answer Key

Use the `/extraction-compare` approach — dump both files to text, then launch parallel Claude Code subagents to analyze each tab. This is **free** (no API calls) and runs entirely within Claude Code.

1. **Dump both Excel files to pipe-delimited text** using the Python script from the extraction-compare skill (see that skill for the full script). Set `OUR_FILE` to the downloaded model and `ANSWER_FILE` to the project's `answerKey` path.

2. **Launch parallel subagents** — one per tab — using the Agent tool with `model: "sonnet"`. Each agent reads its tab pair from `/tmp/compare/ours/` and `/tmp/compare/answer/` and reports differences.

3. **Save the compiled report** to `$OUTPUT_DIR/report_${TIMESTAMP}.md`.

### Step 5: Compare Against Baseline (if `--baseline` flag)

If a baseline exists at `$BASELINE_DIR/baseline.xlsm`:

1. Dump the current model and the baseline model to text (same Python script, different file paths)
2. Launch parallel subagents comparing each tab
3. Save to `$OUTPUT_DIR/regression_${TIMESTAMP}.md`

### Step 6: Save Baseline (if `--save-baseline` flag)

```bash
mkdir -p "$BASELINE_DIR"
cp "$OUTPUT_FILE" "$BASELINE_DIR/baseline.xlsm"
cp "$OUTPUT_FILE" "$BASELINE_DIR/baseline.xlsx"
cp "$REPORT_FILE" "$BASELINE_DIR/baseline_report.md"
echo "$(date -Iseconds)" > "$BASELINE_DIR/baseline_date.txt"
```

Keep `baseline.xlsx` and `baseline.xlsm` identical. The comparison step reads `baseline.xlsx`, so saving only `baseline.xlsm` leaves a stale regression target.

### Step 7: Consolidated Report

After running all projects, produce a summary:

```
## Regression Suite Results — {date}

### Merced
- **Answer Key Comparison**: [path to report]
- **Baseline Comparison**: [path or "no baseline"]
- **Status**: {summary of key findings}

### Rock Hill
- **Answer Key Comparison**: [path to report]
- **Baseline Comparison**: [path or "no baseline"]
- **Status**: {summary of key findings}

### Regression Summary
- New issues introduced: {count}
- Issues fixed since baseline: {count}
- Unchanged issues: {count}
```

Read each project's answer-key report and summarize:
- **Improvements**: Things in the answer-key report that are NOW correct (weren't in baseline)
- **Regressions**: Things that WERE correct in baseline but are NOW wrong
- **Unchanged**: Issues present in both baseline and current run

### Tabs to Compare

Only compare these tabs: **IS Input, BS Input, FFS Input, Payor Input, Detail, NRP Adj.**

The following are **intentionally excluded** from comparison:

- **Staff Input tab** — staff wages extraction is not in scope.
- **Dist. tab** — distributions extraction is not in scope.
- **Budget column in IS Input** — the rightmost budget column in IS Input is not checked. Differences in budget data should be ignored when summarizing IS Input findings.

## Issue Categorization

When reporting issues from comparisons, categorize each finding:

| Category | Description | Risk Level | Action |
|----------|-------------|------------|--------|
| **A: Profile Config** | Missing search terms, wrong field keys in JSON | Low | Fix extraction profile JSON |
| **B: Code Fix** | Wrong values, misclassification in service logic | Medium | Fix service code, regression test |
| **C: Formatting** | Name formatting, alphabetization, presentation | Low-Medium | Fix template filler / model service |
| **D: Feature Gap** | Entirely missing functionality (TTM, NRP, etc.) | High | New implementation needed |
| **E: Data Quality** | Bad source data, format variations, judgment calls | N/A | Flag for client discussion |

This helps prioritize: A-fixes first (lowest risk), then C, then B, then D.

## Directory Structure

After several runs, the structure looks like:

```
~/.bval-toolkit/
├── .env
├── projects.json
├── rock-hill/
│   ├── source-files/
│   ├── output/
│   ├── baselines/
│   │   ├── baseline.xlsm
│   │   ├── baseline_report.md
│   │   └── baseline_date.txt
│   └── runs/
│       ├── model_20260309_143000.xlsm
│       ├── report_20260309_143000.md
│       └── regression_20260309_143000.md
├── merced/
│   └── ...
└── tullahoma/
    └── ...
```

## Re-extraction Loop (Fastest Iteration)

After making a code change to profiles/services:

1. `npm run build:server` (rebuild the API)
2. Restart the server (`npm run start:server`)
3. `/regression-suite --reextract` (re-extract all projects, download, compare)

This skips engagement creation and file upload — just re-runs extraction on already-uploaded files.

## Gotchas

| Mistake | What happens | Prevention |
|---------|-------------|------------|
| Forgetting to rebuild server | Old extraction logic runs | Always `npm run build:server` before re-extract |
| Token expired between projects | Auth'd endpoints fail | Only needed for fresh engagement creation. Re-extract and download use dev endpoints (no auth). |
| Wrong valuationYear in config | Period columns misalign | Verify VY from reference engagement or answer key |
| Comparing wrong files | Misleading report | Always use timestamped outputs, never overwrite |
| Running --baseline without a baseline | Nothing to compare against | Run `--save-baseline` first |
| Saving only `baseline.xlsm` | Future regression compares read stale `baseline.xlsx` and report false diffs | Always copy the recalculated model to both `baseline.xlsm` and `baseline.xlsx` |
| Not opening model in Excel before comparing | Formulas show as zeros — restated sections, reconciliation, projections all empty | **ALWAYS** prompt user to open .xlsm in Excel and Cmd+S before comparing. Never skip this step. |
| Batch extract response parse error | jq filter fails on unexpected fields | Use minimal jq: `jq '{succeeded, failed}'` — don't reference fields that may not exist |
| Baselines generated inconsistently | Comparison quality varies | Use the same comparison approach (subagents with sonnet) for all baselines |

## Improving the Toolchain

As you run the regression suite, you will encounter friction, bugs, or missing capabilities in the underlying skills and tools. **Actively suggest improvements.**

### What to look for

- **extraction-test pain points**: Steps that are error-prone, unclear, or could be automated better. Missing gotchas that cost time. Token acquisition issues. File mapping friction.
- **extraction-compare accuracy**: False positives (flagging acceptable differences as issues). False negatives (missing real differences). Structural differences the LLM gets confused by. Prompt improvements that would yield more actionable output.
- **This skill (regression-suite)**: Workflow steps that should be reordered, combined, or split. Missing flags or options. Config schema gaps.

### How to suggest improvements

After each regression suite run, include a **Toolchain Notes** section at the end of the consolidated report:

```
### Toolchain Notes

**extraction-compare**: [describe issue and suggested fix]
**extraction-test**: [describe issue and suggested fix]
**regression-suite**: [describe issue and suggested fix]
```

Only include entries where you have a concrete observation from the current run — don't pad with generalities.

### When to make the fix vs just suggest it

- **Fix immediately**: Typos, wrong paths, outdated instructions, clearly broken commands in any skill
- **Suggest to user**: Behavioral changes to comparison prompts, new CLI flags, workflow reordering, schema changes — anything that changes how the tools work for the user
- **Log for later**: Vague ideas or optimizations that aren't blocking — add these to `~/.claude/skills/regression-suite/toolchain-improvements.md` so they accumulate and can be reviewed in batch

### Skill file locations (for making edits)

| Skill | Path |
|-------|------|
| extraction-test | `~/.claude/skills/extraction-test/SKILL.md` |
| extraction-compare | `~/.claude/skills/extraction-compare/SKILL.md` |
| regression-suite | `~/.claude/skills/regression-suite/SKILL.md` |

## Codebase Reference

| What | Path |
|------|------|
| Dev endpoints | `server/BvalAutomationPortal.Api/Endpoints/DevAuthEndpoints.cs` |
| Extraction profiles (USPI) | `server/BvalAutomationPortal.Api/Configuration/ExtractionProfiles/uspi/` |
| Input tab mappings (USPI) | `server/BvalAutomationPortal.Api/Configuration/InputTabMappings/uspi/` |
| Client documents config | `server/BvalAutomationPortal.Api/Configuration/ClientDocuments/uspi.json` |
| Excel model service | `server/BvalAutomationPortal.Api/Services/ExcelModelService.cs` |
| LLM extraction service | `server/BvalAutomationPortal.Api/Services/LlmExtractionService.cs` |
| Document extraction service | `server/BvalAutomationPortal.Api/Services/DocumentExtractionService.cs` |
| Excel template filler | `server/BvalAutomationPortal.Api/Services/ExcelTemplateFiller.cs` |
| Comparison approach | `/extraction-compare` skill (free, subagent-based) |
