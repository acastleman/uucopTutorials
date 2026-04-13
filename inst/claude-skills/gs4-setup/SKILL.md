---
name: gs4-setup
description: Guide and execute the complete setup of a new Google Sheet for tutorial tracking in the RMD project, including wiring it to the Analytics Dashboard. Use this skill whenever a new course or tutorial needs a tracking sheet created, when a sheet needs to be wired to the analytics dashboard, or when the user asks how to get Google Sheets logging working for a new tutorial. Also use it when the user asks what steps are needed to get a new course visible in the dashboard.
allowed-tools: Read, Edit, Bash, Glob
---

# New Google Sheet Setup

## Prerequisites

This skill requires a Google service account JSON at `.secrets/gs4-service-account.json` (repo root). This file is provided by Dr. Castleman during onboarding — do not proceed without it. The `client_email` inside it is what you share with each new Google Sheet.

---

This workflow has two parts: browser steps that only the user can perform, and code steps that Claude executes once the sheet ID is in hand.

---

## Step 1 — Identify the project

Before doing anything, ask which project/course this sheet is for. You need to know:
- Which course `deploy.R` to update (e.g., `PBDA1/deploy.R`, `Pharmaceutics Non-Sterile Lab/Labs/deploy.R`)
- What key/label to use in the Analytics Dashboard (e.g., `NSCLABS`, `"PHRM 764 Non-Sterile Lab"`)

If this is obvious from context, proceed without asking.

---

## Step 2 — Browser instructions (user action required)

Tell the user to complete these three steps in the browser, then come back with the sheet ID:

---

**In Google Sheets:**

1. Create a new blank spreadsheet and name it (e.g., "PHRM 764 Non-Sterile Lab Tracking")
2. Right-click the default "Sheet1" tab → **Rename** → type `sessions` (exact spelling, lowercase)
3. Copy the sheet ID from the URL — it's the long alphanumeric string between `/d/` and `/edit`:
   ```
   https://docs.google.com/spreadsheets/d/THIS_PART_HERE/edit
   ```

**Share with the service account:**

4. Find the service account email: open `.secrets/gs4-service-account.json` at the RMD root and copy the value of `"client_email"` (ends in `.iam.gserviceaccount.com`)
5. In Google Sheets, click **Share** → paste that email → set role to **Editor** → uncheck "Notify people" → **Share**

> If the sheet isn't shared with the service account before first use, all writes will fail silently.

**Then:** paste the sheet ID here and I'll handle the rest.

---

## Step 3 — Code execution (Claude does this)

Once the user provides the sheet ID, briefly confirm what you're about to do (one line is enough), then execute all of the following without further prompting:

### 3a. Update SHEET_ID in the course deploy.R

Read the relevant `deploy.R`, find the `SHEET_ID <-` line, and update it to the new sheet ID.

```r
SHEET_ID <- "<new-sheet-id>"
```

### 3b. Run setup_tracking_sheets()

Source the deploy.R and run `setup_tracking_sheets()`. This creates the `question_events` and `section_events` tabs — the `sessions` tab already exists and will be skipped.

```bash
Rscript -e 'source("<path-to-deploy.R>"); setup_tracking_sheets()'
```

Expected output:
```
  SKIP — tab already exists: sessions
  Created tab: question_events
  Created tab: section_events
Sheet setup complete: <sheet-id>
```

**Important:** `setup_tracking_sheets()` is defined in `PBDA1/deploy.R` but may not be present in other project deploy.R files. Check before running — if it's missing, copy the function from `PBDA1/deploy.R` into the target deploy.R first.

### 3c. Wire into Analytics Dashboard

**`Analytics-Dashboard/deploy.R`** — add to `SHEET_IDS`:

```r
SHEET_IDS <- c(
  PBDA1   = "1gBxPivtr4rzOjsQGzAL_gkSW4ufggEVp_ZcI05lI3eE",
  NEWKEY  = "<new-sheet-id>"   # use a short uppercase key, e.g. NSCLABS, PHM704
)
```

The key (e.g., `NSCLABS`) becomes the env var `GS4_SHEET_NSCLABS`, injected into `.Renviron` at deploy time.

**`Analytics-Dashboard/app.R`** — add to the `SHEETS` list:

```r
newkey = list(
  id    = Sys.getenv("GS4_SHEET_NEWKEY", ""),
  label = "Course Display Name"   # shown in dashboard dropdowns
)
```

Check whether a commented-out stub already exists for this course — if so, uncomment and fill it in rather than adding a new block. When adding a new entry, ensure there is a trailing comma after the preceding entry's closing `)` — missing commas in `list()` are a common R syntax error.

### 3d. Redeploy the Analytics Dashboard

```bash
cd "Analytics-Dashboard" && Rscript -e 'source("deploy.R"); deploy()'
```

> Run from inside the `Analytics-Dashboard/` directory, not the RMD root. The `APP_DIR` path resolution in `deploy.R` uses `getwd()` as a fallback and will miscalculate `SECRETS_DIR` if run from a parent directory.

---

## After completion

Confirm to the user:
- Which tabs were created in the sheet
- That the dashboard has been redeployed and the new course will appear in all tabs
- Any issues encountered (e.g., missing function, permissions error)
