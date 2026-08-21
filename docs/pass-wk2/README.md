# PASS WK2 Warm-Up — static tutorial prototype

Live: <https://acastleman.github.io/uucopTutorials/pass-wk2/>

A trial of running a UUCOP learnr tutorial as a static page instead of a Shiny
app. Costs zero shinyapps.io instance hours.

Four questions from the WK2 Retrieval Practice Warm-Up, ported verbatim from
`courses/PHRM707_PASS/tutorials_flipped/02_retrieval_practice/`. Exercises both
question types, retry, randomised answer order, and a no-retry self-assessment
item. The panel at the bottom shows every event that would be POSTed to
Supabase.

**This page is public and unauthenticated.** It has no Supabase credentials
configured, so nothing is recorded — events queue in `localStorage` and are
displayed instead. Answer keys are visible in page source, which is expected:
GitHub Pages cannot be access-controlled, and tutorial content is not protected
material.

| file | what it is |
|---|---|
| `index.html` | page shell, header, prose |
| `questions.js` | the questions as **data** — the point of the prototype |
| `uucop-static.js` | grading, retry, 20/20 header, active-time clock, event queue |
| `uucop-static.css` | stand-in for the real `www/uucop-tutorial.css` |

Backend pieces (`supabase_schema.sql`, `portal_link.R`) are deliberately **not**
published here; they live in the working copy at
`RMD/prototypes/static-tutorial/`, along with the full design notes and the list
of known gaps.

In the real version the Student Portal — already authenticated, already running
— signs a token and links here with it in the URL fragment, so no gatekeeper app
is needed and a static tutorial adds no instance hours at all.
