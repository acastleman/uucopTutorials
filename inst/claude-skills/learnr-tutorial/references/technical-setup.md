# Technical Setup Reference — Learnr Tutorials

Reference implementation: `PBDA1/antidiabetics_part1/antidiabetics_part1_tutorial.Rmd`

---

## YAML Header

```yaml
---
title: "Your Tutorial Title"
output:
  learnr::tutorial:
    progressive: true
    allow_skip: true
    theme: "flatly"
runtime: shiny_prerendered
description: >
  Brief description of the tutorial content and course context.
---
```

- `progressive: true` — sections reveal one at a time
- `allow_skip: true` — students can skip to any section
- `theme: "flatly"` — Bootstrap Flatly theme, consistent across all tutorials

---

## Setup Chunk

```r
```{r setup, include=FALSE}
library(learnr)
library(sortable)     # for drag-and-drop ordering questions
library(kableExtra)   # for styled tables
library(blastula)     # for feedback email
library(googlesheets4)

knitr::opts_chunk$set(echo = FALSE)
tutorial_options(exercise.timelimit = 60)
```
```

---

## Credentials and Deploy Wiring

### deploy.R — adding a new tutorial

In `TUTORIAL_CONFIG` in the project's `deploy.R`:

```r
TUTORIAL_CONFIG <- list(
  part1 = list(
    name = "AppNameOnShinyapps",         # shinyapps.io app name
    file = "tutorial-folder/tutorial.Rmd"  # path relative to REPO_ROOT
  ),
  part2 = list(...)
)
```

`inject_gs4_credentials()` in `deploy_tutorial()` will:
1. Copy `.secrets/gs4-service-account.json` → `tutorial-folder/secrets/gs4-service-account.json`
2. Write `GS4_SHEET_ID`, `SMTP_USER`, `SMTP_PASS` into `tutorial-folder/.Renviron`

### .Renviron (written by inject_gs4_credentials, gitignored)

```
GS4_SHEET_ID=<sheet-id>
SMTP_USER=uucop.shinyapps@gmail.com
SMTP_PASS=<app-password>
```

### One-time sheet setup (per new tutorial)

```r
source("PBDA1/deploy.R")  # or appropriate deploy.R
setup_tracking_sheets()   # creates sessions, question_events, section_events tabs
```

Before running: create the Google Sheet, rename `Sheet1` tab to `sessions`, share the sheet with the service account `client_email` as Editor.

---

## Question Formats

### Multiple choice (radio)
```r
question("Question text?",
  answer("Wrong option"),
  answer("Wrong option"),
  answer("Correct option", correct = TRUE),
  allow_retry = TRUE,
  incorrect = "Explanation of why wrong and what's right.",
  correct = "Explanation of why this is correct."
)
```

### Multiple select (checkbox)
```r
question("Which of the following...? (select all that apply)",
  answer("Option A", correct = TRUE),
  answer("Option B"),
  answer("Option C", correct = TRUE),
  type = "learnr_checkbox",
  allow_retry = TRUE
)
```

### Free text / recall
```r
question_text(
  "In your own words, explain...",
  answer(NULL, correct = TRUE),
  allow_retry = TRUE,
  correct = "Sample answer: [model answer here]. Key points to include: ...",
  incorrect = "The correct answer: [model answer here]. Common mistakes: confusing X with Y, or omitting Z. Compare your response to the model answer above.",
  placeholder = "Type your answer here..."
)
```

**Note on free-text grading:** `answer(NULL, correct = TRUE)` accepts any input as correct, so learnr always shows the `correct` feedback. In practice, use `incorrect` for the substantive feedback and treat `correct` as confirmatory — because students clicking "Try Again" after self-assessing wrong will see `incorrect`. The reliable path is to put the model answer and common mistakes in **both** `correct` and `incorrect` so every student sees it regardless of which branch learnr takes.

Practically: since exact-match grading flags nearly every response as incorrect, the `incorrect` feedback does most of the work. Always include:
1. The correct answer stated explicitly (so students can compare)
2. The most common errors by name ("A common mistake is to say X — this confuses the mechanism because...")

### Ordering (sortable)
```r
question_rank(
  "Arrange these steps in order:",
  answer(c("Step 1", "Step 2", "Step 3"), correct = TRUE),
  allow_retry = TRUE
)
```

### Feedback text conventions
- `incorrect` — state the correct answer explicitly, name the most common mistakes, connect to the mental model
- `correct` — confirm why right, reinforce the mechanism
- For MCQ: "If you chose [X], you may be thinking of... Notice that..." — each distractor should map to a realistic misconception
- For free text: put the model answer and common mistakes in both `correct` and `incorrect` — students see whichever branch learnr takes, and both should be equally informative
- **MCQ distractor quality:** distractors must be plausible (common misconceptions or related-but-wrong reasoning), similar in length and detail to the correct answer, and each one should represent a specific error a student could genuinely make

---

## Unicode Characters in Markdown Body

**Always use actual Unicode characters in markdown prose — never `\uXXXX` escape sequences.**

`\uXXXX` escapes only work inside R string literals (quoted strings within code chunks). In markdown body text, pandoc does not interpret them — it strips the `\u` prefix and renders the raw hex digits, producing garbled output like `192` instead of `→`.

| Use this | Not this | Character |
|----------|----------|-----------|
| `→` | `\u2192` | rightward arrow |
| `↓` | `\u2193` | downward arrow |
| `↑` | `\u2191` | upward arrow |
| `—` | `\u2014` | em dash |
| `–` | `\u2013` | en dash |
| `β` | `\u03b2` | beta |
| `α` | `\u03b1` | alpha |
| `γ` | `\u03b3` | gamma |
| `²` | `\u00b2` | superscript 2 |
| `⁺` | `\u207a` | superscript plus |
| `×` | `\u00d7` | multiplication sign |
| `≥` | `\u2265` | greater than or equal |

Inside R code chunks (e.g., in `paste()`, `sprintf()`, feedback strings), `\uXXXX` escapes work correctly and should stay as-is. The rule applies only to text written directly in the markdown body.

---

## CSS / Styling

Add inside a ```` ```{r, results='asis'} ```` chunk or as raw HTML:

```html
<style>
.section-callout {
  background: #f0f4f8;
  border-left: 4px solid #003366;
  padding: 12px 16px;
  margin: 16px 0;
  border-radius: 4px;
}
.prestudy-prompt {
  background: #fff8e1;
  border-left: 4px solid #f59e0b;
  padding: 12px 16px;
  margin: 16px 0;
  border-radius: 4px;
}
.instructor-insight {
  background: #e8f4f8;
  border-left: 4px solid #0077b6;
  padding: 12px 16px;
  margin: 16px 0;
  border-radius: 4px;
  font-style: italic;
}
.clinical-connection {
  background: #f0f8f0;
  border-left: 4px solid #2d6a4f;
  padding: 12px 16px;
  margin: 16px 0;
  border-radius: 4px;
}
.warning-callout {
  background: #fff3cd;
  border-left: 4px solid #e65c00;
  padding: 12px 16px;
  margin: 16px 0;
  border-radius: 4px;
}
.model-check {
  background: #f3e8ff;
  border-left: 4px solid #7c3aed;
  padding: 12px 16px;
  margin: 16px 0;
  border-radius: 4px;
}
</style>
```

| Class | Use for |
|-------|---------|
| `.section-callout` | Key concept callouts, textbook reference boxes, "Going Deeper" optional content |
| `.prestudy-prompt` | Prediction/question prompts in the Primer section, discussion prompts, "Think about it" prompts |
| `.instructor-insight` | Verbatim or near-verbatim quotes from lecture recordings or faculty interviews |
| `.clinical-connection` | Patient scenarios or clinical stories that illustrate a concept, followed by a retrieval question |
| `.warning-callout` | Error detection exercises ("Find the error"), important caveats, remediation recommendations |
| `.model-check` | Questions that ask students to connect new content back to the named mental model |
