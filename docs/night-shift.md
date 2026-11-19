# The night shift

The Mac does a few pieces of real work while Cassidy sleeps, inside a budget he sets, and tells him in the morning
what got done. Nothing leaves the Mac overnight: every result is a draft waiting for his yes.

Approved Nov 19 (plan 2026-11-19, change 8). Built Nov 19; not yet wired to the schedule.

## The day, in four steps

1. **Things get queued.** Cassidy ("tonight: write up Steve's rubric"), OPS, STEWARD or BUILDER adds an item:
   `cos-night add write-up "Steve's available-foods rubric, due Mon" --from cassidy`.
2. **The evening brief proposes tonight's plan.** `cos-night propose` picks what fits the budget and writes it in
   plain words, one line per job with its size and most it can cost. Cassidy answers "all" or the numbers he wants
   (`cos-night approve all` or `cos-night approve 1,3`). Nothing runs without that yes.
3. **At 10 PM the Mac works.** `cos-night run` checks the Mac is plugged in, then runs each approved job one at a
   time through the usual lanes. Each job is stopped at its time limit. A job starts only if the night's money and
   the week's money still cover its full limit.
4. **At 6 AM the morning brief opens with "While you slept".** `cos-night report` writes three lines per job (what
   was done, why it matters, what's ready) and one decision: share, revise or drop. Then
   "Last night: 3 jobs, $11.40, 1 h 35 min." and "This week so far: $41.20 of $100."

"Share" never sends anything by itself. It stages the outward step (a Slack draft, a private Google Doc, a draft PR,
a fix to land) for his yes, the same way as any daytime approval.

## The nine kinds

| Kind | Size | Most it can cost | How it runs | What he gets in the morning |
|---|---|---|---|---|
| Meeting prep for tomorrow | small | $3, 20 min | investigate | one page per meeting: what to raise, what's owed each way |
| Follow-through on yesterday's calls | small | $3, 20 min | investigate | draft replies (as Slack draft files) and draft card logs |
| Board and roadmap cleanup | small | $3, 20 min | investigate | one numbered clean-up list for one yes |
| PR review drafts | medium | $8, 45 min, up to 5 PRs | investigate | one review draft per PR, never posted |
| Data answer | medium | $5, 30 min | lake | the answer with counts and rates only, each with its query |
| Write-up for an ask | medium | $6, 45 min | investigate | a write-up, ready to become a private Google Doc |
| Decision-doc draft (his own cards) | medium | $6, 45 min | investigate | a DRD or DADR draft and up to three questions |
| Fix for the system | medium | $6, 1 h | fix | a tested fix that lands only on his yes |
| Prototype | large | $12, 2 h, at most two a week | build | a tested build slice, ready to become a draft PR |

Each kind has a recipe in `claude/briefs/night-<kind>.md`: what to read, what done means, what to leave in the job
folder, and the four-line morning note.

## The budget

`handbook/night-budget.json` is Cassidy's file. He changes the numbers; nothing else does.
- Per night: $25, 3 hours of work, at most 4 jobs, at most one large job.
- Per week (Monday to Sunday): $100. Prototypes: at most two a week.
- No new job starts after 5 AM, so the morning brief isn't waiting on one.

How the plan is picked: small kinds first (one of each kind a night; meeting prep covers all of tomorrow's meetings
in one job), then the one large job if one is queued and the week allows it, then medium kinds fill what's left.
Anything that doesn't fit waits in the queue with the reason, in plain words.

How the money is kept: a job's cost is read from its own run files (the cost line every Claude job writes). If a job
doesn't report a cost (it was stopped before writing one, or its lane doesn't report one), it's counted at its full
limit, so the budget can't be overspent without anyone seeing it. Every start, end, hold and refusal goes in the
ledger (`~/cos/state/ledger/night.jsonl`).

When a job hits its time limit, the Mac stops it and everything it started. It's reported "partly done", with the
last line of its progress note ("3 of 5 reviews drafted").

## The hard lines (in every recipe)

- Nothing leaves the Mac overnight: no sending, posting, commenting, approving, merging, closing or pushing, and no
  Slack drafts saved. Outward steps are staged as files.
- Canon values never enter a job: aggregates and IDs only.
- Nicholas's live pipeline is never touched. No push to anyone else's branch; another owner's card gets a note in the
  write-up, not an edit.
- The Mac must be plugged in with the lid open. On battery, the night shift doesn't run and the morning brief says so.

## Commands

```
cos-night add <kind> "<what>" [--from cassidy|ops|steward|builder] [--slug <slug>]   queue an item
cos-night propose                   tonight's plan (JSON; .text is the plain-words version)
cos-night approve <ids|numbers|all> his yes
cos-night run                       10 PM, from the Mac's schedule
cos-night report [YYYYMMDD]         6 AM; writes ~/cos/outbox/night-<night>/receipt.json for cos-push
cos-night status                    queue, tonight's plan, last night, the week
cos-night kinds                     the nine kinds and their limits
```

Files: the queue and plan in `~/cos/state/night-queue.json`; one line per job in `~/cos/state/night-runs.jsonl`;
each job's brief in `~/cos/state/night/<night>/`; each job's work in `~/cos/outbox/night-<kind>-<night>-<id>/`.
The night is named by the evening it started (Thursday night's report is `night-20261119`).

Tests: `bash claude/tests/test-night.sh` (a throwaway home, a stub in place of the real jobs, nothing spent).
