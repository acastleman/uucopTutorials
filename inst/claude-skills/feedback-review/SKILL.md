---
name: feedback-review
description: "Process unread student feedback for learnr tutorials. Use whenever the user asks to process feedback, or when invoked automatically by the scheduled feedback cron. Reads feedback/inbox/ files, evaluates each item, edits the tutorial Rmd, logs decisions to feedback_log.csv, moves files to feedback/processed/, generates a daily report, and commits. Trigger on: 'process feedback', 'review student feedback', 'any new feedback?', or when running as a scheduled task."
user-invocable: true
allowed-tools: Read, Glob, Bash, Edit, Write
---

# Feedback Review

Processes unread student feedback for one or more learnr tutorials. Can be invoked manually or run automatically by the scheduled cron.

**Before evaluating any feedback, read the `learning-science` skill and the `learnr-tutorial` skill.** Decisions about whether feedback warrants a change — and what that change should look like — must be grounded in the pedagogical principles in those skills. A suggestion that seems reasonable on its face may conflict with intentional design decisions (e.g., interleaving that feels confusing, desirable difficulty that students misread as an error, distractor quality that is by design).

---

## Step 1 — Find pending feedback

Scan all known tutorial directories for files in `feedback/inbox/`:

```
PBDA1/antidiabetics_part1/feedback/inbox/
PBDA1/antidiabetics_part2/feedback/inbox/
```

Add new tutorials to this list as they are created. If the user specifies a particular tutorial, scope to that one only.

If no `.txt` files exist in any `inbox/`, report "No pending feedback" and stop.

---

## Step 2 — Read tutorial context

For each tutorial with pending feedback, read:
1. The tutorial's `feedback_config.md` (in the tutorial directory) — contains course level, Rmd path, tutorial identifier
2. The tutorial Rmd file (path from config)
3. `feedback_log.csv` — to understand what has been processed before, and to detect duplicates

---

## Step 3 — Duplicate check

Before evaluating a feedback file, compare it against existing entries in `feedback_log.csv`. A duplicate is a submission that describes the same concern in the same section that has already been logged.

If a duplicate is found: move the file to `feedback/processed/` and skip it — do not add another log entry.

---

## Step 4 — Evaluate each feedback item

For each non-duplicate file in `feedback/inbox/`, evaluate:

**Is the concern valid?**
- Factually correct?
- Appropriate for the course level specified in `feedback_config.md`?
- Could a change introduce errors or unintended scope creep?
- Does the concern conflict with an intentional pedagogical design decision from the learning-science or learnr-tutorial skills? If so, that is grounds for rejection with a clear explanation.

**Assign a decision:**
- `Accepted` — make the change as described
- `Partial` — make a related but more limited change; explain the deviation
- `Rejected` — do not change; briefly explain why (out of scope, factually incorrect premise, intentional design, etc.)

**Constraints:**
- Keep changes minimal and targeted — do not refactor surrounding content
- Do not change content outside the referenced section unless strictly necessary
- Do not add new sections or expand scope
- Flag any feedback raising a privacy concern rather than acting on it
- Do NOT read inside `.secrets/` or `archive/`

---

## Step 5 — Implement accepted changes

Edit the tutorial Rmd directly for all `Accepted` and `Partial` decisions. Make only the change described — no opportunistic improvements to nearby content.

---

## Step 6 — Log every item

Append one row per feedback file to `feedback_log.csv` in the tutorial directory:

| Column | Value |
|--------|-------|
| `date_processed` | today's date, YYYY-MM-DD |
| `tutorial` | tutorial identifier from `feedback_config.md` |
| `section` | section from the feedback file |
| `category` | one of: Factual error, Level mismatch, Conceptual gap, Clarity issue, Question design, Positive, Other |
| `feedback_summary` | 1–2 sentence anonymized description of the concern |
| `decision` | Accepted, Partial, or Rejected |
| `change_description` | what was changed, or why rejected; 1–3 sentences |
| `git_commit` | leave blank — filled after commit |

---

## Step 7 — Move processed files

Move each processed `.txt` file from `feedback/inbox/` to `feedback/processed/`. Create `processed/` if it does not exist.

---

## Step 8 — Generate daily report

Write a summary report to `feedback_reports/YYYY-MM-DD.md` in the RMD root. Create the `feedback_reports/` directory if it does not exist.

Report format:

```markdown
# Feedback Processing Report — YYYY-MM-DD

## Summary
- X items processed across N tutorial(s)
- X Accepted, X Partial, X Rejected, X duplicates skipped

## Changes Made

### PHM726-AntidiabeticsPart1
| Section | Category | Decision | Change |
|---------|----------|----------|--------|
| ...     | ...      | Accepted | ...    |

## Rejected Items

### PHM726-AntidiabeticsPart1
| Section | Category | Reason |
|---------|----------|--------|
| ...     | ...      | ...    |

## No pending feedback
_(if applicable)_
```

If no feedback was processed, write a one-line report: `No pending feedback on YYYY-MM-DD.`

---

## Step 9 — Commit

After all tutorials are processed and the report is written, create a git commit from the PBDA1 repo root:

```
Tutorial revision: N feedback items processed (YYYY-MM-DD)
```

Then fill the `git_commit` column in each `feedback_log.csv` with the resulting short hash.

If changes span multiple git repos, commit each repo separately. The daily report does not need to be committed (it lives outside the git repo).

---

## Category definitions

| Category | Meaning |
|----------|---------|
| Factual error | Content is scientifically or clinically incorrect |
| Level mismatch | Too detailed or not detailed enough for the course level |
| Conceptual gap | Prerequisite concept missing or assumed without scaffolding |
| Clarity issue | Accurate but poorly worded, ambiguous, or hard to follow |
| Question design | Distractor quality, stem ambiguity, answer key error |
| Positive | Reinforcement; no change needed |
| Other | Does not fit above categories |
