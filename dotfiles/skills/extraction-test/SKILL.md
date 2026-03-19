---
name: extraction-test
description: Run extraction regression tests — create engagements, upload files, trigger extraction via dev endpoints, download models, and compare against analyst answer keys.
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__read_console_messages, mcp__claude-in-chrome__read_network_requests, mcp__claude-in-chrome__navigate
---

# Extraction Regression Test

End-to-end extraction test: upload source documents, extract via dev endpoints, download output models, compare against analyst answer keys.

## Prerequisites

- **Local server running** at `http://localhost:5224` in Development mode (dev endpoints are only registered in Development)
- **Auth token**: A valid JWT token must be saved to `/tmp/.bval_token` — only needed for Steps 3-5 (create engagement, get doc slots, upload files). Steps 6-7 use dev endpoints that bypass auth.
- **Source files**: The user must tell you where the source documents are (Excel files to upload).
- **Answer key models**: The user must tell you where the analyst answer key models are (xlsb/xlsm/xlsx files to compare against).
- **No API key needed** — comparison uses Claude Code subagents (free).

## Token Acquisition (only needed for Steps 3-5)

**Check for existing token first:**
```bash
if [ -f /tmp/.bval_token ]; then
  EXP=$(cat /tmp/.bval_token | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('exp',0))")
  NOW=$(date +%s)
  if [ "$EXP" -gt "$NOW" ]; then
    echo "Token valid until $(date -r $EXP)"
  else
    echo "Token expired"
  fi
else
  echo "No token found"
fi
```

**If expired or missing, extract from the running app using Chrome DevTools MCP:**

1. Ensure the app is open in Chrome and logged in at `http://localhost:4200`.

2. Get tab context:
   ```
   mcp__claude-in-chrome__tabs_context_mcp
   ```

3. Extract token via JavaScript:
   ```
   mcp__claude-in-chrome__javascript_tool
   ```
   Run this JS:
   ```javascript
   (async () => {
     const msalKeys = Object.keys(sessionStorage).filter(k => k.includes('accesstoken'));
     for (const key of msalKeys) {
       try {
         const entry = JSON.parse(sessionStorage.getItem(key));
         if (entry.secret) {
           console.log('__BVAL_TOKEN__:' + entry.secret);
           return;
         }
       } catch(e) {}
     }
     console.log('__BVAL_TOKEN__:NOT_FOUND');
   })();
   ```
   Then read console:
   ```
   mcp__claude-in-chrome__read_console_messages  (tabId, pattern: "__BVAL_TOKEN__")
   ```

4. Save and verify:
   ```bash
   echo '<extracted_token>' > /tmp/.bval_token
   curl -s -o /dev/null -w "%{http_code}" "$API/engagements" -H "Authorization: Bearer $(cat /tmp/.bval_token)"
   # Should return 200
   ```

**Token lifetime**: ~1 hour. Only needed for engagement creation and file upload.

## API Base URLs

| Endpoint Type | Base URL | Auth Required |
|---|---|---|
| **Authenticated endpoints** (create, upload, poll) | `http://localhost:5224/api` | Yes (JWT) |
| **Dev endpoints** (extract, download) | `http://localhost:5224/api/dev` | No |
| **Deployed (SWA)** | `https://thankful-river-0a013e10f.4.azurestaticapps.net/api` | Yes (JWT, no dev endpoints) |
| **Deployed (direct)** | `https://dev-bvalap-app-api.azurewebsites.net/api` | Yes (JWT, no dev endpoints) |

Set variables:
```bash
API="http://localhost:5224/api"
DEV_API="http://localhost:5224/api/dev"
TOKEN=$(cat /tmp/.bval_token)
```

## Step 1: Determine the correct valuationYear

**CRITICAL**: Never assume valuationYear from the current date. It shifts ALL period slots and causes data to land in wrong columns.

If re-testing an existing engagement, read its valuationYear:
```bash
curl -s "$API/engagements/{EXISTING_ENGAGEMENT_ID}" \
  -H "Authorization: Bearer $TOKEN" | jq '.valuationYear'
```

If creating a fresh test, ask the user what valuationYear to use. For USPI examples, the year placeholders in document types work as follows:
- VY=2025 creates doc slots for years 2022, 2023, 2024, and YTD
- VY=2026 creates doc slots for years 2023, 2024, 2025, and YTD

## Step 2: Get the file-to-documentType mapping

**CRITICAL**: Don't guess which file goes to which document slot by filename pattern-matching. Read the mapping from a reference engagement.

```bash
curl -s "$API/engagements/{REFERENCE_ENGAGEMENT_ID}" \
  -H "Authorization: Bearer $TOKEN" | jq '[.documents[] | select(.fileName != null) | {fileName, documentType, id}]'
```

If no reference engagement exists, map files manually. USPI document types (for VY=2025):
- `Income Statement YTD & Balance Sheet YTD`
- `Income Statements 2024 & Balance Sheet 2024`
- `Income Statements 2023 & Balance Sheet 2023`
- `Income Statements 2022 & Balance Sheet 2022`
- `Physician Utilization (Case Volumes) YTD` / `2024` / `2023` / `2022`
- `Charge and Collection Detail by Physician, Specialty, Payor YTD` / `2024` / `2023` / `2022`
- `Staff Wages`
- `Lease Schedule / Agreement`
- `Ownership Roster`
- `Distributions YTD` / `2024` / `2023` / `2022`
- `Budget`

These come from `server/BvalAutomationPortal.Api/Configuration/ClientDocuments/uspi.json`.

## Step 3: Create engagement (requires auth)

```bash
curl -s -X POST "$API/engagements" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "targetCompanyName": "<DESCRIPTIVE_NAME>",
    "orgId": "<ORG_ID>",
    "valuationYear": <YEAR>,
    "valuationDate": "<YYYY-MM-DD or null>",
    "createdDate": "<ISO8601_UTC_TIMESTAMP>"
  }' | jq '{id, targetCompanyName, valuationYear, valuationDate}'
```

**Required fields:**
- `targetCompanyName` (string, 1-200 chars)
- `orgId` (string) — known orgs: `"USPI"`, `"HCA"`, `"SCA"`. Also accepts `"org-uspi"`.
- `valuationYear` (int, 2020-2050)
- `createdDate` (ISO 8601 string) — **MUST be included** or the API returns 400

**Optional fields:**
- `valuationDate` (string, ISO date) — set for **stub-year engagements** where the fiscal year doesn't end Dec 31 (e.g., `"2025-06-30"` for a June 30 valuation). Controls YTD period end dates in the model. If omitted, defaults to Dec 31 of the valuationYear.

## Step 4: Get document slot IDs (requires auth)

```bash
curl -s "$API/engagements/{ENGAGEMENT_ID}" \
  -H "Authorization: Bearer $TOKEN" | jq '[.documents[] | {id, documentType, status}]'
```

Build a mapping: `documentType -> document id`.

## Step 5: Upload files (requires auth)

```bash
curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$API/engagements/{ENGAGEMENT_ID}/documents/{DOCUMENT_ID}/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/source/file.xlsx;type=application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
```

**Content type mapping:**
| Extension | Content-Type |
|---|---|
| `.xlsx` | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` |
| `.xls` | `application/vnd.ms-excel` |
| `.xlsb` | `application/vnd.ms-excel.sheet.binary.macroEnabled.12` |
| `.xlsm` | `application/vnd.ms-excel.sheet.macroEnabled.12` |
| `.pdf` | `application/pdf` |
| `.csv` | `text/csv` |

**Parallelization**: Upload files concurrently:
```bash
curl ... -F "file=@file1.xlsx" &
curl ... -F "file=@file2.xlsx" &
curl ... -F "file=@file3.xlsx" &
wait
```

## Step 6: Trigger extraction via dev endpoint (NO AUTH)

**Option A — Batch dev endpoint (recommended for local):**

Use the batch extraction endpoint to extract **all uploaded documents in parallel** with a single call. No auth required.

```bash
curl -s -X POST "$DEV_API/extract-all/{ENGAGEMENT_ID}?force=true" | \
  jq '{wallClockMs, totalCpuMs, succeeded, failed, documents: [.documents[] | {documentType, success, fieldsExtracted, elapsedMs}]}'
```

This is ~6x faster than extracting documents one at a time. The endpoint creates a separate DI scope per document for thread safety. Response includes wall-clock time and per-document timing.

**Option A2 — Single document extraction (for re-extracting one doc):**

```bash
curl -s -X POST "$DEV_API/extract/{ENGAGEMENT_ID}/{DOCUMENT_ID}?force=true" | \
  jq '{fieldsExtracted, fieldsNotFound}'
```

The dev extract endpoints are **synchronous** — they run extraction and return results directly. No polling needed.

**Option B — Auto-extraction with polling (for deployed environments):**

If targeting a deployed environment (no dev endpoints), upload triggers auto-extraction. Poll until complete:

```bash
while true; do
  RESP=$(curl -s "$API/engagements/{ENGAGEMENT_ID}" -H "Authorization: Bearer $TOKEN")
  PROCESSING=$(echo "$RESP" | jq '[.documents[] | select(.fileName != null and .status == "Processing")] | length')
  COMPLETED=$(echo "$RESP" | jq '[.documents[] | select(.fileName != null and .status == "Completed")] | length')
  FAILED=$(echo "$RESP" | jq '[.documents[] | select(.fileName != null and .status == "Failed")] | length')
  TOTAL=$(echo "$RESP" | jq '[.documents[] | select(.fileName != null)] | length')
  echo "Completed: $COMPLETED  Processing: $PROCESSING  Failed: $FAILED  Total: $TOTAL"
  if [ "$PROCESSING" -eq 0 ]; then break; fi
  sleep 15
done
```

## Step 7: Download models via dev endpoint (NO AUTH)

**Full model download (recommended for local, no auth needed):**

```bash
curl -s -o "/tmp/model_output.xlsm" -w "%{http_code}" \
  "$DEV_API/download-full-model/{ENGAGEMENT_ID}"
```

This downloads a single .xlsm with ALL tabs filled. Use this for comparison against answer keys.

**Full model download with auth (for deployed environments):**

```bash
curl -s -o "/tmp/model_output.xlsm" -w "%{http_code}" \
  "$API/engagements/{ENGAGEMENT_ID}/input-tabs/download-model" \
  -H "Authorization: Bearer $TOKEN"
```

## Step 8: MANDATORY — Open Model in Excel for Formula Recalculation

**CRITICAL: You MUST prompt the user to open the downloaded `.xlsm` file in Excel and save it (Cmd+S) before comparing.** The downloaded model contains formulas that haven't been recalculated — restated sections, reconciliation totals, projections, and balance checks will ALL show as zeros until Excel recalculates them.

**Do NOT skip this step. Do NOT proceed to comparison without user confirmation that the file has been opened and saved.**

Tell the user:
```
Please open the downloaded model in Excel and save it (Cmd+S) to recalculate formulas:
open "/tmp/model_output.xlsm"
```

Wait for the user to confirm before proceeding to Step 9.

## Step 9: Compare against answer keys using extraction-compare

Use the `/extraction-compare` approach — this is **free** (no API calls, uses Claude Code subagents):

1. **Dump both files to text** — run the Python script from the extraction-compare skill with `OUR_FILE` set to `/tmp/model_output.xlsm` and `ANSWER_FILE` set to the analyst answer key path.

2. **Launch parallel subagents** — one per tab (IS Input, BS Input, FFS Input, Payor Input, Detail, NRP Adj.). Each agent reads its tab pair from `/tmp/compare/ours/` and `/tmp/compare/answer/` and reports differences.

3. **Compile results** — group findings by tab, highlight impactful differences first.

### Cost
**$0** — all comparison runs within Claude Code subagents.

## Re-extraction workflow (existing engagement)

When you've changed extraction profiles or mappings and want to re-test without creating a new engagement:

```bash
ENGAGEMENT_ID="<existing-engagement-id>"

# 1. Batch re-extract all documents (no auth needed, ~6x faster than sequential)
curl -s -X POST "$DEV_API/extract-all/$ENGAGEMENT_ID?force=true" | \
  jq '{wallClockMs, succeeded, failed}'

# 2. Download the updated model (no auth needed via dev endpoint)
curl -s -o "/tmp/model_output.xlsm" "$DEV_API/download-full-model/$ENGAGEMENT_ID"

# 3. Open in Excel and save (Cmd+S) to recalculate formulas — MANDATORY before comparing
open "/tmp/model_output.xlsm"
# Wait for user to confirm before proceeding

# 4. Compare using /extraction-compare approach (free, subagent-based)
#    Dump both files to text, then launch parallel subagents per tab
```

This is the fastest iteration loop: change profile → re-extract → download → compare.

## Gotchas

| Mistake | What happens | Prevention |
|---|---|---|
| Wrong `valuationYear` | Period slots shift — columns misalign with answer keys | Always confirm VY from reference engagement or user |
| Missing `createdDate` in POST | API returns 400 | Always include `"createdDate": "2026-01-01T00:00:00Z"` |
| Download before extraction finishes | Empty cells in output model | Dev extract endpoint is synchronous — wait for it to return |
| Wrong file-to-docType mapping | Files in wrong slots → garbage extraction | Copy mapping from reference engagement via API |
| Token expired mid-run | 401 on auth'd endpoints | Token only needed for Steps 3-5. Steps 6-7 use dev endpoints (no auth). |
| Using wrong orgId | Wrong document slots created | Verify orgId matches the source data |
| Dev endpoints on deployed env | 404 — dev endpoints only exist in Development mode | Use auth'd endpoints + polling for deployed environments |
| Not opening model in Excel before comparing | Formulas show as zeros — restated sections, reconciliation, projections all empty | After downloading .xlsm, open in Excel, let formulas recalculate, Cmd+S, then compare |

## Codebase Reference

| What | Path |
|---|---|
| Dev endpoints (extract, download) | `server/BvalAutomationPortal.Api/Endpoints/DevAuthEndpoints.cs` |
| Engagement endpoints | `server/BvalAutomationPortal.Api/Endpoints/EngagementEndpoints.cs` |
| Input tab / download endpoints | `server/BvalAutomationPortal.Api/Endpoints/InputTabEndpoints.cs` |
| USPI document types config | `server/BvalAutomationPortal.Api/Configuration/ClientDocuments/uspi.json` |
| USPI extraction profiles | `server/BvalAutomationPortal.Api/Configuration/ExtractionProfiles/uspi/` |
| USPI input tab mappings | `server/BvalAutomationPortal.Api/Configuration/InputTabMappings/uspi/` |
| Excel model service | `server/BvalAutomationPortal.Api/Services/ExcelModelService.cs` |
