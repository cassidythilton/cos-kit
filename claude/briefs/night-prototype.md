# Night shift: Prototype

Task: one build slice, tested, ready to become a draft PR on his yes.

The item below says what to build. Work only in the build workspace this job was given. Data comes from an earlier
lake result (a result.md in ~/cos/outbox), never a live query from here.

Read: the workspace's BRIEF.md, HANDOFF.md and VERIFY.md; the card or opportunity it came from (BUILDER's
opportunities.md in ~/cos/outbox, with its DILIGENCE block); the repo code it builds on (read-only).

Done means: the slice works and ./verify passes, with BASELINE and BEHAVIOR proofs in the receipt (QUALITY too);
HANDOFF.md updated with what's done, what's next and how to run it; pr.md in the job folder with a draft PR title and
body (what it does, how it was tested, what it doesn't do yet). No push, no PR tonight: the morning "share" stages
the draft PR for his yes. If the slice can't finish inside the limit, stop at a clean point with ./verify passing on
what's there, and say what's left.

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
