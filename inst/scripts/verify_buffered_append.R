# Live check that the buffered writer produces the same cells sheet_append did.
#
# Run from the RMD root:
#   Rscript "uucopTutorials/inst/scripts/verify_buffered_append.R" <SHEET_ID>
#
# Creates a temporary "_buffer_test" tab on that sheet, writes three rows
# through the buffer, reads them back, and deletes the tab. It never touches
# sessions / question_events / section_events.

args     <- commandArgs(trailingOnly = TRUE)
SHEET_ID <- if (length(args)) args[[1]] else Sys.getenv("GS4_SHEET_ID")
TAB      <- "_buffer_test"

if (!nzchar(SHEET_ID)) stop("Pass a sheet ID, or set GS4_SHEET_ID.")

library(uucopTutorials)
library(googlesheets4)

setup_gs4_auth(local_json = ".secrets/gs4-service-account.json")

message("Creating temporary tab '", TAB, "' ...")
sheet_add(SHEET_ID, sheet = TAB)
on.exit({
  message("Deleting temporary tab '", TAB, "' ...")
  try(sheet_delete(SHEET_ID, sheet = TAB), silent = TRUE)
}, add = TRUE)

# Header row, then three event rows covering every type the loggers emit.
sheet_append(SHEET_ID, data.frame(
  user = "user", app = "app", date = "date", time = "time",
  question = "question", attempt = "attempt",
  first_attempt_correct = "first_attempt_correct", correct = "correct",
  answer_text = "answer_text", stringsAsFactors = FALSE
), sheet = TAB)

mk <- function(q, attempt, correct, ans) data.frame(
  user = "buffer.test", app = "VERIFY", date = "2026-08-13", time = "14:03:22",
  question = q, attempt = attempt,
  first_attempt_correct = (attempt == 1L) && correct,
  correct = correct, answer_text = ans, stringsAsFactors = FALSE
)

message("Queueing 3 rows ...")
uucop_sheet_append(SHEET_ID, mk("q1", 1L, TRUE,  "12.5 mg"), TAB)
uucop_sheet_append(SHEET_ID, mk("q2", 2L, FALSE, NA_character_), TAB)
uucop_sheet_append(SHEET_ID, mk("q3", 1L, FALSE, "not sure"), TAB)

message("Flushing (expect ONE API request for all three rows) ...")
n <- uucop_flush_events()
message("Rows written: ", n)
stopifnot(n == 3L)

got <- read_sheet(SHEET_ID, sheet = TAB)
print(got)

cat("\nColumn types as stored:\n")
print(vapply(got, function(x) class(x)[[1]], character(1)))

cat("\nExpected: date/time are character (NOT Date/POSIXct -- that would mean\n",
    "valueInputOption slipped back to USER_ENTERED), attempt is numeric,\n",
    "correct is logical, and q2's answer_text is NA.\n", sep = "")

ok <- is.character(got$date) && is.character(got$time) &&
      is.numeric(got$attempt) && is.logical(got$correct) &&
      is.na(got$answer_text[[2]])
cat("\nRESULT: ", if (ok) "PASS" else "FAIL", "\n", sep = "")
