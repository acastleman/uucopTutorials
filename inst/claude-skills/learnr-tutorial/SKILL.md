---
name: learnr-tutorial
description: Scaffold, build, or extend a learnr tutorial for the RMD project. Use this skill whenever the user wants to create a new learnr tutorial, add a section to an existing one, write questions, design a primer page, build an immediate review section, or set up the tracking infrastructure (session logging, question events, section navigation, feedback form). Also use it when the user asks how a tutorial should be structured, what to put in a section, or how to wire up credentials.
allowed-tools: Read, Glob, Bash, Write, Edit
---

# Learnr Tutorial Builder

**Before doing anything else, read the `learning-science` skill** (`~/.claude/skills/learning-science/SKILL.md` or `.claude/skills/learning-science/SKILL.md` — use whichever exists). Every structural and content decision in this tutorial should be informed by those principles. Do not skip this step.

Then read the reference files in this skill's `references/` directory as needed:
- `references/technical-setup.md` — YAML header, chunk setup, credential injection, deploy wiring
- `references/tracking-infrastructure.md` — session logging, question events, section navigation, feedback form

---

## Tutorial Structure

Every tutorial follows this section order. The placement of the immediate review *before* the content sections is intentional — students consolidate the lecture while it's fresh, then work through the detailed content at their own pace.

```
1. Welcome & Study Plan       ← navigation, study plan, feedback form, question submission
2. Primer                     ← complete before lecture (replaces old Pre-Study)
   [student attends lecture]
3. Warm-Up                    ← tutorials 2+ only — spaced retrieval from prior tutorials
4. Immediate Review           ← complete same day as lecture
5. Content Section(s)         ← one or more, work through at own pace
6. Synthesis                  ← interleaved mixed practice across all content sections
7. Model Summary              ← generative consolidation
8. What's Next                ← spacing recommendation, preview of next tutorial
```

Primer, immediate review, and content sections are not optional. The warm-up is required for any tutorial after the first in a course sequence. Synthesis and model summary should be included unless the tutorial is very short.

### Section-level `data-progressive` attribute

Even though the YAML sets `progressive: true` globally, certain sections should have `data-progressive=FALSE` so students can navigate freely within them:

```markdown
## Welcome & Study Plan {data-progressive=FALSE}
## Primer {data-progressive=FALSE}
## Immediate Review {data-progressive=FALSE}
```

Content sections, synthesis, model summary, and what's next can use the default progressive behavior.

---

## Section 1: Welcome & Study Plan

Brief. The first thing students read — make the intended use of each section unmistakable. Include these elements in order:

### 1a. Three-step flow

> **How to use this tutorial:**
> 1. **Primer** — complete this *before* lecture (~15 min). It builds a framework for the material you're about to hear.
> 2. **Immediate Review** — complete this *the same day as lecture*, right after class (~10–15 min). It helps lock in what you just heard.
> 3. **[Content sections by name]** — work through these *at your own pace* after the immediate review (~30–45 min). This is where the full detail lives, along with worked examples and practice.

Adapt the content section names to the actual tutorial.

### 1a-bis. "How This Tutorial Works" (first tutorial of each course only)

For the **first** tutorial in a course sequence, add a brief explanation of why the tutorial is structured the way it is. Keep it short (4–6 bullet points) — the academic success course covers the learning science in depth; this is just enough context so students aren't confused by the design.

> **Why this tutorial is structured differently from a textbook:**
> - The **Primer** uses *prediction* — generating predictions, even wrong ones, primes your brain to encode the correct answer more deeply when you hear it in lecture.
> - The **Immediate Review** is timed for the same day as lecture because the first spacing interval is most effective while memory is fresh. Waiting until the weekend costs 60–70% of what you learned.
> - Questions are **deliberately mixed** across topics — interleaved practice feels harder but produces stronger long-term retention.
> - If a question feels hard to answer, that difficulty is a feature. Effortful retrieval strengthens memory more than easy retrieval.
> - Questions in this tutorial are **learning events**, not just assessments.

Do not include this in tutorials 2+ — students have already seen it.

### 1b. Study plan recommendation

Include a concrete schedule tied to the forgetting curve:

> **Recommended schedule:**
> 1. Primer: Before lecture (15 min)
> 2. Attend lecture
> 3. Immediate Review: Same day after lecture (10–15 min)
> 4. Content Sections: Within 2 days of lecture (30–45 min)
> 5. Quick review: 1 week after lecture — revisit the Immediate Review (5 min)
> 6. Exam prep: Use the Cumulative Review app

### 1c. Value proposition

Frame the tutorial as the primary study tool, not another resource on the pile:

> This tutorial contains the lecture content PLUS retrieval practice, worked examples, and self-assessment you can't get from the slides alone. If you only use one resource outside of lecture, this is the one to use.

### 1d. Feedback form

Include the feedback form UI (from `references/tracking-infrastructure.md`). Add framing:
- Feedback is used by an AI to make targeted improvements
- Most useful submissions are small and specific
- No limit on submissions; handled automatically

### 1e. Question submission to faculty

Add a separate text box for students to submit questions to the instructor. This removes barriers to help-seeking — students who are hesitant to ask in class or come to office hours can submit questions here.

```r
textAreaInput("student_question", "What question would you ask?",
  rows = 3,
  placeholder = "Ask anything about this topic — your question goes directly to the instructor"),
actionButton("submit_question", "Send Question",
  style = "background:#003366;color:white;border:none;padding:8px 20px;"),
uiOutput("question_status")
```

Wire this to blastula in the server chunk (same pattern as feedback form, different email subject line: "Student Question — [Tutorial Name]").

### 1f. Downloadable resources

If a downloadable primer PDF or concept map template exists, link them here:

```r
tags$p(
  tags$a(href = "media/primer.pdf", target = "_blank", "Download the Primer as PDF"),
  " | ",
  tags$a(href = "media/concept-map-template.pdf", target = "_blank", "Concept Map Template")
)
```

Place the PDF files in the tutorial's `www/` directory (served via `shiny::addResourcePath("media", "www")`).

---

## Section 2: Primer

**Purpose:** Build the mental model BEFORE lecture. This section replaces the old "Pre-Study" and does heavier conceptual lifting — it doesn't just activate prior knowledge, it constructs the scaffold that lecture content will fill in.

The primer is modeled on the PK "bathtub model" primer approach: introduce a sustained analogy, define every key parameter through both formal language AND the analogy, and show how parameters relate to each other.

### Structure

**Part A — Retrieve What You Know** *(retrieval-based, not declarative)*
- Do NOT say "You already know about X." Instead, ask students to PRODUCE the relevant knowledge.
- Use `question_text()` prompts: "Before we start, write down what 'like dissolves like' means and give one example."
- Include model answers in the feedback so students can self-check.
- For tutorials 2+ in a series, retrieve concepts from the prior tutorial: "In Part 1, you learned about [concept]. In your own words, what is [concept] and why does it matter?"

**Part B — The [Model Name]** *(sustained analogy + framework)*
- Introduce a concrete, named analogy and sustain it throughout the primer.
- Every key parameter/concept gets defined TWICE: formally AND through the analogy.
- Show how parameters relate to each other within the analogy.
- Make the framework visual or spatial in language — students should be able to "see" the structure.
- **Cross-tutorial coherence:** The analogy introduced here must extend naturally through subsequent tutorials in the series. Don't design a model that gets replaced later — design one that grows. (Example: the bathtub model for IV bolus extends to include an input faucet for oral absorption, and a staircase for multiple dosing.)

**Part C — Key Terms** *(formal definitions paired with analogy)*
- Present a table or structured list: Term | What It Represents | The [Analogy Name]
- This is the reference version students can return to.

**Part D — Diagnostic Self-Check** *(prerequisite verification)*
- 1–2 questions that test prerequisite knowledge (not new content).
- "Can you calculate a percent w/v concentration? Try this one before moving on."
- If the student struggles, provide a specific recommendation: "If this was difficult, review [Tutorial X / Resource Y] before continuing."
- Use `conditionalPanel()` or `renderUI()` to show remediation recommendations based on performance if technically feasible.

**Part E — Predictions** *(generative learning)*
- 2–3 prediction questions grounded in the model just built.
- Use `question_text()` with `answer(NULL, correct = TRUE)` and `allow_retry = FALSE`.
- Frame as genuine engagement: "Based on the [model name], predict what happens when..."
- These predictions will be revisited in the Immediate Review.

### Implementation notes
- Target length: 10–15 minute read + questions
- Tone: conversational, not textbook — as if a knowledgeable friend is explaining the framework
- The analogy should draw on things pharmacy students reliably know
- Avoid frontloading clinical detail — save that for content sections
- Generate a downloadable PDF version of the primer content (Parts B and C primarily) and place it in `www/primer.pdf`

---

## Section 3: Warm-Up (tutorials 2+ only)

**Purpose:** Spaced retrieval of concepts from prior tutorials + activation of prior knowledge for the current tutorial. In cumulative courses (e.g., PK), the warm-up serves double duty as both spaced retrieval AND primer activation.

### Design
- 3–5 retrieval questions drawn from previous tutorials in the sequence
- Questions should bridge to the current tutorial's content: "In the IV bolus model, what does k represent? How do you think this concept will apply when the drug is given orally?"
- Mix of MCQ and `question_text()`
- Include model answers and explanatory feedback

### Cross-tutorial remediation
If a student performs poorly (e.g., 0/3 or 1/5), display a recommendation:

```r
# In server context, after warm-up questions are answered:
output$warmup_recommendation <- renderUI({
  if (warmup_score < threshold) {
    tags$div(class = "warning-callout",
      tags$p("Your warm-up results suggest you may want to review ",
        tags$a(href = "https://uucop.shinyapps.io/PreviousTutorial", "Tutorial X"),
        " before continuing.")
    )
  }
})
```

This requires tracking warm-up question performance in server context. If the full implementation is too complex for the initial build, at minimum include the warm-up questions and add remediation links in the feedback text of each question.

---

## Section 4: Immediate Review

**Purpose:** First spaced repetition hit, completed the same day as lecture while memory is fresh. Consolidates the primer mental model and the core detail from lecture. Not exam prep — consolidation.

**Students should complete this immediately after lecture, before working through the content sections.** The welcome page makes this flow explicit.

### Design principles

- **Short** — 10–15 minutes maximum. Students should do this right after lecture, not defer it.
- **Recall-heavy** — lead with free-response questions that require students to produce answers in their own words. `question_text()` is the primary format here.
- **Mixed format** — follow free-response with MCQ and other formats to interleave. Don't block all MCQ together.
- **Interleaved topics** — don't march through topics sequentially. Mix concepts from different parts of lecture.
- **Varying difficulty** — start with moderate retrieval (core model), include some harder integration questions, include one or two easier anchors for confidence.
- **Close the loop on primer predictions** — include at least one question that asks students to revisit their primer predictions: "Before lecture, you wrote a prediction about X. How did that match what you learned?"
- **Close with a model check** — final question asks students to connect what they learned back to the named mental model from the Primer.
- **Feedback is explanatory** — every question needs feedback that explains why, connects back to the mental model, and addresses the most common misconception for that item.

### Format guidance

| Format | When to use |
|--------|------------|
| `question_text()` | Lead with these — recall, own words, mechanism explanation |
| MCQ (radio) | Concept discrimination, clinical application |
| MCQ (checkbox) | "Select all that apply" — good for mechanism steps |
| Ordering questions | Drug class comparisons, mechanism sequences |

Target: 6–10 questions total. More than 10 starts to feel like exam prep; fewer than 6 may not be enough consolidation.

---

## Section 5: Content Sections

**Purpose:** Full lecture content with active elaboration layered on top. Students work through this at their own pace after completing the immediate review — potentially over multiple sessions.

### Critical design principle: KEEP the lecture content, TRANSFORM the experience

Content sections retain the lecture material (students should not need to go back to slides as a separate resource). But the tutorial adds layers that lectures cannot provide:

- **Retrieval checkpoints** every 200–300 words of content — even a single `question_text()` asking "In your own words, what is the key idea from what you just read?"
- **Worked example fading** — full → faded → independent (see below)
- **Self-explanation prompts** after worked examples
- **Concept map connections** — "How does this fit into the [model name]?"
- **Instructor Insight callouts** — explanations from lecture transcripts/recordings not on slides
- **Clinical Connection vignettes** — real clinical stories that illustrate the concept
- **Teach-back prompts** — "Explain [concept] to a classmate who hasn't taken this course"

### Content-to-retrieval ratio

The overall tutorial and each individual content section should target roughly **equal weight between content delivery and active retrieval**. A content section that is 80% prose and 20% questions is too passive — students will read without engaging. Aim for:

- **Per content section:** at least 1 retrieval element (question, self-explanation prompt, retrieval checkpoint, or model-check) per ~200–300 words of prose. A section with 500 words of prose should have at least 2–3 retrieval elements interspersed, not clustered at the end.
- **Overall tutorial:** retrieval-dominant sections (Primer, Immediate Review, Synthesis, Model Summary) should collectively account for at least **40–50%** of the tutorial by student time. Content sections make up the remainder, but even content sections should be ~50% retrieval by student experience (prose is read quickly; questions take longer per line).
- **Minimum per section:** no content section should have fewer than 3 retrieval elements (questions + prompts + model-checks). If a section is short enough that 3 questions would overwhelm the content, the section may be too thin to stand alone — consider merging it with an adjacent section.

When reviewing a draft tutorial, count questions per content section. If any section falls below 1 question per 250 words of prose, add retrieval checkpoints, self-explanation prompts, or model-check questions until it reaches that density.

### Worked example fading pattern

For each concept that involves a procedure or calculation:

0. **"Stop and think" prompt** — present the problem *before* the worked example and ask the student to attempt it or predict the approach. Even failed attempts improve learning from the subsequent example (the generation effect). Use `question_text()`: "Before looking at the solution, try this problem yourself — or at least write down which approach you'd use."
1. **Full worked example** — complete solution with all steps labeled
2. **Faded example** — present a similar problem with some steps completed, student fills in the missing steps via `question_text()` or MCQ
3. **Independent practice** — student solves the entire problem, then a reveal shows the full solution

### Self-explanation prompts

After a worked example, ask: "Why did step 3 use multiplication rather than division?" or "What would change if the dose were doubled?" Place these as `question_text()` with model answers.

### Error detection exercises (use selectively)

Present a worked solution that contains a deliberate error. Ask students to find and explain the error. Especially effective for procedural knowledge (calculations, compounding steps). Use a distinctive callout style:

```html
<div class="warning-callout">
<strong>Find the error:</strong> The following solution contains one mistake.
Identify the error and explain why it's wrong.
</div>
```

### Confidence calibration (per section)

Place the confidence rating **after the content exposition but before the first question** in each content section. This ordering is deliberate: if placed after the questions, students base their rating on the retrieval they just practiced rather than their genuine pre-assessment. Pre-question confidence is a better metacognitive calibration exercise.

```r
radioButtons("confidence_sectionN",
  "Before answering the questions below: how confident are you that you could answer exam questions about [section topic]?",
  choices = c("1 — Not at all" = "1", "2 — Slightly" = "2", "3 — Moderately" = "3",
              "4 — Very" = "4", "5 — Completely" = "5"),
  selected = character(0), inline = TRUE)
```

Log the confidence rating alongside question events. After the section's questions, students can compare their confidence to their actual performance — the mismatch is itself a learning event.

### Self-assessment after key question_text() items

Follow important free-text responses with a trackable MCQ:

```r
question("How did your answer compare to the model answer?",
  answer("I got the key idea right", correct = TRUE),
  answer("I was partially right but missed a key element"),
  answer("I had a misconception"),
  answer("I didn't know where to start"),
  allow_retry = FALSE
)
```

This provides a trackable signal AND trains metacognitive calibration.

### Instructor Insight callouts

When lecture transcripts or faculty interviews provide explanations not on slides, present them as:

```html
<div class="instructor-insight">
<strong>Dr. [Name]'s explanation:</strong> "[Verbatim or close-to-verbatim
quote from lecture recording or faculty interview]"
</div>
```

### Clinical Connection vignettes

```html
<div class="clinical-connection">
<strong>From the clinic:</strong> [Brief patient scenario or clinical story
that illustrates the concept]

Based on this scenario, [retrieval question about the concept]
</div>
```

### Model check questions

After introducing a new concept or at the end of a subsection, ask students to connect the new material back to the named mental model. Use the `.model-check` CSS class:

```html
<div class="model-check">
<strong>Model check:</strong> How does [new concept] fit into the [model name]?
Which part of the [analogy] corresponds to this?
</div>
```

Follow with a `question_text()` or MCQ that requires the student to articulate the connection. These questions force integration of new information into the existing framework rather than storing it as an isolated fact.

### Textbook reference callouts

When textbook content supports or extends the tutorial material, use these three patterns rather than building tutorial content from textbook prose:

```html
<div class="section-callout">
<strong>For Reference:</strong> [Formal definition, complete table, or
derivation from the textbook]
</div>
```

```html
<div class="section-callout">
<strong>Going Deeper (optional):</strong> [Expanded content for students
who want more depth — clearly marked as optional]
</div>
```

For active engagement with textbook language, present the formal version and ask students to restate:

> **The textbook says:** "[Formal textbook quote]"

Then add a `question_text()`: "Restate this in your own words — what does it actually mean in practice?"

### Discussion prompts (for potential flipped classroom use)

Where natural, include prompts that work for both solo reflection and paired discussion:

```html
<div class="prestudy-prompt">
<strong>Think about it:</strong> Before submitting your answer, consider:
would a classmate agree with your reasoning? Why or why not?
</div>
```

These prompts support flipped classroom exercises if faculty allocate class time for tutorial work, but also function as self-reflection for solo students.

### Dual coding prompts

At key points where a visual representation would aid understanding, ask students to generate their own diagram:

> **Sketch it:** On paper, draw a diagram showing [concept relationship]. Then describe what you drew below.

Use `question_text()` to capture the description. The act of generating a visual representation is itself a learning event, even though we can't evaluate the drawing directly.

### Table formatting standard

All tables use `kableExtra::kbl()` — never `knitr::kable()` directly. Standard styling:

```r
kableExtra::kbl(df, col.names = c(...), align = c("l", "l", ...)) |>
  kableExtra::kable_styling(
    bootstrap_options = c("striped", "hover", "bordered"),
    full_width = FALSE   # TRUE only for wide multi-column tables
  ) |>
  kableExtra::column_spec(1, bold = TRUE, width = "Xem") |>
  kableExtra::column_spec(2, width = "Yem")
```

- `bootstrap_options` must always include `"striped"`, `"hover"`, and `"bordered"` — all three
- `full_width = FALSE` for most tables; `full_width = TRUE` for tables with 4+ columns that need full width
- Always bold the first column (`column_spec(1, bold = TRUE)`) when it is a label/term column
- Set explicit `width` on each column to prevent browser-driven column stretching
- The chunk must include `library(kableExtra)` in the setup chunk — it is already loaded in the standard tutorial template

### MCQ answer length balance

**Answer length bias is a persistent problem.** When the correct answer is noticeably longer or more detailed than the distractors, students learn to select the longest option rather than discriminating between choices. This makes the question useless as a retrieval event.

**Rules:**
- All answer options for a given question should be within 30–40% of each other in character length.
- Explanatory text belongs in the `correct`/`incorrect` feedback, NOT in the answer text itself. If you find yourself writing "Correct answer — because it does X and Y," strip "because it does X and Y" out of the answer and put it in feedback.
- If the correct answer is naturally longer than distractors, either trim the correct answer or expand the distractors to similar length by making them more specific and plausible. A distractor should represent a genuine misconception stated precisely, not a one-word label.
- After writing any MCQ, do a quick length check: compute the character count of each option. Flag and revise any question where the correct answer is more than 1.5× the length of the longest distractor.

**Common failure pattern:** the correct answer is written as a complete explanatory sentence ("X happens because Y, which leads to Z") while distractors are short noun phrases ("Oxidation", "Incorrect pH"). Fix: either compress the correct answer to the same register as the distractors, or expand the distractors to include a brief mechanism that could plausibly be mistaken for the correct one.

### Question format within sections

Target ratio: 40% `question_text()` (free recall), 40% MCQ (discrimination), 20% other (ranking, calculation, error detection).

Each content section covers one coherent chunk of the topic. Design principles:
- Lead with the concept's role in the mental model, then add detail
- Use worked examples before independent questions (fading pattern)
- Embed retrieval questions throughout — don't save all questions for the end
- Sequence from simpler to complex within the section
- Write question feedback that explains *why*, connects back to the model, and addresses likely wrong answers explicitly

---

## Section 6: Synthesis

**Purpose:** Interleaved mixed practice across all content sections. This section tests discrimination between concepts and produces stronger long-term retention than blocked practice.

### Design
- 8–12 questions mixing topics from all content sections
- Interleave question formats (MCQ, free text, ordering)
- Questions should require students to discriminate between similar concepts
- Include at least 2–3 questions that require integrating ideas from multiple sections

### Student-generated MCQ exercise

Near the end of the synthesis section, ask students to write their own exam question using a structured input format:

```r
fluidRow(
  column(10,
    tags$h4("Write a Practice Question"),
    tags$p("Write an MCQ about this tutorial's content. This exercise helps you
            identify key concepts and think about common mistakes."),
    textAreaInput("student_q_stem", "Question:", rows = 3,
      placeholder = "Write your question stem here..."),
    textInput("student_q_a", "Option A:"),
    textInput("student_q_b", "Option B:"),
    textInput("student_q_c", "Option C:"),
    textInput("student_q_d", "Option D:"),
    selectInput("student_q_correct", "Correct answer:",
      choices = c("Select..." = "", "A", "B", "C", "D")),
    textAreaInput("student_q_explanation", "Why is this the correct answer?", rows = 3),
    actionButton("submit_student_q", "Submit Question",
      style = "background:#003366;color:white;border:none;padding:8px 20px;"),
    uiOutput("student_q_status")
  )
)
```

Wire submission to blastula (email to faculty) or log to a Google Sheet. The formatting constraint of individual text inputs prevents free-form formatting issues.

---

## Section 7: Model Summary

**Purpose:** Generative consolidation — students produce a summary of the complete mental model.

### Design
- One `question_text()` prompt: "Describe the complete [model name] as you understand it now, including everything from today's tutorial. Use the analogy from the Primer to organize your answer."
- If using a downloadable concept map template, add a prompt: "Update your concept map with the new connections from this tutorial. What nodes did you add? What connections are new?"
- This is the most effortful generative task in the tutorial — place it after synthesis so students have just retrieved across all topics.

---

## Section 8: What's Next

**Purpose:** Preview the next tutorial, provide spacing recommendations, and link to review tools.

### Content
- 2–3 sentences previewing the next tutorial's topic and how it extends the current model
- Retention forecast: "You learned [N] new concepts today. Research shows a 5-minute review in 2–3 days keeps retention above 80%. Without review, you'll retain about 40% in one week."
- Specific recommendation: "Revisit the Immediate Review section in 3 days for a quick retrieval boost."
- Link to cumulative review app when available
- If this is the last tutorial before an exam, note that and link to the per-exam review app

---

## Unlearning Exercises (use selectively, not standard)

For topics where analytics or faculty experience identify persistent misconceptions, deploy an explicit unlearning sequence. This is NOT a standard section — use only when a specific misconception is known to be common and resistant to correction.

1. Present the misconception directly and ask students if they hold it
2. Show why it's wrong with a concrete counterexample
3. Present the correct understanding
4. Test whether the misconception persists with a follow-up question

Example topic: "Vd is the actual physical volume the drug distributes into" (it's not — it's an apparent volume).

---

## Question Labeling Convention

Label all questions with a structured tag for analytics and the cumulative review question bank:

```
q_[concept]_[bloom]_[section_block_number]
```

- `concept`: short identifier (e.g., `vd`, `clearance`, `firstorder`, `syrup`, `hlb`)
- `bloom`: `rem` (remember), `und` (understand), `app` (apply), `ana` (analyze)
- `number`: **section-block numbering** — each section starts at a round hundred, and questions are numbered sequentially within that block

### Section block assignments

| Block | Section |
|-------|---------|
| 100s  | Warm-Up |
| 200s  | Primer |
| 300s  | Immediate Review |
| 400s  | Content Section 1 |
| 500s  | Content Section 2 |
| 600s  | Content Section 3 |
| ...   | (continue for additional content sections) |
| 900s  | Synthesis |
| 1000s | Model Summary |

Assign content sections sequentially starting at 400. If a tutorial has more than 5 content sections, the Synthesis block shifts to the next available hundred after the last content section.

Examples: `q_vd_app_401`, `q_firstorder_und_301`, `q_syrup_rem_802`

**Why block numbering:** Inserting a new question into a section only requires picking the next available number within that block — no renumbering of other sections required. A Primer question added between `q_rule9_rem_202` and `q_saturation_rem_203` becomes `q_newconcept_und_210`.

This enables:
- Question-level analytics (which concepts are students struggling with?)
- Cumulative review apps (pull questions by concept, Bloom's level, or empirical difficulty)
- Cross-tutorial spaced retrieval (warm-up questions reference prior tutorial question tags)
- Section identification from the label alone (e.g., 300s = Immediate Review)

---

## Answer Text Capture

The event recorder must capture the student's actual response text for `question_text()` questions. Add an `answer_text` column to the `question_events` sheet:

In the event recorder (see `references/tracking-infrastructure.md`), add to the `data.frame()`:

```r
answer_text = if (!is.null(data$answer)) as.character(data$answer) else NA_character_,
```

This enables:
- LLM-assisted grading of free-text responses
- Faculty review of student understanding
- Identification of common misconceptions from student language
- Better-targeted remediation recommendations

**Important:** Update `setup_tracking_sheets()` in deploy.R to include `answer_text` in the `question_events` tab headers.

---

## CSS Classes

Add these to the `<style>` block (extending the existing `.section-callout` and `.prestudy-prompt`):

```css
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
```

---

## Tutorial Naming and Course Sequencing

Within a course, tutorial **directories** get a zero-padded numeric prefix to enforce ordering. The prefix is omitted from the Rmd filename and the deployed shinyapps.io app name — those stay clean and human-readable.

```
PBDA1/
  03_antidiabetics_part1/
    antidiabetics_part1_tutorial.Rmd   ← no prefix in filename
  04_antidiabetics_part2/
    antidiabetics_part2_tutorial.Rmd
```

shinyapps.io app names follow the existing convention without the prefix:
```
PHM726-AntidiabeticsPart1
PHM726-AntidiabeticsPart2
```

The prefix numbers reflect sequence within the course. Ask the user what number a new tutorial should get if it isn't obvious from context.

**When writing a later tutorial in a series**, treat earlier tutorials as prior knowledge the student has. The warm-up section retrieves key concepts from earlier tutorials. The primer explicitly activates and extends: "In Part 1, you built a model of X — this tutorial extends that model to Y."

---

## Adding a New Tutorial — Setup Checklist

When scaffolding a new tutorial from scratch, work through these in order:

**Before starting:** pull the course repo to make sure you have the latest:
```bash
git -C <course-repo-root> pull --ff-only
```

1. **Create directory** — `NN_tutorial-name/` (zero-padded number prefix for ordering)
2. **Copy YAML header and setup chunks** from `references/technical-setup.md`
3. **Add to `TUTORIAL_CONFIG`** in `deploy.R` (name + file path)
4. **Wire tracking infrastructure** — session logging, question events (with `answer_text` column), section navigation — from `references/tracking-infrastructure.md`
5. **Create Google Sheet** — rename Sheet1 tab to `sessions`, share with service account, run `setup_tracking_sheets()`
6. **Set `GS4_SHEET_ID`** in project's `.Renviron` (gitignored)
7. **Wire feedback form** — from `references/tracking-infrastructure.md`
8. **Wire question submission** — separate textAreaInput + actionButton for student questions to faculty
9. **Create `.rscignore`** in the tutorial directory:
   ```
   feedback/
   feedback_config.md
   feedback_log.csv
   ```
10. **Create feedback infrastructure:**
    - Create `feedback/inbox/` and `feedback/processed/` directories
    - Create `feedback_log.csv` with headers: `date_processed,tutorial,section,category,feedback_summary,decision,change_description,git_commit`
    - Create `feedback_config.md` from this template:
      ```
      | Tutorial identifier | `CourseCode-TutorialName` |
      | Rmd path            | `ProjectDir/tutorial-dir/tutorial.Rmd` |
      | Course              | Course name |
      | Student level       | P1/P2/etc. |
      | Feedback inbox      | `ProjectDir/tutorial-dir/feedback/inbox/` |
      | Feedback log        | `ProjectDir/tutorial-dir/feedback_log.csv` |
      | Git repo root       | `ProjectDir/` |
      ```
    - **Register in uucop-hub** — open `uucop-hub/feedback/collect_feedback.py` and add an entry to `TUTORIAL_MAP`:
      ```python
      "Course Name Tutorial Name": RMD_ROOT / "courses" / "COURSE_DIR" / "tutorial-dir" / "feedback",
      ```
      The key must match (case-insensitive) the tutorial name in the feedback email subject — i.e., everything between `[EXTERNAL] - ` and ` Feedback —`.
    - Also add the inbox path to the inbox directory list in `uucop-hub/feedback/run_process_feedback.bat` (the long `--message` string passed to Claude).
    - Use the `git-sync` skill to commit and push both the course repo and uucop-hub changes. Commit course repo first, then uucop-hub.
11. **Draft primer** — sustained analogy, parameter table, diagnostic self-check, predictions
12. **Draft warm-up** (if tutorial 2+ in series) — spaced retrieval from prior tutorials
13. **Draft content sections** — lecture content + active elaboration layers
14. **Draft immediate review** — interleaved, recall-heavy, closes prediction loop
15. **Draft synthesis** — interleaved mixed practice + student-generated MCQ exercise
16. **Draft model summary** — generative consolidation prompt
17. **Draft what's next** — preview, retention forecast, spacing recommendation
18. **Create downloadable primer PDF** — place in `www/primer.pdf`
19. **Label all questions** with `q_concept_bloom_number` convention
20. **Commit and push** the completed tutorial — use the `git-sync` skill.

---

## Reference files

Read these when you need implementation details — don't load them unless relevant to the current task:

- `references/technical-setup.md` — YAML, setup chunks, package loading, CSS, question formats
- `references/tracking-infrastructure.md` — Full implementation of session logging, question event recorder, section navigation tracking, and feedback form (with code)
