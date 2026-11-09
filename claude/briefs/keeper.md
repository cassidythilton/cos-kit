Task: KEEPER's weekly audit of the bots and the Mac lanes. Find what keeps going wrong, check the system still matches the team's rules and its sources, and propose the fix.

Read first, in this order:
1. ~/cos/handbook/system-map.md: every source, every rule, and what may cross which wire.
2. The rules it names, fresh from origin/main: data-org AGENTS.md, CONTRIBUTING.md (the boundary), standards/writing.md, the work-system, commands-by-cadence and board-weeding docs, the Makefile help (`make help` or the Makefile's ## lines) in ~/cos/data-org-main; data-org-notebook AGENTS.md and HANDOFF.md in ~/cos/notebook-main; canon charter decisions 14 and 28.
3. The kit's own rules: ~/cos/handbook/rules.md, board-standard.md, engineering-standard.md, ~/cos/claude/lane.md, build-lane.md, verifier.md, the briefs, and ~/cos/kit/grokbot/*.md (what each bot was told).

Then the week's evidence (last 7 days):
- ~/cos/state/corrections.jsonl: every correction Cassidy recorded, by bot.
- Every ~/cos/outbox/*/receipt.json: status, checker verdict and failures, verifier level, baseline reading, cost. run.err when a job failed.
- ~/cos/state/sched.log: missed, failed, skipped and no-change runs.
- ~/cos/evals/runs/*/report.json: the latest eval results.
- ~/cos/kit git log, and git log on data-org and data-org-notebook origin/main for the week: what changed in the system and in the rules it wraps.
- Slack, read-only, only the channels system-map.md lists for work signals: any message where someone corrected or questioned something a bot drafted for Cassidy.

Produce:
1. Scorecard, one line per bot and lane: runs, checker pass rate, verifier levels, cost, corrections, misses.
2. Rules drift: anything in the repos that changed this week and that the kit wraps (a new or renamed make target, a changed skill, a writing-standard rule, a new boundary item, a new charter decision). For each: what changed (file and commit), what in the kit depends on it, and the edit.
3. Conformance: any receipt, draft or batch this week that broke a repo rule (writing standard, boundary, context/, branch naming, notebook conventions, decision 14). One line each, with the job id.
4. Context health: is every source in system-map.md still reachable and current? Check: the latest file date in ~/meetings and ~/Documents/Zoom, whether this week's jobs could read Slack and the roadmap sheet (from their receipts), whether `gh auth status` passes, whether PR #610 merged (then the cold-start path changes), whether the Field Guide has turned up. A source that went dark is a finding.
5. Patterns: a mistake seen twice or more (one-offs aren't patterns). For each: the evidence, the root cause, and the fix at the strongest rung that works: fix the setup; add a check (gate.sh, the checker's checklist, ./verify, a make target); edit a skill, lane prompt or brief; a remembered rule in one bot.
6. Proposals, at most three, most valuable first:
   - lane prompt or brief: the full proposed file in the job folder as <name>.proposed.md and the command `cos-run eval core <path>`. Don't run it.
   - kit code: a unified diff against ~/cos/kit in proposal.patch.
   - system-map.md: the proposed file as system-map.proposed.md.
   - a Grok bot: the exact text Cassidy would paste.
   - a new eval case for ~/cos/evals/core.json when a pattern is fixed.
7. The one thing Cassidy wouldn't miss: a routine, bot or lane that costs more than it returns.

Never apply a change. Nothing here edits a bot, a skill, the map or the kit. Write keeper.md (and any proposal files) in the job folder. The receipt summary carries counts and job ids only, no canon terms or label text.
If there were no failures, no corrections, no misses and no rules drift this week, set summary to exactly: NO CHANGE
