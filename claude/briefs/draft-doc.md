Task: draft a {{KIND}} for Cassidy's card {{CARD}} (plan 2026-11-14, item 8), by data-org's own skills.

Read first, from the repo root of this worktree: .cursor/skills/{{SKILL}}/SKILL.md (the interview), .cursor/skills/{{LC}}/SKILL.md
(the contract), templates/{{KIND}}-template.md, the writing standard in AGENTS.md, and docs/2026-10-12-work-system.md. The
DRD and DADR check lives in PR #524, open, not merged: read it with gh pr diff 524 --repo wisecodeai/data-org, and say
"per PR #524 (open)" when you use it.

The skill is an interview, and a job can't interview. So work in two rounds.

Round 1 (this brief carries no answers from Cassidy yet):
- Read the card (gh issue view), its comments, linked PRs, and the related DRDs and DADRs in drd/ and dadr/ and in open
  PRs (gh pr list --repo wisecodeai/data-org --state open --limit 200). Read the card's DRD line and drd/ first. If a
  DRD for this requirement already exists, stop: say so, and name it; the work is an amend, not a new doc.
- Fill every interview answer you can source: the card, transcripts in ~/cos/zoom (cite the timestamp), Slack (cite the
  permalink), related docs (cite the path). Write sourced.md in the job folder: each interview question, the answer,
  and its source, or "not sourced".
- Return at most three numbered questions that only Cassidy can answer, in open_questions, each with options where you
  can. For a DRD these are usually: the requirement as a commitment (one sentence), the owner (one name), and what the
  sources leave open. For a DADR: the ranked drivers, the deciders, the owner.
- Change nothing in the repo in round 1.

Round 2 (the brief carries his answers):
- make next-id KIND={{KIND}}. Then DRY_RUN=1 make scaffold KIND={{KIND}} ID=00NN TITLE="<title>" INIT=P0xx ISSUE=<n>, then the
  same without DRY_RUN. INIT and ISSUE come from the card; never invent an ID.
- Fill the sections by the skill. Run make gate and make lint-writing FILE=<the file> until clean, or until a failure
  needs a person; put both outputs in proofs.
- Status stays Draft (a DRD) or proposed (a DADR). Never Approved, never accepted: the CDO ratifies. Don't edit context/.
- One document per draft. A DRD and a DADR go in separate PRs, so never both new in one diff. A DADR's cascade edits
  to existing DRDs belong in the same diff (the dadr skill).
- Write pr.md in the job folder. Line 1: the title, "{{KIND}}-00NN (Draft): <title>". Then the body: "A merge registers a
  document.", "Tile: #<card>", and for a DRD "Closes #<its DRD sub-item>" (or say there is none), for a DADR
  "Refs #<card>".

What leaves the Mac: the title, the ID, the PR link and the questions. Never the doc text. A DRD cites canon tables and
aggregates, never canon values.

Done means. Round 1: sourced.md and at most three numbered questions. Round 2: the file, make gate and make
lint-writing output, pr.md. The push and the draft PR happen after this job, outside it, each re-checking the ID:
cos-run gh <job> push <this job> --branch cassidy/<issue>-<topic>, then cos-run gh <job> draft-pr data-org
cassidy/<issue>-<topic> --title "<line 1 of pr.md>" --body-file <job folder>/pr-body.md.
