---
name: learning-science
description: Principles of the science of learning that should guide the design of all educational content, tutorials, and assessments in this project. Load this skill automatically whenever creating, editing, or evaluating learnr tutorials, Shiny educational apps, quiz questions, or any instructional content. Use it to evaluate whether a proposed design decision is pedagogically sound.
user-invocable: false
---

# Science of Learning — Instructional Design Principles

These principles should actively shape every decision when building tutorials — not as a checklist to complete after the fact, but as a lens applied throughout design.

---

## 1. Mental Model Construction

Students don't absorb isolated facts — they build structured representations of how things work. New information lands better when there's a framework to attach it to. When designing content, ask: *what is the mental model this student should leave with, and am I building toward it deliberately?*

- Lead with the big picture before the details
- Make the framework explicit — **name it**, draw it out in words or a diagram, return to it
- Details should feel like they're filling in a structure the student already has, not arriving out of nowhere
- Analogies are among the most powerful tools for building new schemas — a good analogy lets students borrow structure from something they already understand
- **Cross-tutorial coherence:** Mental models must be designed to grow across a tutorial series. The analogy introduced in Tutorial 1 should extend naturally in Tutorials 2, 3, etc. — not get replaced. (Example: the bathtub model for IV bolus extends to include an input faucet for oral absorption, a staircase for multiple dosing, a second tub for two-compartment models.)
- **Progressive concept maps:** Use concept maps that build across sections and across tutorials. The preferred implementation is Option B (interactive, retrieval-based): before revealing new connections on the map, ask students to predict which concepts connect and how.

## 2. Prior Knowledge Activation

Students learn new material by connecting it to what they already know. Failing to activate relevant prior knowledge means new content arrives without a scaffold to attach to, increasing cognitive load and reducing retention.

- Before introducing new content, **require students to produce** the relevant knowledge — don't just tell them they know it
- Use `question_text()` retrieval prompts: "Write down what 'like dissolves like' means" is activation; "You already know about polarity" is a reminder (not activation)
- Don't assume prior knowledge is activated just because students completed a prerequisite course; prompt retrieval of it
- **Within a tutorial series:** tutorial directories use a zero-padded numeric prefix (e.g., `03_antidiabetics_part1/`) so the expected order is unambiguous in the file system. Later tutorials should explicitly activate content from earlier ones via the Warm-Up section — spaced retrieval questions from prior tutorials that also serve as activation for the current one.
- **Cross-tutorial remediation:** When warm-up or diagnostic questions reveal that a student lacks prerequisite knowledge, recommend specific tutorials or resources. This is especially important for first-year students with gaps from prerequisite courses and for upper-division students who need to revisit earlier material (e.g., pharmacology for pharmacotherapy).

## 3. Cognitive Load Theory

Working memory is limited. Effective instruction manages three types of load:

| Type | What it is | Design implication |
|------|-----------|-------------------|
| **Intrinsic** | Complexity inherent to the content | Chunk material; sequence from simpler to complex; teach component skills before integrating |
| **Extraneous** | Complexity from poor presentation | Eliminate unnecessary decoration; keep examples tightly relevant; don't split attention across formats |
| **Germane** | Effort directed toward schema formation | This is the goal — create it by requiring students to actively process, not passively receive |

When a student seems to be struggling, ask whether the difficulty is intrinsic (the content is genuinely complex) or extraneous (the presentation is adding unnecessary friction). Reduce extraneous load aggressively; don't try to reduce intrinsic load by oversimplifying — use scaffolding instead.

**Worked examples with fading:** Before asking students to solve independently, show a fully worked example. Then present a similar problem with some steps completed (faded example). Then present an independent problem. This three-stage progression (full → faded → independent) reduces load for novices while building toward competence. As students gain proficiency, fade the scaffolding further.

**Self-explanation prompts:** After worked examples, ask "Why did step 3 use multiplication rather than division?" or "What would change if the dose were doubled?" These prompts increase learning from examples by 2–3x compared to just reading them (Chi et al., 1989).

## 4. Retrieval Practice

Retrieving information from memory is itself a powerful learning event — often more effective than re-reading or re-watching. The act of retrieval, especially when effortful, strengthens the memory trace.

- **Recall > recognition** — asking students to produce an answer is more effective than asking them to select one. Free response, fill-in, and own-words explanations outperform multiple choice for consolidation (though MCQ has its place for broad coverage and for trackable analytics).
- **Target ratio:** 40% `question_text()` (free recall), 40% MCQ (discrimination), 20% other (ranking, calculation, error detection)
- **Retrieval checkpoint density:** Insert a retrieval question every 200–300 words of content. Long text blocks without questions = passive reading.
- Retrieval should require genuine effort — if the answer is immediately obvious, the retrieval event isn't doing much
- Feedback after retrieval is critical — students need to know what they got right and why, and what they got wrong and why
- **Teach-back prompts** are among the most powerful retrieval exercises: "Explain [concept] to a classmate who hasn't taken this course." These force the student to organize and restructure their knowledge.

**MCQ quality:** When multiple choice is used, the quality of distractors determines the quality of the retrieval event. Distractors should be plausible — common misconceptions, related but incorrect mechanisms, or defensible-but-wrong reasoning that a student could arrive at. Random or obviously absurd choices reduce the task to eliminating nonsense rather than discriminating between similar concepts.

Specific pitfalls to avoid:
- **Answer length bias** — the correct answer should not be systematically longer or more detailed than the distractors. Students learn to exploit this pattern. Balance lengths across all choices, or deliberately make a distractor the longest option.
- **Implausible distractors** — if you can't articulate why a student would genuinely choose a distractor, replace it. Each wrong answer should represent a specific, realistic error or misconception.
- Avoid "all of the above" and "none of the above" — they short-circuit discrimination between choices.

## 5. Spaced Repetition

Memory decays without retrieval, but each retrieval resets and strengthens the trace. Spacing reviews over time — rather than cramming — produces dramatically better long-term retention.

The tutorial system implements spacing at multiple levels:

| Level | Mechanism | When |
|-------|-----------|------|
| **Within-tutorial** | Immediate review → content sections → synthesis | Same day through next 2 days |
| **Cross-tutorial** | Warm-up sections retrieve prior tutorial concepts | Each new tutorial |
| **Cumulative review apps** | Per-exam, per-course, or cross-course MCQ + calculations | Ongoing |
| **Email retrieval** | Blastula sends a retrieval question 3 days after completion | Automated |

- The **immediate review** is the first spaced repetition hit. It is not comprehensive review or exam prep — it is consolidation.
- **Warm-up sections** (tutorials 2+) provide the second hit, bridging to the new material.
- **Cumulative review apps** provide ongoing spacing with expanding intervals.
- Don't try to cover everything in the immediate review — cover the core model and highest-yield details.
- Keep the immediate review short enough that students actually do it right after lecture rather than deferring.

## 6. Interleaving

Blocking practice (all questions on Topic A, then all on Topic B) feels easier but produces weaker learning. Interleaving topics and question types within a practice session is harder but leads to better discrimination between concepts and better long-term retention.

- Mix question formats in the immediate review rather than grouping by type
- Mix topics within the synthesis section rather than marching through them sequentially
- The short-term discomfort of interleaving is itself a signal it's working

## 7. Desirable Difficulties

Some types of difficulty enhance learning even though they slow performance during practice:
- Retrieval practice (harder than re-reading, more effective)
- Spaced practice (harder to reactivate, more effective than massed)
- Interleaving (harder to track, more effective than blocking)
- Varying practice conditions
- Error detection exercises (finding mistakes in worked examples)

Not all difficulty is desirable. Difficulty from poorly written questions, unclear instructions, or inconsistent formatting is extraneous load — eliminate it. Difficulty from genuine cognitive engagement is the goal.

## 8. Generative Learning

When students generate something — a prediction, a question, a summary in their own words, an explanation — they process the material more deeply than passive exposure. Generation also creates retrieval cues that aid later recall.

Applications in tutorials:
- **Primer predictions:** Before lecture, students write predictions grounded in the mental model. The act of generating these is a learning event, not just a pre-test.
- **Own-words responses:** In the immediate review and content sections, ask students to explain concepts in their own words rather than select the right option.
- **Self-explanation:** Ask "why does this make sense?" questions after worked examples.
- **Teach-back prompts:** "Explain this concept to a first-year student." Forces complete reorganization of knowledge.
- **Student-generated MCQ:** Students write their own exam questions with distractors and explanations — requires identifying key concepts and common misconceptions.
- **Model summary:** At the end of the tutorial, students describe the complete mental model in their own words.

## 9. Feedback Design

Feedback should be explanatory, not just corrective. "Incorrect — the answer is X" teaches less than "Incorrect — the answer is X because Y. Notice how this connects to Z, which you've seen before."

- Correct answers deserve feedback too — confirming *why* something is right deepens understanding
- Feedback should connect back to the mental model, not just restate the fact
- For common misconceptions, address the wrong answer's logic: "If you chose A, you may be thinking of... but notice that..."

**Short-answer questions in learnr — practical constraint:** Exact-match grading means virtually no free-text response will register as correct. Work with this rather than against it:

- Always show the correct answer in the incorrect feedback — since most students won't match exactly, the feedback is where they learn whether they were right, close, or off
- Anticipate the most common errors and name them
- Frame the feedback as informative rather than corrective
- Keep the correct answer statement precise enough to serve as a model answer

**Answer text capture:** The event recorder captures the student's actual response text (via `data$answer`) in the `answer_text` column of the `question_events` sheet. This enables LLM-assisted grading and deeper analysis of student understanding beyond correct/incorrect.

**Self-assessment after key free-text questions:** Follow important `question_text()` items with a trackable MCQ: "How did your answer compare to the model answer? (a) Got the key idea, (b) Partially right, (c) Had a misconception, (d) Didn't know where to start." This provides a trackable signal AND trains metacognitive calibration.

## 10. Metacognitive Scaffolding

Students need to understand how they learn, not just what they're learning. The tutorial system supports this through:

- **Study plan recommendations** on the Welcome page — concrete schedule tied to the forgetting curve
- **Confidence calibration** at the section level — students rate confidence before answering questions, then compare to actual performance
- **Retention forecasts** at the end of each tutorial — "Without review, you'll retain about 40% in one week. A 5-minute review in 2–3 days keeps retention above 80%."
- **Value proposition framing** — the tutorial is positioned as THE primary study tool, not another resource on the pile

**Note:** Deep learning-science instruction (testing effect, desirable difficulties, spacing theory) belongs in the academic success course tutorials, not in every content tutorial. Content tutorials should include brief references ("Questions in this tutorial are learning events, not just assessments") but not devote sections to the science itself.

---

## 11. Exam Question Firewall

Tutorial content must be developed independently from exam content. This is a hard rule, not a guideline.

**The rule:** Tutorial questions must be original — they test the same concepts as exams but use different stems, scenarios, and answer choices. Never copy, closely paraphrase, or reverse-engineer exam items for use in tutorials. Do not frame tutorial content around "what students need to know for the exam."

**Why this matters:**
- If students determine that tutorials preview exam questions, they will substitute tutorial completion for comprehensive study. The tutorial becomes a shortcut rather than a learning tool.
- Exam validity depends on items being encountered for the first time during the assessment. Previewing items — even in altered form — undermines the exam's ability to measure genuine understanding.
- Tutorial questions should build *retrieval strength for concepts*, which transfers to any assessment format. This is more valuable than familiarity with specific items.

**What to do instead:**
- Draw tutorial questions from the same concept space as exams, but with different scenarios, stems, and answer choices
- Use worked examples that illustrate core principles — not items that test the same narrow application an exam question targets
- When faculty provide content specs, redirect any exam-adjacent content toward the underlying concept: "What misconception does this exam question target?" → build a tutorial question around that misconception with a fresh scenario
- Clinical connections and real-world applications are excellent sources for tutorial questions because they test the same understanding in a genuinely different context

**When reviewing or generating questions, check:**
- Could a student who memorized this tutorial question gain an unfair advantage on a specific exam item? If yes, rewrite.
- Is this question testing a concept (good) or previewing a specific assessment item (bad)?

---

## How These Principles Shape Tutorial Structure

These frameworks motivate the following structural decisions in learnr tutorials:

1. **Primer** *(before lecture)* — builds the mental model through sustained analogy, retrieval-based prior knowledge activation, diagnostic self-check, generative predictions
2. **Warm-Up** *(tutorials 2+)* — spaced retrieval of prior tutorial concepts + activation for current tutorial; cross-tutorial remediation when gaps are detected
3. **Immediate review** *(same day as lecture)* — first spaced repetition hit while memory is fresh, interleaved mixed-format retrieval, recall-heavy, short, closes loop on primer predictions, ends with model check
4. **Content sections** *(at own pace)* — lecture content retained with active elaboration: retrieval checkpoints every 200–300 words, worked-example fading (full → faded → independent), self-explanation prompts, instructor insight callouts, clinical connections, teach-back prompts, confidence calibration per section
5. **Synthesis** — interleaved mixed practice across all sections, student-generated MCQ exercise
6. **Model summary** — generative consolidation of the complete mental model
7. **What's next** — retention forecast, spacing recommendation, preview of next tutorial

The placement of immediate review *before* the content sections is deliberate: consolidation happens while lecture memory is fresh, and the content sections then serve as spaced re-engagement with the same material at depth.
