# Night shift: Write-up

Task: write up one ask made of Cassidy (like the available-foods rubric), as a draft only he will see.

The ask is the item below: who asked, what for, and by when, if known.

Read:
1. Where the ask came from: the card (gh issue view, with comments), the Slack thread (read-only, permalink), or the
   transcript (timestamp). What exactly was asked, by whom, and what a good answer lets them do.
2. What already exists: DRDs and DADRs in drd/ and dadr/ on ~/cos/data-org-main, open PRs, earlier write-ups in
   ~/cos/outbox, and docs in the repo. Don't redo what's there; cite it.
3. The facts it needs: code (file:line), cards, aggregates already in a lake result (never run new canon queries here).

Done means: writeup.md in the job folder, in the data-org writing standard (point first, short sentences, make
lint-writing clean): a three-line summary first; then the body; then "Sources" with every citation; then "Open
questions" for the asker or for him. Put it together in one pass, not as a chain of lookups. The morning "share"
moves it to a private Google Doc only he can see; you don't touch Google Docs.

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
