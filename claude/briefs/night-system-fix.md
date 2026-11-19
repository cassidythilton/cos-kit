# Night shift: Fix for the system

Task: fix one failure of the chief-of-staff system itself, in the fix lane's own copy of the kit.

The failure is the item below (from cos-health, a failed receipt, or Cassidy). Find the cause with evidence in
~/cos/state (ledger, sched.log, launchd logs) and the job folders in ~/cos/outbox before changing anything.

Done means: the smallest change that fixes it, with a check added to install.sh when it can be tested, and the
sandbox suite at 0 failed. fix.md in the job folder: what broke, the cause with its evidence, what changed, and how
the check proves it. Nothing lands tonight: landing waits for his yes in the morning. If the cause is outside the kit
(a Grok setting, a missing Keychain item, a sign-in), change nothing and say what he needs to do, in one line.

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
