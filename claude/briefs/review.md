Task: review pull request {{REPO}}#{{N}} ("{{TITLE}}", {{URL}}) for Cassidy, who is a requested reviewer. Write the
review he would submit. Head commit at the start of this job: {{HEAD}}.

Read, in order:
1. gh pr view {{N}} --repo {{REPO}} --json title,body,author,baseRefName,headRefOid,files,comments,reviews,closingIssuesReferences
2. gh pr diff {{N}} --repo {{REPO}} (read it all; for very large diffs, read every changed file's hunks before judging)
3. Every issue the PR references (Tile: #n, Refs #n, Closes #n) with gh issue view, including comments.
4. The repo's rules on origin/main. For data-org: AGENTS.md, CONTRIBUTING.md, standards/writing.md, and for a DRD or
   DADR the template and the gate (run `make gate` and `make lint-writing FILE=<changed .md>` in ~/cos/data-org-main
   on the PR's files if you can fetch them read-only with `gh pr diff`; otherwise judge against the written rules).
5. Earlier reviews and comments on the PR, so you don't repeat what someone already said, and Cassidy's own
   comments anywhere on the linked issues (his position wins over a generic opinion).

Judge it the way Cassidy would: does it do what the linked issue asks, does it follow the repo's rules, is anything
wrong, missing or unclear, does it touch his areas (the board, the roadmap, the work system, the image extractor,
data providers) in a way that conflicts with what he has said.

Evidence, for every finding (the checker fails the review without it, and it posts under Cassidy's name):
- Add one receipt.evidence entry per finding: the diff file and line, or the exact command you ran and what it showed.
- Check live state before stating it: gh issue view for a card, the board via `make board` or `make stale`, the
  Makefile or scripts on ~/cos/data-org-main for how a target behaves. Never state a count you didn't read.
- Anything you couldn't verify is written as a question to the author ("Does X happen when …?"), never as a fact.
- Lint with exactly `make lint-writing FILE={{OUT}}/review.md` from the folder you start in (~/cos/data-org-main), and
  record the clean result as the QUALITY proof.

Write {{OUT}}/review.md, the review body, in plain Markdown that passes `make lint-writing` (point first, short
sentences, no em dashes, no semicolons). Shape:
- First line: what the PR does and whether it is ready, in one or two sentences.
- Then numbered findings, most important first. Each names the file and line (or the section), says what is wrong
  or missing, and what would fix it. Only real findings. Praise only if it informs a decision.
- Then questions for the author, if any.
- No sign-off, no mention of AI, no "LGTM" filler.
Run make lint-writing on it and fix every finding.

Then decide who submits it:
- If the review is a normal comment review, write {{OUT}}/standing.sh with exactly this one line and nothing else:
  gh pr review {{N}} --repo {{REPO}} --comment --body-file {{OUT}}/review.md
  The Mac submits it under Cassidy's standing approval: comment only, never approve, never request changes.
- Do NOT write standing.sh, and say why in open_questions, if any of these hold: the PR asks Cassidy for a decision
  only he can make; it changes something he owns or has a stated position on and the review would commit him to a
  position he hasn't taken; you think it should be blocked (request changes); you could not read the diff; or the
  head commit changed while you worked (check gh pr view --json headRefOid at the end).

Never submit, comment, approve or edit anything yourself. Done means: review.md (and standing.sh, unless one of the
reasons above applies), and a receipt whose summary says "comment review ready" or "needs Cassidy: <why>".
