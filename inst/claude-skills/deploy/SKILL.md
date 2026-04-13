---
name: deploy
description: Deploy a Shiny app or learnr tutorial to shinyapps.io for the RMD project. Use this skill whenever the user wants to deploy, redeploy, or push an app or tutorial to shinyapps.io — even if they just say "push it" or "send it to shinyapps" or "deploy the labs". Also use it when setting up deployment for a new project or when troubleshooting a deployment failure.
disable-model-invocation: false
allowed-tools: Bash, Read, Glob
---

# Deploy to shinyapps.io

## Prerequisites

Before deploying for the first time, you need three things — all provided by Dr. Castleman during onboarding:

1. **`.secrets/gs4-service-account.json`** at your repo root — the Google service account key for Sheets logging
2. **SMTP credentials** (`SMTP_USER` / `SMTP_PASS`) — the Gmail App Password for sending student feedback emails
3. **shinyapps.io account access** — your login for the `uucop` account on shinyapps.io (or your own account if deploying under a different org)

If any of these are missing, `inject_gs4_credentials()` will fail silently and deployed apps will not log sessions. Get these before continuing.

---

All apps deploy to the `uucop` account on `shinyapps.io`. There are two deployment patterns in use — identify which one applies, then follow the steps for that pattern.

---

## Step 1: Identify the deployment pattern

Look at the project directory. The key question is: does a `deploy.R` exist, and what rsconnect function does it use?

| Signal | Pattern |
|--------|---------|
| `deploy.R` with `deployDoc()` and `TUTORIAL_CONFIG` | **Learnr tutorial** (PBDA1-style) |
| `deploy.R` with `deployApp()` and `LAB_CONFIG` | **Shiny app suite** (NSC Labs-style) |
| No `deploy.R` — just an `app.R` or `.Rmd` | **Direct deploy** (standalone app, no credential injection needed) |

### Learnr tutorial pattern (e.g., PBDA1/)
- `deploy.R` at the project root
- `TUTORIAL_CONFIG` maps short keys (e.g., `"part1"`) to shinyapps.io `name` and local `file` path
- Uses `deployDoc()` on an `.Rmd` file
- `inject_gs4_credentials()` must run before every deploy — it copies the service account JSON and writes `GS4_SHEET_ID` + SMTP creds into each tutorial's `.Renviron`
- SMTP credentials are included because these tutorials have a student feedback form

### Shiny app suite pattern (e.g., NSC Labs/)
- `deploy.R` lives in the `Labs/` subfolder (not the repo root)
- `LAB_CONFIG` maps lab numbers to shinyapps.io `name` and local `dir`
- Uses `deployApp()` on a directory
- `inject_gs4_credentials()` must run before every deploy — copies service account JSON and writes `GS4_SHEET_ID` only (no SMTP, since labs email via blastula using their own `.Renviron`)
- Each lab has its own SMTP creds already in its `.Renviron` (not managed by deploy.R)

### Which pattern to use for a new project?
- **learnr tutorial** (`.Rmd`, interactive educational content with questions, session logging, feedback form) → PBDA1 pattern
- **Standard Shiny app** (data entry, visualization, no learnr) → NSC Labs pattern if it's a suite of related apps; direct deploy if it's a single standalone app

---

## Step 2: Ask which app/tutorial to deploy

Ask the user interactively — don't guess. For example:
- For learnr projects: "Which tutorial? (e.g., `part1`, `part2`, or all)"
- For lab suites: "Which labs? (e.g., `1`, `1:3`, or all)"

---

## Step 3: Deploy

### Learnr tutorial
```r
source("PBDA1/deploy.R")   # adjust path as needed
deploy_tutorial("part1")   # or deploy_tutorial() for all
```

`deploy_tutorial()` automatically calls `inject_gs4_credentials()` first. You don't need to call it separately.

### Shiny app suite
```r
source("Pharmaceutics Non-Sterile Lab/Labs/deploy.R")
deploy_labs(1)    # single lab
deploy_labs(1:7)  # range
deploy_labs(c(1, 3, 5))  # specific labs
```

`deploy_labs()` automatically calls `inject_gs4_credentials()` first.

### Direct deploy (no deploy.R)
```r
rsconnect::deployApp(
  appDir   = "path/to/app",
  appName  = "AppName",
  account  = "uucop",
  server   = "shinyapps.io",
  forceUpdate = TRUE,
  launch.browser = FALSE
)
```

---

## Step 4: After deploy

Remind the user of things they may need to do separately:
- **Set app to private** on shinyapps.io if it requires authentication (student-facing apps should be private before inviting students)
- **Invite students** — this is a separate step; see the `invite` skill or run `invite_students()` manually

---

## Troubleshooting common issues

- **"Service account JSON not found"** — `.secrets/gs4-service-account.json` is missing at the repo root. It lives outside the git repo and must be present locally before deploying.
- **"Unknown tutorial: ..."** — the key passed to `deploy_tutorial()` doesn't match a key in `TUTORIAL_CONFIG`. Read `deploy.R` to see valid keys.
- **rsconnect auth error** — run `rsconnect::setAccountInfo()` or reconnect the account in RStudio's Publishing settings.
- **App deploys but crashes** — check the shinyapps.io logs. Common causes: missing package, `.Renviron` not written (credentials not injected), path mismatch.
