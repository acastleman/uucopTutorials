---
name: tutorial-cleanup
description: Post-creation QA pass for any UUCOP learnr tutorial. Auto-fixes mechanical issues (random_answer_order, allow_retry, blank lines before lists, markdown→kable table conversion, MCQ answer length balance, prediction answer suppression, version upgrade, missing confidence checkpoints). Flags for human review: missing model answers, question count/density below threshold, prediction follow-up gaps, numbering issues. Invoke as /tutorial-cleanup or when the user says "clean up the tutorial", "run cleanup", or "QA the tutorial".
allowed-tools: Read, Edit, Write, Glob, Bash, PowerShell
---

# Tutorial Cleanup

Post-creation QA pass. Applies mechanical fixes silently, then runs structural checks and
flags anything that requires content judgment. Ends with a commit and a printed report.

**Authority for MCQ quality:** the `mcq-writing` skill is the canonical reference for what
makes a good multiple-choice question (stem rules, distractor plausibility, parallel
options, logical cues, etc.). The mechanical fixes below (Phase A: `random_answer_order`;
Phase B: answer-length ratio) automate two narrow checks from that broader rule set; if a
deeper revision is warranted, consult `mcq-writing` rather than expanding the rules here.

---

## Step 0 — Resolve the target tutorial

Extract from the invocation text. If the user named a tutorial ("clean up the leukemia
tutorial"), find its Rmd with Glob. If only one tutorial was recently edited in context,
use that. If still ambiguous, ask: "Which tutorial should I clean up? Please name the
course and topic."

Read the Rmd path from `feedback_config.md` in the tutorial directory if it exists.

---

## Step 1 — Read the tutorial Rmd

Read the full file. As you read, build a mental map of:

- **Sections** — each `## Heading` marks a section boundary; identify which are
  Primer / Warm-Up / Immediate Review / content sections (400+) / Synthesis /
  Model Summary / What's Next
- **Question blocks** — each ` ```{r q_...} ` chunk containing `question(` or
  `question_text(`; note chunk name, section, line number, and type
- **Markdown tables** — any `| col | col |` / `|---|` patterns that appear in the
  narrative body (outside R code chunks)
- **YAML version comment** — line 2 of the file: `# UUCOP Tutorial Version: X.X`

---

## Step 2 — Version check and upgrade

Read `uucop-hub/tutorial_versions.md`. Note the **Current Target Version** and run the
feature checklist against the tutorial:

```
[ ] Has learnr question chunks                               → v0.1
[ ] Has Google Sheets session + question + section logging   → v1.0
[ ] Uses uucopTutorials package functions                    → v1.1
[ ] Confidence selections logged to question_events sheet    → v2.0
[ ] Custom fixed crimson header + pill-button confidence UI  → v3.0
[ ] Reveal Model Answer button + auto-expand textarea        → v3.1
```

If the tutorial is below the current target, apply the upgrade path steps from the
**Upgrade Paths** section of `tutorial_versions.md` for the specific version gap. Then
update the YAML version comment on line 2 to match the new version.

If the tutorial is already at the current target, move on.

---

## Phase A — Mechanical Auto-Fixes

Apply all of the following. No confirmation needed; all will be bundled into the final commit.

### A1: `random_answer_order = TRUE`

For every `question(` block (not `question_text(`):
1. Check if `random_answer_order = TRUE` is present anywhere within the block
2. If absent, insert it as a named argument after the last `answer(...)` line and before the
   `allow_retry` / `correct=` / `incorrect=` / closing `)`:

   ```r
   answer("D — fourth option"),
   random_answer_order = TRUE,    ← insert here
   allow_retry = TRUE,
   correct = "...",
   incorrect = "..."
   )
   ```

### A2: `allow_retry`

For every `question(` and `question_text(` call, check if `allow_retry` is present:
- If `allow_retry = FALSE` is present → do not touch it
- If `allow_retry` is absent:
  - `question()` → add `allow_retry = TRUE`
  - `question_text()` → check whether this is a **prediction question** (see below)
    - Prediction: add `allow_retry = FALSE`
    - Otherwise: add `allow_retry = TRUE`

**Identifying prediction questions:** A `question_text()` is a prediction question if it
is inside the Primer section (between `## Primer` and the next `## ` heading) AND the
question stem contains any of: `predict`, `before lecture`, `before you watch`,
`what do you think will happen`, `hypothesize`.

### A3: Blank lines before bulleted and numbered lists

Scan the Rmd line by line, **skipping content inside R code chunks** (between ` ```{r` and
closing ` ``` `). For each line matching `^[- *+] ` or `^\d+\. ` (a list item):
- If the immediately preceding non-empty line is also a list item or blank → no action
- If the preceding line is a non-empty paragraph line → insert a blank line before this
  list item

Use Edit for each insertion, or batch with a Python script run via Bash for efficiency
when there are more than 5 insertions.

**Exceptions:** Do not insert blank lines inside HTML `<div>` blocks or inside YAML front matter.

### A4: Markdown table → kable conversion

Find every markdown table in the Rmd **narrative body** (not inside R code chunks). A
markdown table is a contiguous block of lines where:
- Line 1 matches `^\|` (header row)
- Line 2 is a separator row matching `^\|[-: |]+\|$`
- Lines 3+ are data rows matching `^\|`

For each markdown table found, run a Python script via Bash to:
1. Parse the header row → column names
2. Parse the alignment row → alignment characters (`l`, `r`, `c`)
3. Parse all data rows → list of lists
4. Generate an R code chunk replacement

The replacement chunk format:

```r
```{r, echo=FALSE}
df <- data.frame(
  col1 = c("val1a", "val2a"),
  col2 = c("val1b", "val2b"),
  stringsAsFactors = FALSE
)
kableExtra::kbl(df,
  col.names = c("Column 1", "Column 2"),
  align = c("l", "l")) |>
  kableExtra::kable_styling(
    bootstrap_options = c("striped", "hover", "bordered"),
    full_width = FALSE      # TRUE for tables with 4+ columns
  ) |>
  kableExtra::column_spec(1, bold = TRUE)
```
```

Set `full_width = TRUE` for tables with 4 or more columns. Set `bold = TRUE` only on
column 1 when it is a label/term column (i.e., all values in column 1 are unique and
appear to be keys/terms).

The crimson header color (`#8C1B2A`) is already applied by the tutorial's CSS — no extra
kableExtra call is needed for that.

Replace the original markdown table block with the generated chunk using Edit.

---

## Phase B — MCQ Answer Length Analysis and Fix

### B1: Compute ratios

Run the following Python script via Bash (substituting the actual Rmd path):

```python
import re, sys
path = r"RMDPATH"
with open(path, encoding='utf-8') as f:
    lines = f.readlines()

current_chunk = None
current_answers = []
results = []
line_nums = {}

for i, line in enumerate(lines, 1):
    m = re.match(r'```\{r\s+(\w+)', line)
    if m:
        if current_chunk and len(current_answers) >= 2 and any(c for _,c,_ in current_answers):
            results.append((current_chunk, line_nums[current_chunk], list(current_answers)))
        current_chunk = m.group(1)
        line_nums[current_chunk] = i
        current_answers = []
        continue
    if line.strip() == '```' and current_chunk:
        if len(current_answers) >= 2 and any(c for _,c,_ in current_answers):
            results.append((current_chunk, line_nums[current_chunk], list(current_answers)))
        current_chunk = None; current_answers = []; continue
    m = re.match(r'\s*answer\("([^"]+)",?\s*(correct\s*=\s*TRUE)?', line)
    if m and current_chunk:
        current_answers.append((len(m.group(1)), bool(m.group(2)), m.group(1)))

violations = []
for chunk, lineno, answers in results:
    correct = [(l,t) for l,c,t in answers if c]
    distractors = [(l,t) for l,c,t in answers if not c]
    if not correct or not distractors: continue
    correct_len = correct[0][0]
    max_dist = max(distractors, key=lambda x: x[0])
    ratio = correct_len / max_dist[0] if max_dist[0] > 0 else 0
    if ratio > 1.15:
        violations.append((chunk, lineno, ratio, correct[0][1], max_dist[1]))

if violations:
    for chunk, lineno, ratio, ctxt, dtxt in violations:
        print(f"VIOLATION line {lineno}: {chunk} ratio={ratio:.2f}")
        print(f"  CORRECT ({len(ctxt)}): {ctxt}")
        print(f"  LONGEST DIST ({len(dtxt)}): {dtxt}")
else:
    print("All ratios <= 1.15 — no violations found.")
```

### B2: Fix each violation

For each question reported with ratio > 1.15, apply a fix strategy. The target is ratio ≤ 1.15.

**Strategy 1 — Trim the correct answer by moving clauses to `correct=` feedback:**
Look for the correct answer ending with:
- A semicolon-separated trailing clause: `"X is correct; it also does Y"` → trim `; it also does Y`, append to `correct=`
- A parenthetical: `"X (because Y)"` → trim `(because Y)`
- A phrase starting with "because", "which", "—", "meaning", "since", "this is"

Move the trimmed clause to the end of the existing `correct=` argument text. If `correct=` is absent, create it.

**Strategy 2 — Expand short distractors:**
If the correct answer cannot be trimmed without losing the discriminating information,
expand the shortest distractors by adding a specific (but wrong) mechanism or clinical
detail. Distractors must remain clinically plausible misconceptions.

**Strategy 3 — Hybrid:**
Trim correct slightly AND expand one distractor slightly.

After all fixes are applied, **re-run the Python analysis** from B1 to confirm 0 violations
before proceeding.

---

## Phase C — Structural Checks

### C1: `question_text()` model answers

For every `question_text(` call:
1. Locate the `correct =` argument. Flag if:
   - Argument is absent, OR
   - Value is `""`, `NULL`, or contains only whitespace
2. Locate the `incorrect =` argument. Flag the same way.
3. **Exception:** Prediction questions (Primer section + `allow_retry = FALSE`) use a
   redirect message — check that the text contains "revisit" or "section" or similar.
   If it contains a full model answer instead, redirect to **C6**.

Report flagged questions with chunk name, line number, and question stem (first 80 chars).

### C2: Section Questions area and confidence check placement

In each **content section** (sections starting at block 400 or later, up to but not
including Synthesis):

**Check 1 — Section Questions area:** Verify there is a bold label `**Section Questions**`
(or a `### Section Questions` heading) at or near the end of the section, with question
blocks clustered after it.

If the section has questions interspersed throughout the prose (retrieval checkpoints)
**and** a closing Section Questions block → ✓ correct design, no action.

If the section has questions interspersed but NO closing Section Questions block →
flag: "Section [name] has no closing Section Questions area. Consider adding one."

If ALL questions in the section appear in the first 50% of the section lines with none
after → flag: "Section [name] has all questions front-loaded with no closing reinforcement."

**Check 2 — Confidence check placement:** Verify a `radioButtons("confidence_` call
appears in the section **before the first question block**.

If absent, auto-insert a confidence checkpoint immediately before the first `question(` or
`question_text(` in that section:

```r
```{r, echo=FALSE}
radioButtons("confidence_SECTIONSLUG",
  "Before answering the questions below: how confident are you that you could answer exam questions about SECTIONTOPIC?",
  choices = c("1 — Not at all" = "1", "2 — Slightly" = "2", "3 — Moderately" = "3",
              "4 — Very" = "4", "5 — Completely" = "5"),
  selected = character(0), inline = TRUE)
```
```

Replace `SECTIONSLUG` with a short lowercase version of the section heading (e.g.,
`aml_treatment` for "AML Treatment") and `SECTIONTOPIC` with the section heading text.
Add a note in the cleanup report to verify the topic text is natural.

### C3: Question count and density

Count question blocks (individual `question(` or `question_text(` calls) per section.
Also estimate prose word count per section (count words in narrative lines, excluding R
chunk bodies).

| Section | Minimum questions | Notes |
|---------|-------------------|-------|
| Primer | 2 | |
| Immediate Review | 6 | Target 6–10; flag if < 6 or > 10 |
| Each content section | 3 | Plus ≥ 1 per 250 words of prose |
| Synthesis | 8 | Target 8–12 |
| Model Summary | 1 | |

Report sections below minimum with exact question count and estimated word count.
Do NOT auto-generate questions — report only.

### C4: Prediction follow-up coverage

In the Primer section, find all prediction `question_text()` calls (identified by
`allow_retry = FALSE` and stem containing prediction language).

For each prediction, extract the core topic from the question stem.

Scan the Immediate Review section for evidence of follow-up:
- Question stems containing "revisit your prediction", "before lecture you predicted",
  or "compare your answer"
- OR questions clearly covering the same concept as the prediction

Report which predictions have follow-up and which do not. For predictions with no IR
follow-up, flag with the prediction's stem (first 100 chars) and suggest adding a
"revisit your prediction" question to the Immediate Review.

Do NOT auto-generate content — report only.

### C5: Prediction answer suppression

In the Primer section, for every `question_text()` with `allow_retry = FALSE`:
1. Read the `correct =` argument text
2. If the text is longer than ~80 characters AND does not contain "revisit", "section",
   "compare", or "you'll learn" → this prediction is showing a model answer instead of
   redirecting the student

Auto-fix: Replace both `correct =` and `incorrect =` text with:

```
correct = "Your prediction has been recorded. We'll revisit this question in the SECTIONNAME section — compare your answer then.",
incorrect = "Your prediction has been recorded. We'll revisit this question in the SECTIONNAME section — compare your answer then."
```

Infer `SECTIONNAME` from the content section most relevant to the prediction topic
(infer from the question stem). Add a note in the cleanup report to verify the section name.

### C6: Question numbering continuity

Check all question chunk names (` ```{r q_*`) against the block numbering scheme:

| Block | Section |
|-------|---------|
| 100s  | Warm-Up |
| 200s  | Primer |
| 300s  | Immediate Review |
| 400s  | Content Section 1 |
| 500s  | Content Section 2 |
| 600s  | Content Section 3 |
| 700s  | Content Section 4 |
| 800s  | Content Section 5 |
| 900s  | Synthesis |
| 1000s | Model Summary |

If the tutorial has more than 5 content sections, Synthesis and Model Summary shift to the
next available block (e.g., 1000s for Synthesis, 1100s for Model Summary).

Flag:
- **Duplicates** — two or more chunks with the same number
- **Block mismatch** — a question in the wrong section for its number (e.g., a 400s chunk
  appearing inside the Immediate Review section)
- **Large gaps** — sequential gap > 5 within a block, suggesting deleted questions

Do not auto-renumber — report only with chunk names and line numbers.

---

## Final Step — Commit and report

After all phases are complete, create a git commit from the tutorial's repo root:

```
Tutorial cleanup: [Tutorial Name] — [date]
```

Then print a **Cleanup Report** to the console (do not write it to a file unless the user asks):

```
## Tutorial Cleanup Report — [Tutorial Name] — YYYY-MM-DD

### Auto-fixes applied
- Version upgrade: vX.X → vX.X  (or "already at current version")
- random_answer_order: N question() blocks updated
- allow_retry: N blocks updated (X question, Y question_text)
- Blank lines before lists: N insertions
- Markdown tables → kable: N tables converted
- MCQ length balance: N questions rebalanced (was > 1.15 ratio)
- Confidence checkpoints inserted: N sections (verify topic text)
- Prediction answer suppression: N prediction questions updated (verify section names)

### Flags for human review
#### Missing model answers (question_text)
- [chunk name] line [N]: "[first 80 chars of stem]" — missing [correct= / incorrect= / both]
...

#### Question count below threshold
- [Section name]: [N] questions, ~[W] prose words (minimum [M])
...

#### Prediction follow-up gaps (IR)
- Primer question [chunk]: "[stem excerpt]" — no clear IR follow-up found
...

#### Question numbering issues
- [chunk name] line [N]: [description of issue]
...

#### Section Questions area / structure
- [Section name]: [description of issue]
...

(If a category has no issues, print "None." for that category.)
```
