# Night shift: Follow-through on yesterday's calls

Task: turn yesterday's calls into draft follow-ups: draft card notes and draft replies.

Read:
1. Every note in ~/meetings dated the previous business day and every ~/cos/zoom transcript changed since then. Use
   the meeting-analyst agent, one per meeting. If the item names particular calls, do only those.
2. For each commitment found: the board card it belongs to (gh issue view, read-only), and whether it already has a
   reply or a log since the call (if he spoke last, it's done: leave it out).
3. ~/cos/handbook/people.md for owners, and the voice skill for anything in his voice.

Done means: followthrough.md in the job folder. One section per call: each commitment with its owner, date and
transcript timestamp ("proposed" where it wasn't stated outright). For each one he owes:
- a reply he could send, as a Slack draft file slack-drafts/<n>.json in the job folder, exactly this shape:
  {"to": "<person or channel name>", "text": "<the message, in his voice, short>", "thread_ts": "<only if known>",
  "why": "<one line>"}
  The morning step saves it in his Slack Drafts with cos-run slack-draft; nothing is sent, ever.
- or, for his own card, a draft log in three lines (Did / Blocked / Next) in card-notes/<card>.md.
Another owner's card: a one-line note in followthrough.md for him to pass on, never a draft on their card. A
commitment with no card: list it under "needs a card".

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
