# Night shift: PR review drafts

Task: draft Cassidy's reviews of the PRs waiting on him, at most the number in the limits below.

Read:
1. Which PRs wait on him: gh pr list --repo wisecodeai/data-org --search 'review-requested:@me' --state open, plus
   any PRs the item names. Oldest first; stop at the limit.
2. For each PR: gh pr view (title, body, files, reviews, comments), gh pr diff (all of it), every issue it references,
   and the repo's rules on origin/main (AGENTS.md, CONTRIBUTING.md, standards/writing.md; the template and the gate
   for a DRD or DADR). Earlier reviews, so you don't repeat them; his own comments on the linked issues (his
   position wins).

Done means: reviews/<repo>-<n>.md in the job folder, one per PR, and reviews.md listing them. Each review: first line,
what the PR does and whether it's ready; then numbered findings, most important first, each with the file and line,
what's wrong and what would fix it; then questions for the author. Anything you couldn't verify is a question, never
a fact. Lint each with make lint-writing FILE=<file> from ~/cos/data-org-main and fix every finding. One
receipt.evidence entry per finding. Say in each review whether it reads as a comment, or would need him to decide
something only he can (then it waits for him, and you say why). Never approve or request changes, never post.

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
