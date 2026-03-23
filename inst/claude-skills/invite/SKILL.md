---
name: invite
description: "Manage shinyapps.io student access for all apps in this project (antidiabetics tutorials, NSC Lab apps, Analytics Dashboard). Use whenever the user wants to grant access to a class or cohort (ClassOf2028, ClassOf2029, P1, P2) or individual students; check who currently has access to an app; or remove/revoke student access at end of semester. Trigger on phrases like invite, add students, let students in, who has access, show users, remove students, revoke access. Do NOT use for deploying apps, editing tutorial content, debugging session logging, or viewing analytics data."
allowed-tools: Read, Bash, Edit
---

# Student Access Management

All student-facing apps are private on shinyapps.io. This skill handles three operations: **invite**, **show**, and **remove**.

---

## Cohort CSV files

Student rosters live at the RMD root as `ClassOf{year}.csv`. Each must have an `email` column.

| File | Cohort |
|------|--------|
| `ClassOf2028.csv` | P2 (current second-year class) |
| `ClassOf2029.csv` | P1 (current first-year class) |

Update these as classes advance each year. Path: `C:/Users/andjc/OneDrive - Union University/Pharmaceutics - Documents/RMD/ClassOf{year}.csv`

---

## Which deploy.R to use

| App type | Source |
|----------|--------|
| PHM 726 Anti-Diabetics tutorials | `PBDA1/deploy.R` |
| PHRM 764 Non-Sterile Lab apps | `Pharmaceutics Non-Sterile Lab/Labs/deploy.R` |
| Analytics Dashboard | `Analytics-Dashboard/deploy.R` |

---

## Operation: Invite

### Step 1 — Confirm the app is private (pause here)

Tell the user:

> Before inviting students, confirm the app is set to **private** on shinyapps.io:
> 1. Go to [shinyapps.io](https://www.shinyapps.io) → Applications → find the app
> 2. Click the app → Settings → Visibility → set to **Private** → Save
>
> Reply when done and I'll proceed with the invitations.

**Wait for confirmation before continuing.**

### Step 2 — Grant access

Source the appropriate `deploy.R` and call `invite_students()` with `send_email = FALSE` (the shinyapps.io built-in email doesn't work reliably — we send separately):

```r
source("PBDA1/deploy.R")
invite_students(
  csv_path     = "C:/Users/andjc/OneDrive - Union University/Pharmaceutics - Documents/RMD/ClassOf2029.csv",
  tutorials    = "part1",
  send_email   = FALSE,
  message_text = NULL
)
```

For NSC Labs, use `deploy_labs()` equivalent:
```r
source("Pharmaceutics Non-Sterile Lab/Labs/deploy.R")
invite_students(
  csv_path   = "C:/Users/andjc/OneDrive - Union University/Pharmaceutics - Documents/RMD/ClassOf2029.csv",
  labs       = 1:7,
  send_email = FALSE
)
```

### Step 3 — Draft invite email

Draft an email appropriate to the app and course. Show it to the user for approval or edits before sending. The draft should:
- Explain what the app/tutorial is and how it fits the course
- Include a note that the shinyapps.io invite link arrives separately (students need to accept the shinyapps.io invite email to activate access)
- Be warm and brief — not a formal announcement

Template structure:
```
Subject: [Course] — [App/Tutorial Name] Now Available

Hi,

[1–2 sentence description of what the app is and its purpose in the course.]

[1 sentence on how to access — accept the shinyapps.io invite, then use the link.]

[Optional: any notes on how to use it, what to expect, or feedback request.]

Thanks,
Dr. Castleman
```

### Step 4 — Send email (after approval)

Load SMTP credentials from a tutorial `.Renviron`, then send via blastula BCC to all students:

```r
# Load SMTP credentials from an existing tutorial .Renviron
readRenviron("PBDA1/antidiabetics_part1/.Renviron")

emails <- read.csv(
  "C:/Users/andjc/OneDrive - Union University/Pharmaceutics - Documents/RMD/ClassOf2029.csv",
  stringsAsFactors = FALSE
)
student_emails <- trimws(emails$email[nzchar(trimws(emails$email))])

invite_email <- blastula::compose_email(
  body = blastula::md(email_body_text)  # use the approved draft
)

blastula::smtp_send(
  email       = invite_email,
  to          = Sys.getenv("SMTP_USER"),
  bcc         = student_emails,
  from        = Sys.getenv("SMTP_USER"),
  subject     = email_subject,
  credentials = blastula::creds_envvar(
    user        = Sys.getenv("SMTP_USER"),
    pass_envvar = "SMTP_PASS",
    host        = "smtp.gmail.com",
    port        = 465,
    use_ssl     = TRUE
  )
)
```

---

## Operation: Show users

Source the relevant `deploy.R` and call the show function:

```r
source("PBDA1/deploy.R")
show_users()                     # all tutorials
show_users(tutorials = "part1")  # specific tutorial
```

```r
source("Pharmaceutics Non-Sterile Lab/Labs/deploy.R")
show_lab_users()          # all labs
show_lab_users(labs = 1)  # specific lab
```

---

## Operation: Remove students

Used at end of semester. Source the relevant `deploy.R` and call `remove_students()`:

```r
source("PBDA1/deploy.R")
remove_students(
  csv_path  = "C:/Users/andjc/OneDrive - Union University/Pharmaceutics - Documents/RMD/ClassOf2028.csv",
  tutorials = names(TUTORIAL_CONFIG)  # or specify: c("part1", "part2")
)
```

```r
source("Pharmaceutics Non-Sterile Lab/Labs/deploy.R")
remove_students(
  csv_path = "C:/Users/andjc/OneDrive - Union University/Pharmaceutics - Documents/RMD/ClassOf2028.csv",
  labs     = 1:7
)
```

Confirm with the user before running removal — it revokes access immediately.

---

## Notes

- Student email domain is `@my.uu.edu` (not `@uu.edu`) — verify CSV emails match
- If a student's shinyapps.io invite expires before they accept, re-run `invite_students()` for just that student
- The shinyapps.io invite email (from shinyapps.io directly) and the separate Gmail invite email are independent — students need to accept both
