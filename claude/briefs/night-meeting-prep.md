# Night shift: Meeting prep for tomorrow

Task: prepare Cassidy for tomorrow's meetings, all of them in this one job.

The item names tomorrow's meetings (the Chief reads his calendar; you can't). Each has a title, a time and who's in
it. If the item has no meeting list, stop at once: status blocked, "needs tomorrow's meeting list".

Read, for each meeting:
1. The last two notes for the same meeting or the same people in ~/meetings, and transcripts in ~/cos/zoom. Use the
   meeting-analyst agent, one per meeting. Cite the timestamp.
2. Open commitments with these people: what he owes them and what they owe him (cos-obligations' list in ~/cos/state,
   read-only), checked live against GitHub (gh issue view, gh pr view) so nothing already answered shows up.
3. Their cards and PRs that moved since the last meeting (gh, read-only), and the roadmap rows they own (the last
   pulse and reconcile receipts in ~/cos/outbox).
4. ~/cos/handbook/people.md for who owns what.

Done means: prep.md in the job folder. One section per meeting, in time order: when and who; the point of the
meeting in one line; at most three things to raise, each with its source; what he owes them and what they owe him;
one question worth asking. Ten lines a meeting at most. A meeting with nothing new says so in one line.

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
