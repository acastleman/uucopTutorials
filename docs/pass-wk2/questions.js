/* questions.js — WK2 Warm-Up section, ported verbatim from
   courses/PHRM707_PASS/tutorials_flipped/02_retrieval_practice/retrieval_practice_tutorial.Rmd

   THIS FILE IS THE POINT OF THE PROTOTYPE. Content stops being code and becomes
   data. Porting the remaining 11 questions is transcription, not engineering,
   and a build script can generate this array straight from the Rmd chunks --
   question()/question_text() calls map 1:1 onto the objects below.

   Field mapping from learnr:
     question()      -> kind: "single"
     question_text() -> kind: "text"      (model answer, never auto-graded)
     answer(correct=TRUE) -> correct: true
     allow_retry, random_answer_order -> same names
     correct/incorrect -> feedback.correct / feedback.incorrect
*/
window.UUCOP_QUESTIONS = [
  {
    label: "q_pipeline_rem_101",
    kind: "text",
    prompt: "Name the five stages of the Learning Pipeline from WK1 and briefly describe what happens at each stage. Use the road analogy if it helps.",
    placeholder: "Stage 1: ...\nStage 2: ...\nStage 3: ...\nStage 4: ...\nStage 5: ...",
    allow_retry: true,
    model: "Model answer: (1) Info arrives — sensory input from the environment. (2) Attention (on-ramp) — only attended information enters working memory; distracted attention means the signal never gets on the highway. (3) Working memory — conscious processing, limited to ~4–7 items; the busy intersection. (4) Encoding — information moves from working memory into long-term storage; paving a dirt track into a road. (5) Long-term memory — vast storage, but unused roads become overgrown (knowledge decay)."
  },
  {
    label: "q_pipeline_self_102",
    kind: "single",
    prompt: "How many of the five stages did you recall accurately without looking?",
    allow_retry: false,
    random_answer_order: false,
    choices: [
      { text: "All five with correct descriptions" },
      { text: "Four stages accurately", correct: true },
      { text: "Three stages accurately" },
      { text: "Fewer than three — I needed to look" }
    ],
    feedback: {
      correct: "Good self-assessment.",
      incorrect: "Good self-assessment."
    }
  },
  {
    label: "q_decay_und_103",
    kind: "single",
    prompt: "According to WK1, knowledge decay occurs because:",
    allow_retry: true,
    random_answer_order: true,
    choices: [
      { text: "The brain runs out of storage space and deletes old information" },
      { text: "Synaptic connections that are not regularly used weaken and are pruned", correct: true },
      { text: "Stress hormones during exam periods erase recently encoded memories" },
      { text: "Working memory overwrites long-term storage when new material is learned" }
    ],
    feedback: {
      correct: "Correct. Decay is a normal pruning process — the brain removes connections it interprets as unimportant. The remedy is regular retrieval, which reactivates the connection and signals it should be kept.",
      incorrect: "Not quite. The brain does not work like a hard drive with a finite capacity. Decay happens because unused synaptic connections weaken — the brain prunes them as part of normal maintenance. Regular retrieval is the countermeasure."
    }
  },
  {
    label: "q_myths_und_104",
    kind: "single",
    prompt: "A first-year pharmacy student tells you she studies pharmacokinetics exclusively by watching lecture recordings repeatedly, because she is an 'auditory learner.' Based on WK1, what is the most accurate response?",
    allow_retry: true,
    random_answer_order: true,
    choices: [
      { text: "Her approach is sound — repeated exposure to audio is an effective consolidation strategy" },
      { text: "The learning styles framework has no empirical support, and repeated passive exposure produces familiarity rather than durable recall", correct: true },
      { text: "Her approach would work better if she also made visual diagrams to match her auditory preference" },
      { text: "Auditory repetition is valid for declarative knowledge but not procedural knowledge" }
    ],
    feedback: {
      correct: "Correct. Two WK1 concepts apply here: the learning styles myth (there is no evidence that matching instruction to a style label improves learning) and the limitation of passive repetition (re-exposure creates familiarity, not mastery). WK2 will explain why these two points are deeply connected.",
      incorrect: "Not quite. Two WK1 concepts apply: the learning styles framework has no empirical support, and repeated passive exposure builds familiarity rather than durable recall."
    }
  }
];
