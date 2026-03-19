---
name: extraction-compare
description: Compare our system's Excel model output against an analyst answer key using parallel subagents. Reports missing sections, missing rows, value differences, and extra data.
allowed-tools: Bash, Read, Write, Glob, Grep, Agent
---

# Extraction Compare — Parallel Subagent Excel Comparison

Compare two Excel files by dumping each tab to pipe-delimited text, then launching parallel subagents to analyze differences. No external API calls needed — uses Claude Code agents for free, fast comparison.

## Prerequisites

- **Two Excel files**: The user must provide:
  1. **Our output** (what our system produced)
  2. **Answer key** (the "correct" file — analyst-completed reference)
- **Formula recalculation**: If our output is a `.xlsm` file downloaded from the server, it **must** be opened in Excel and saved (Cmd+S) before comparing.

## Step 1: Dump both Excel files to text

Run the following Python script to extract all tabs from both files into `/tmp/compare/`:

```bash
nix-shell -p python312Packages.openpyxl python312Packages.pyxlsb --run "python3 << 'PYEOF'
import os, sys
from pathlib import Path

OUTPUT_DIR = '/tmp/compare'
os.makedirs(f'{OUTPUT_DIR}/ours', exist_ok=True)
os.makedirs(f'{OUTPUT_DIR}/answer', exist_ok=True)

OUR_FILE = '{{OUR_FILE}}'
ANSWER_FILE = '{{ANSWER_FILE}}'

TABS = ['IS Input', 'BS Input', 'FFS Input', 'Payor Input', 'Detail', 'NRP Adj.']

def dump_xlsx(filepath, out_dir, tabs):
    from openpyxl import load_workbook
    wb = load_workbook(filepath, data_only=True, read_only=True)
    available = wb.sheetnames
    for tab in tabs:
        if tab not in available:
            print(f'  SKIP: {tab} (not in file)')
            continue
        ws = wb[tab]
        lines = []
        for row in ws.iter_rows(values_only=True):
            cells = [str(c) if c is not None else '' for c in row]
            lines.append('|'.join(cells))
        safe_name = tab.replace(' ', '_').replace('.', '_').replace('/', '_')
        out_path = f'{out_dir}/{safe_name}.txt'
        with open(out_path, 'w') as f:
            f.write('\n'.join(lines))
        print(f'  OK: {tab} -> {out_path} ({len(lines)} rows)')
    wb.close()

def dump_xlsb(filepath, out_dir, tabs):
    from pyxlsb import open_workbook
    with open_workbook(filepath) as wb:
        available = wb.sheets
        for tab in tabs:
            if tab not in available:
                print(f'  SKIP: {tab} (not in file)')
                continue
            lines = []
            with wb.get_sheet(tab) as ws:
                for row in ws.rows():
                    cells = [str(c.v) if c.v is not None else '' for c in row]
                    lines.append('|'.join(cells))
            safe_name = tab.replace(' ', '_').replace('.', '_').replace('/', '_')
            out_path = f'{out_dir}/{safe_name}.txt'
            with open(out_path, 'w') as f:
                f.write('\n'.join(lines))
            print(f'  OK: {tab} -> {out_path} ({len(lines)} rows)')

def dump_file(filepath, out_dir, tabs):
    ext = Path(filepath).suffix.lower()
    print(f'Parsing {filepath} ({ext}):')
    if ext in ('.xlsx', '.xlsm'):
        dump_xlsx(filepath, out_dir, tabs)
    elif ext == '.xlsb':
        dump_xlsb(filepath, out_dir, tabs)
    else:
        print(f'ERROR: Unsupported extension {ext}')
        sys.exit(1)

dump_file(OUR_FILE, f'{OUTPUT_DIR}/ours', TABS)
dump_file(ANSWER_FILE, f'{OUTPUT_DIR}/answer', TABS)
print('Done.')
PYEOF"
```

Replace `{{OUR_FILE}}` and `{{ANSWER_FILE}}` with actual paths. Adjust `TABS` if the user requests specific tabs.

## Step 2: Launch parallel subagents

For each tab that was successfully dumped from BOTH files, launch a subagent in parallel using the Agent tool. **Launch ALL tab agents in a single message** for maximum parallelism.

Each agent prompt should be:

```
Compare these two Excel tab dumps and report differences. This is tab "{{TAB_NAME}}" from a financial model.

**Our output (system-generated):**
File: /tmp/compare/ours/{{SAFE_TAB_NAME}}.txt

**Answer key (analyst reference):**
File: /tmp/compare/answer/{{SAFE_TAB_NAME}}.txt

Read both files, then analyze:

1. **Missing Sections** — sections/groups in the answer key but absent from our output
2. **Missing Rows** — rows with data in the answer key but empty/missing in our output
3. **Value Differences** — cells where both files have data but values differ. Report as: Row identifier | Our value | Expected value. Ignore rounding differences ≤$1. Ignore blank vs zero differences.
4. **Extra Data** — data in our output that doesn't appear in the answer key
5. **Summary** — overall accuracy assessment (percentage match estimate)

IMPORTANT context:
- Column positions may differ between files (our output may have different column offsets than the answer key)
- Use row labels/identifiers to match rows, not position
- Financial values: treat 1234 and 1,234 and $1,234 and 1234.00 as equivalent
- "Open" slots in specialty sections are expected for unused groups — don't report these as differences
- Focus on MEANINGFUL differences that affect the financial model accuracy

Keep your response concise — bullet points, not paragraphs. Only report actual differences, not things that match.
```

Use `subagent_type: "general-purpose"` and `model: "sonnet"` for speed.

## Step 3: Present results

After all agents return, compile a summary:
- Group findings by tab
- Highlight the most impactful differences first
- If findings match known deferred issues from BUGFIX_PLAN.md, note that they're already tracked
- Give an overall accuracy estimate

## Tab name → safe filename mapping

| Tab Name | Safe Filename |
|---|---|
| IS Input | IS_Input.txt |
| BS Input | BS_Input.txt |
| FFS Input | FFS_Input.txt |
| Payor Input | Payor_Input.txt |
| Detail | Detail.txt |
| NRP Adj. | NRP_Adj_.txt |

## Cost

**$0** — all comparison is done by Claude Code subagents within the current session. No external API calls.
