---
name: git-sync
description: Pull, commit, and push changes in git-tracked repos (uucop-hub and course repos). Use this skill after completing any logical unit of work — adding a tutorial, editing a skill, finishing a tutorial section, processing feedback. Also use when the user says "sync", "push", "commit this", "save my work", or "pull latest". Invoke proactively at natural milestones; do not wait until end of session.
allowed-tools: Bash, Read
---

# Git Sync

Handles pull, commit, and push for uucop-hub and course repos. The branching decision is the only judgment call — everything else is mechanical.

---

## Pull

Run before editing files if you haven't pulled in this session:

```bash
git -C <repo-root> pull --ff-only
```

If `--ff-only` fails (diverged history), stop and report to the user — do not force-merge or rebase without explicit instruction.

---

## Commit and push

### Step 1 — Check what changed

```bash
git -C <repo-root> status --short
git -C <repo-root> diff --stat HEAD
```

Count changed files. Note which directories are affected.

### Step 2 — Branching decision

**Default is main.** Only raise the branching question if the change meets the threshold below — otherwise commit to main directly without asking.

**Prompt the user if both are true:**
1. More than 5 files changed, AND
2. Any of these paths are affected:
   - `inst/claude-skills/` (skill files — affect all faculty)
   - `R/` (package source — affects all faculty)
   - Core infrastructure files (`deploy.R`, `tracking-infrastructure.md`, `technical-setup.md`)

**If prompting, keep it short:**
> "This touches [N] files including shared skill/infrastructure files. Push to main, or create a branch first? (Main is usually fine — just flagging since this affects everyone.)"

If the user says main, or doesn't have a strong preference, push to main.

**Never prompt for:**
- `feedback/` additions (TUTORIAL_MAP, bat file, reports)
- Tutorial `.Rmd` edits in course repos
- Planning docs, README, CLAUDE.md updates
- Any change to ≤5 files that doesn't touch skill/package/infrastructure files

### Step 3 — Commit

Stage only the files that are part of this unit of work. Generate a concise commit message (imperative, present tense, under 72 characters) that says what changed and why.

```bash
git -C <repo-root> add <specific files>
git -C <repo-root> commit -m "<message>"
```

### Step 4 — Push

```bash
git -C <repo-root> push origin <branch>
```

If the push is rejected (someone else pushed since your pull), run `git pull --ff-only` first and try again. If that fails, report to the user.

---

## Multi-repo changes

When a single logical unit of work touches multiple repos (e.g., adding a tutorial updates both the course repo Rmd AND uucop-hub's `collect_feedback.py`), commit each repo separately with its own message. Commit the course repo first, then uucop-hub.

---

## What not to do

- Do not use `git add -A` or `git add .` — stage only the files that belong to this change
- Do not amend published commits
- Do not force-push
- Do not skip hooks (`--no-verify`)
