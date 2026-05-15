---
name: mcq-writing
description: Authoritative guide for writing and reviewing multiple-choice questions (MCQs) for UUCOP pharmacy tutorials and quizzes. Load whenever creating, editing, or auditing MCQs in any learnr tutorial Rmd, Shiny quiz app, or practice quiz — including when the user only says "write a question on X", "add some MCQs", "review these questions", "this distractor feels weak", or "make a quiz". This skill is the authority on MCQ quality and supersedes the MCQ-specific rules in tutorial-cleanup; reach for it whenever a question's stem, choices, or distractors are being created or evaluated.
user-invocable: false
---

# Writing Multiple-Choice Questions for UUCOP Tutorials

Well-written MCQs assess what students know. Poorly written ones reward test-wiseness, penalize the knowledgeable, and quietly become reading-comprehension exams. Studies of pharmacy and health-professions assessments consistently find item-writing flaws (IWFs) in 50–78% of MCQs. The default failure mode is not malice — instructors write the kinds of questions they were given as students, perpetuating IWFs across generations. This skill exists to break that cycle for UUCOP tutorial content.

The goal: every MCQ in a tutorial should discriminate between students who understand the concept and students who don't, on the basis of the concept itself — not abbreviation lookup, reading stamina, grammar parsing, or pattern-matching to the longest answer.

Source material: Sylvia & Barr (2011) 31-item checklist; Dell & Wantuch (2017), *Currents in Pharmacy Teaching and Learning* 9:137–144 — the 12 best practices condensed below. See also `references/dell-wantuch-examples.md` for the full worked pharmacy examples.

---

## 1. MCQ Components — Shared Vocabulary

```
Item   = the whole question (stem + all choices)
Stem   = the question or incomplete statement that leads into the choices
Choices / Options = all the possible answers (correct + incorrect)
Key    = the one correct answer
Distractors = the incorrect choices
```

When this skill says "the stem," it means everything above the choices. When it says "distractors," it means only the wrong answers — not the key.

---

## 2. Align Each Question to a Cognitive Level

Before writing the stem, decide what cognitive level the question is supposed to probe. Mixing levels by accident is one of the most common reasons a question fails to discriminate. Use the simplified three-level Bloom's taxonomy (Dell & Wantuch, Table 1):

| Level | What it tests | Common verbs | Pharmacy examples |
|-------|--------------|--------------|-------------------|
| **1. Knowledge / recall** | Recognition of terms, mechanisms, facts | define, list, name, identify, describe, recall | Identify an ACEI; recognize a definition; list common side effects |
| **2. Interpretation / application** | Comparing, applying a definition, recognizing instances | apply, compare, contrast, calculate, differentiate, solve, illustrate | Compare side effects of two drug classes; recognize an example of a mechanism; calculate a dose |
| **3. Problem solving / evaluation** | Synthesis, choosing the best plan from a case | recommend, select, design, propose, judge, assess, eliminate | Recommend a therapeutic plan; select the best agent for a patient |

**Principle:** Determine the objective first; then write a question that genuinely requires that cognitive level. A "level 3" question is not a level 3 question just because it has a long patient stem — it must require synthesis to answer. If the patient details can be deleted and the question is still answerable, the question was never level 3.

---

## 3. The 12 Best Practices

Dell & Wantuch synthesized the literature into 12 rules grouped under General, Stem, and Answer choices. They are the most important rules in this skill. Treat them as the core checklist for every MCQ.

### General (whole-item rules)

**1. Correct grammar, punctuation, and spelling.** Errors confuse readers and sometimes accidentally cue the answer. With proofreading this is the easiest flaw to eliminate.

**2. Streamlined, non-repetitive stem and choices.** Move shared wording out of the choices and into the stem. Repetition increases reading load and often leaks logical cues.

**3. Free of logical cues.** A logical cue is anything that lets a test-wise student pick the right answer without knowing the content. Common cues:
- Absolutes (*always*, *never*, *completely*, *absolutely*) in distractors — they make those distractors easy to dismiss
- Vague hedges (*sometimes*, *may*, *often*) in the key — they advertise it as the safe bet
- *All of the above* — knowing two correct options is enough to win
- *None of the above* — knowing the others are wrong is enough; also impairs subsequent retrieval
- Grammatical agreement between stem and only one choice (singular/plural; a/an)
- Clang associations — a distinctive word in the stem repeated in only one choice
- The key being conspicuously longer, more specific, or more qualified than the distractors
- Pairs/triples of options where only one option could possibly be correct on inspection

**4. Use only appropriate abbreviations.** An abbreviation is appropriate only if any entry-level pharmacist would recognize it unambiguously. *LFTs* can mean liver function tests or lung function tests — context inside a stem is rarely sufficient. Spell out specialty abbreviations unless assessing knowledge of the abbreviation itself is the point.

### Stem (the question itself)

**5. Use question form, or completion form with the blank at the end.** Blanks in the middle force the student to hold the rest of the sentence in working memory while reading choices. This tests working memory, not content.

**6. One question per item; items independent.** A stem like "Which of the following statements is correct?" is really four true/false questions stapled together. So is *EXCEPT* phrasing. Both increase cognitive burden and obscure which concept the student failed. Avoid double jeopardy across items: if missing Q3's staging means the student must miss Q4's therapy choice too, that's one assessment dressed as two.

**7. Positively phrased.** Negative phrasing (*not*, *except*, *contraindicated*, *least appropriate*) doubles the cognitive load and easily creates double negatives in combination with the choices. Reserve negative phrasing for cases where the *not*-doing is genuinely what is being assessed (e.g., contraindications, exclusion criteria). When negative phrasing is necessary, place the negative word at the end of the stem and bold/underline it. Bolding does not eliminate the cognitive cost — it only reduces accidental misreading.

**8. Includes all and only the information needed to answer.** Window dressing — gratuitous case detail, irrelevant labs, friendly social descriptors ("a pleasant 62-year-old...") — converts content questions into reading-stamina questions. This disadvantages slower readers and ESL students without measuring anything pharmacological. When a case stem matters, every clause should be load-bearing for the answer or for distinguishing distractors.

### Answer choices

**9. Use three to five options.** Meta-analytic evidence (Rodriguez 2005) supports three options as often optimal: it is rare to write more than two genuinely plausible distractors, and forcing yourself to five typically produces filler distractors that students can eliminate on sight. Three plausible distractors are better than four with one obvious throwaway. For UUCOP tutorials, **four is the standard default**, three is acceptable, five is reserved for cases where the content genuinely supports five plausible options.

**10. Only plausible, appropriate choices.** Each distractor should represent a *specific* misconception, a *specific* incorrect mechanism, or a *defensible-but-wrong* reasoning path a real student could take. Best source: write distractors from the actual wrong answers students give in class, on prior exams, or in free-response retrievals. If you cannot articulate the reasoning that would lead a student to a given distractor, replace it. Humor and absurd choices reduce the effective number of options and should be omitted (humor sometimes engages, sometimes alienates — not worth the inconsistency).

**11. Parallel options.** All choices should match in verb tense, length, grammatical structure, and level of specificity. A mismatched outlier (the only noun among verbs, the only generic among brand names, the only short one) becomes a logical cue — even when the outlier *is* the correct answer, students will second-guess it. Lack of parallelism almost always traces to insufficient time spent on distractors.

**12. Exactly one correct answer.** This is the single most important rule. The hidden trap is overlapping numeric ranges: choices like `< 160/90`, `< 180/105`, `< 185/110`, `< 200/105` are all technically correct for "TPA can be administered when BP is..." because each is a subset of the largest. Fix by asking for a specific cut-off, by using single values, or by making the ranges mutually exclusive. The distinction between *correct* and *best* answer is legitimate — but the stem must signal which is being asked ("most appropriate," "best initial," "preferred").

---

## 4. Additional Rules From the Sylvia/Barr Checklist

These extend the 12 without duplicating them.

- **Test specifications first.** Each item should reflect a specific blueprint cell (content × cognitive level). For UUCOP tutorials this maps to: which lecture objective × which Bloom level. Avoid trivial content even if it's easy to write items about.
- **Paraphrase, don't quote.** Use language different from the textbook or lecture slides for novel-material testing. Recall of an exact phrase rewards memorization without comprehension. (See Section 5 — Exam Question Firewall — for a stronger version of this rule.)
- **Vary the location of the key.** Across a tutorial, the correct answer should appear in each position roughly equally. In learnr, this is handled mechanically by `random_answer_order = TRUE` (see Section 7), which makes ordering moot at runtime — but when authoring, do not write all keys as option B and rely on the shuffle. Authoring habits leak into review.
- **Order choices logically.** When choices are numbers, dates, or doses, sort them ascending or descending. When they are list lengths, sort by length. This prevents the order itself from being a cue and makes the item easier to scan.
- **Independent, non-overlapping choices.** No choice should subsume another (the TPA trap). No choice should be a paraphrase of another.
- **Homogeneous choices.** All choices should be the same *kind* of thing (all drug names, or all mechanisms, or all doses) — never a mix.

---

## 5. The Exam Question Firewall

From `CLAUDE.md`: tutorial questions must be **original**. They test the same concepts as exams but must use different stems, scenarios, and choices. Do not copy, closely paraphrase, or reverse-engineer exam items into tutorial content. Do not frame tutorial questions as "what students need to know for the exam."

When faculty submit an exam question as a "worked example":
1. Identify the underlying concept or misconception the exam item targets
2. Build a fresh tutorial question around that concept
3. Use a different scenario (different drug in the class, different patient, different presentation)
4. Have the tutorial question probe the same cognitive level

This protects exam validity (no item leakage) and produces better tutorials (concept-anchored, not exam-anchored). See `learning-science` Section 11 for the full rationale.

---

## 6. Common Anti-Patterns — Pharmacy Examples

The Dell & Wantuch paper provides three worked flawed/revised pairs covering all three Bloom levels. Full versions in `references/dell-wantuch-examples.md`. Distilled patterns to watch for:

| Anti-pattern | What it looks like | Why it fails |
|-------------|---------------------|--------------|
| **Two-question stem** | "Which is an appropriate regimen *and* administration?" | Tests two concepts in one item; can't tell which the student missed |
| **Repetition in choices** | Each choice ends "...would be an appropriate regimen" | Reading load; signals streamlining failure |
| **Multiple keys** | Two pharmacologically correct answers in choices | Item is unscorable; reveals lack of review |
| **Negative phrasing + abbreviation soup** | "______ would not be an option in a 62 y/o F with UTI and NKDA, SCr 1.3" | Negative + blank-at-start + buried abbreviations = comprehension test |
| **Non-parallel choice mix** | Three drug names + one drug *class* | The class is either the obvious key or the obvious throwaway |
| **Window-dressed cases** | "A pleasant 62 y/o African American male presents to your trusted ambulatory care clinic..." with lifestyle anecdotes | None of the social detail bears on the JNC-8 recommendation; just reading load |
| **Implausible distractor** | Asking for a hypertension recommendation with naproxen among the choices | Eliminable on sight; effectively reduces option count |
| **Overlapping numeric ranges** | `< 160/90`, `< 180/105`, `< 185/110`, `< 200/105` | All four contain the smaller ones; multiple correct keys |
| **Clang association** | Distinctive word from stem appears in only one choice | Pure pattern-match cue |
| **Absolute language in distractors** | "Always taken with food," "Never given IV" | Trivially eliminated by test-wise students |
| **Chained items** | Q4's correct answer requires Q3's correct staging | Double jeopardy — one missed concept costs two points |
| **Conspicuous key** | One choice is twice as long or has clinical qualifiers the others lack | Length and specificity become the signal |

---

## 7. Integration With `learnr::question()`

Mechanics (full details in `learnr-tutorial` skill):

- `random_answer_order = TRUE` on every `question()` unless when choices are numbers, dates, or doses, sort them ascending or descending — eliminates position as a cue at runtime
- `allow_retry = TRUE` — supports retrieval practice (see `learning-science`)
- `correct = "..."`, `incorrect = "..."` — high-quality feedback; explain *why* the key is right and *why* the chosen distractor is wrong, not just "correct" / "try again"
- `message = "..."` on `answer()` — per-choice feedback; ideal for naming the specific misconception that distractor represents
- `random_answer_order` does not absolve authoring of Rule 11 (parallel options) — non-parallel choices remain cues even when shuffled, because they cue *which choice* is the key, not its position

When in doubt about learnr mechanics, defer to the `learnr-tutorial` skill. This skill owns the content quality of the question; that skill owns the wiring.

---

## 8. Compact Review Checklist

Use this for fast QA passes over existing items. Each row should be answered yes for a clean item.

**Whole item**
- [ ] Aligned to a specific lecture objective and Bloom level
- [ ] Original content (Exam Question Firewall respected)
- [ ] Correct grammar/spelling/punctuation
- [ ] No clang associations between stem and a single choice
- [ ] No logical cues (absolutes, hedges, length, specificity, grammar agreement)
- [ ] No "all of the above" / "none of the above"
- [ ] Abbreviations either universal or spelled out
- [ ] Independent of other items (no double jeopardy)

**Stem**
- [ ] Asks one question
- [ ] In question form, or completion form with blank at the end
- [ ] Positively phrased (or negative is essential, placed last, bolded)
- [ ] Contains only information needed to answer
- [ ] A knowledgeable student could answer it without seeing the choices

**Choices**
- [ ] 3–5 options (default 4 for UUCOP tutorials)
- [ ] Exactly one correct answer (no overlapping ranges)
- [ ] All distractors plausible — each represents a specific student error
- [ ] Parallel in tense, length, structure, and specificity
- [ ] Logically ordered when ordering makes sense (numeric, alphabetic)
- [ ] Homogeneous in kind (all drugs, or all mechanisms, etc.)
- [ ] Key is not conspicuously longer or more qualified
- [ ] `random_answer_order = TRUE` unless intentionally ordered and `allow_retry = TRUE` set in learnr

If the review surfaces a fixable mechanical issue (length imbalance, missing `random_answer_order`, etc.), `tutorial-cleanup` can repair it. If the review surfaces a conceptual issue (weak distractor, mis-aligned Bloom level, double jeopardy), rewrite the item.

---

## 9. When MCQ Is the Wrong Format

MCQ is not the only tool. From the `learning-science` skill target ratio: 40% `question_text()` (free recall), 40% MCQ, 20% other. Reach for non-MCQ formats when:

- The objective is *production* (write a SOAP note, calculate a dose, explain a mechanism in your own words) — use `question_text()` for retrieval, even if it cannot be auto-graded
- The objective is *evaluation of a full case* — consider one or two long-form cases rather than splintering into 6 small MCQs
- The objective is *communication* — MCQ cannot assess how a student would speak to a patient
- You cannot write four plausible distractors after honest effort — the content may not be MCQ-shaped, or the cognitive level may not be what you assumed

Don't force MCQ. A well-written `question_text()` beats a forced MCQ with two filler distractors.

---

## References

- Sylvia LM, Barr JT. *Pharmacy Education: What Matters in Learning and Teaching.* Jones and Bartlett, 2011. (Checklist adapted from Haladyna)
- Dell KA, Wantuch GA. How-to-guide for writing multiple choice questions for the pharmacy instructor. *Currents in Pharmacy Teaching and Learning* 2017; 9:137–144.
- Haladyna TM, Downing SM, Rodriguez MC. A review of multiple-choice item-writing guidelines for classroom assessment. *Appl Meas Educ.* 2002; 15:309–334.
- Rodriguez MC. Three options are optimal for multiple-choice items: a meta-analysis of 80 years of research. *Educ Meas Issues Pract.* 2005; 24(2):3–13.
- NBME. *Constructing Written Test Questions for the Basic & Clinical Sciences*, 3rd ed.
- Worked flawed/revised pairs: `references/dell-wantuch-examples.md`
