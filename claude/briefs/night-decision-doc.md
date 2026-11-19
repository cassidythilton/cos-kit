# Night shift: Decision-doc draft

Task: draft a decision doc (a DRD, a requirement, or a DADR, a decision record) for one of Cassidy's own cards.

The card is in the item below. If it isn't his card (gh issue view: assignee or author is Cassidy), stop: status
blocked, "that card is <owner>'s; the decision doc is theirs to write".

Read:
1. The card, its comments, linked PRs, and related DRDs and DADRs in drd/ and dadr/ on ~/cos/data-org-main and in open
   PRs (gh pr list --repo wisecodeai/data-org --state open --limit 200 --search DRD). If one already exists, stop and
   name it: the work is an amend, not a new doc.
2. The skill and template the repo uses: .cursor/skills/draft-drd or draft-dadr, templates/<kind>-template.md, and
   AGENTS.md's writing standard, all on ~/cos/data-org-main.
3. Sources for each section: transcripts (timestamp), Slack (permalink), docs (path).

Done means: decision-doc.md in the job folder: the draft, following the template, status Draft (a DRD) or proposed
(a DADR), never Approved or accepted. Every section sourced or marked "not sourced". sourced.md: each interview
question, its answer and its source. At most three numbered questions only he can answer, in open_questions, each with
options. No ID is taken and no branch is made tonight: the morning "share" runs the draft lane on his card, which
takes the next ID and opens it as a draft for his yes.

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
