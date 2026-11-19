# Night shift: Board and roadmap cleanup

Task: one clean-up list for the board and the Data Roadmap sheet, for one yes in the morning.

Read (read-only; use the repo's own targets, never write):
1. In ~/cos/data-org-main: make board, make stale DAYS=3, make roadmap-check, make weed (whichever exist).
2. The last pulse, capture and reconcile receipts in ~/cos/outbox, so you don't repeat what's already proposed.
3. ~/cos/handbook/board-standard.md and ~/cos/handbook/standing-approvals.json for what's allowed and who owns what.

Done means: cleanup.md in the job folder: one numbered list, at most 15 lines, his own cards first. Each line: the
card in full form, what's wrong (stale, no status, roadmap field blank, wrong lane, broken link), the exact fix, and
whether it needs his yes or is the owner's to do. For his own cards, put the command for each fix under it as a
code line (make set-pillar, make ragb with DRY_RUN=1 first). Another owner's card: "note for <name>", never a fix.
A roadmap field that's blank and has a value in that card's Data Roadmap row: list the fill, marked "blank-field
rule (only once he's switched it on)".

ALWAYS, on every night job
- Nothing leaves the Mac. Never send, post, comment, review, approve, merge, close, label, push, or save a Slack draft.
  Every outward step is a staged file in the job folder, listed in needs_approval, for Cassidy's yes in the morning.
  Don't write apply.sh, sheet.json or standing.sh: the morning "share" stages those after he picks.
- Canon values never enter your context: aggregates and IDs only (counts, rates, ids). No food, label or canon text,
  no rows from canon tables, nothing quoted from them.
- Never touch Nicholas's live pipeline: don't run it, change it, or start anything that feeds it. Never push to
  anyone's branch, and never edit another owner's card or doc: what they should know goes in your write-up as a note.
- Work in small steps. After each step, add one line to progress.md in the job folder, newest last, in plain words
  ("3 of 5 reviews drafted"). The Mac stops this job at its time limit; the last line of progress.md is what Cassidy
  hears if it does.
- Every claim cites its source: file:line, the card or PR number with what you read, transcript path@timestamp, or a
  URL. Write "unverified" where it is.

WHILE YOU SLEPT (write while-you-slept.md in the job folder, last; rewrite it if you stop early)
Four lines, in plain words per ~/cos/handbook/plain-language.md (no job ids, file paths, hashes, lane names, row
numbers or column letters; name cards and PRs in the full form the first time):
1. What was done, in one sentence.
2. Why it matters to him.
3. What's ready and what's left ("partial: 3 of 5" when it is).
Decision: share, revise or drop, and what "share" would do, in a few words.

RECEIPT
status: done, partial (stopped short; say what's left), blocked (needs something only he can give; say what), or
failed. summary: the same three lines. artifacts: every file you wrote. needs_approval: each staged outward step, with
the exact place (card, PR, thread) and why. If there was no input to work on, set summary to exactly: NO CHANGE
