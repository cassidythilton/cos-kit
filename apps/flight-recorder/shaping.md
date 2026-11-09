# Flight recorder

The question the page answers: what did my bots and my Mac do, what did it cost, and did anything get blocked or miss?

Audience: Cassidy, alone, at his desk. He acts on a block, a missed scheduled run, a failed checker, or a correction that has shown up twice.

## Recon (this Mac, 2026-11-09)

There is no replica and no `database.schema.table`. The sources are files on the Mac. Counted read-only before any loader existed.

| Source | What is there |
|---|---|
| `~/cos/outbox/` | 16 job folders, all dated 2026-11-09. No `~/cos/archive/` jobs yet. |
| Receipts | 11 Claude `investigate` runs, 5 Cursor `quick` runs. Claude dollars on the receipts: $6.59. Cursor receipts have no `cost_usd`. |
| Checker | 5 pass, 6 fail, 5 with no checker (the quick runs). |
| Receipt status | 11 done, 4 blocked, 1 partial. |
| `~/cos/state/sched.log` | 4 lines: one skipped followups, one pulse that started and was pushed, one skipped keeper. |
| `~/cos/state/corrections.jsonl` | 6 notes. |
| `~/cos/state/board-health.csv` | 1 row, `as_of` 2026-11-09. |
| `~/cos/evals/runs/` | 1 run, `core-20261109-064738`. |
| Apply batches | `apply.sh` exists on some jobs. No `apply-receipt.json` yet, so nothing has been applied. |
| Ledger | Did not exist. Gate blocks, pushes, commands and files touched were not recorded as events. |

Claude transcripts are `~/.claude/projects/*/<session_id>.jsonl` plus `subagents/*.jsonl`. `run.json` holds `session_id`. A spot check of `smoke` found Bash and Write tool calls. Cursor quick runs have no Claude transcript. Their commands are the `$ ` lines in `context.txt`.

## Requirements

| Id | Requirement | Status |
|---|---|---|
| R1 | One place that answers the question above, for Cassidy at this Mac. | Core goal |
| R2 | Every Mac action appends one JSON line. A log failure never changes a gate decision, an exit code, or the order of checks. | Must-have |
| R3 | The raw record is append-only JSONL. Only the loader writes SQLite. | Must-have |
| R4 | No secrets, file contents, tool outputs, or canon values in the ledger. Commands and paths only, redacted, commands capped at 300 characters. | Must-have |
| R5 | Re-running the loader is safe. Two loads of the same files leave the same row counts. Jobs since 2026-11-09 are backfilled, including ones that predate the ledger. | Must-have |
| R6 | The page and the API stay on 127.0.0.1. Nothing in this system makes a network call. | Must-have |
| R7 | The page shows jobs, Claude spend, checker pass rate, gate blocks, missed or failed runs, corrections, the schedule, approvals, evals and board health, each with its source and the data-through time. | Must-have |
| R8 | Added time in the gate stays under 20 ms a call. | Must-have |
| R9 | Writers are the existing scripts. No Grok, Keychain, or launchd change from the agent. The installer writes the refresh plist. Cassidy loads it. | Must-have |
| R10 | Hosted deploy, Amplify, a replica, or a sign-in wall. | Out |

## Shapes

**A. Read the folders on every request.** The API walks `outbox/`, transcripts and logs live. No ledger, so a gate block that already happened is still invisible, and the page waits on disk every time.

**B. Writers open SQLite.** One file, easy queries, but a locked or corrupt database sits on the gate's path. That breaks R2 and R3.

**C. Append-only JSONL, a loader, then SQLite, then a local page.** Writers append a line and move on. The loader is the only database writer. The page reads the last loaded database and refreshes it when the last load is older than 60 seconds.

The build brief already fixed Shape C (the ledger, `cos.db`, and the local UI). It was not re-asked. The brief says to stop for network, a gate-decision change, launchd, the Keychain, a push, or a third failed attempt. Shape choice is not in that list.

### Fit, Shape C

|  | C |
|---|---|
| R1 | yes, one local page |
| R2 | yes, best-effort append, gate unchanged |
| R3 | yes |
| R4 | yes, redact at the append and again in the loader |
| R5 | yes, upsert by the keys below, backfill from files |
| R6 | yes, bind 127.0.0.1, open the database `mode=ro` |
| R7 | yes |
| R8 | yes, one `date`, one `sha1sum`, one `jq`, no extra fork on the common path |
| R9 | yes |
| R10 | stays out |

## Chosen shape

Shape C.

| Part | Choice |
|---|---|
| Raw record | `~/cos/state/ledger/<stream>.jsonl`, one compact JSON object per line, one `printf` so a line under 4,000 bytes appends atomically |
| Database | `~/cos/state/cos.db`, WAL, `busy_timeout` 5000. Writers never open it |
| Page | Vite + React, served with the API by `server.py` on `127.0.0.1:8787` |
| Freshness | The loader runs if the last load is older than 60 seconds. The chip turns amber after 15 minutes |
| Windows | Today, 7 days, 30 days, ending on the newest local day in the data. The last day is marked partial when it is today |

### Schema notes

Names follow the brief, with these additions:

| Change | Why |
|---|---|
| `jobs.exit_code` instead of `exit` | `exit` is painful in SQL. The API still returns it as `exit`. |
| `jobs.needs_approval_json`, `jobs.verifier_json` | The brief stores the count. The drawer needs the items and the criteria. Both are redacted. |
| `jobs.has_codex` | Codex is not a job engine. It is a review inside a build. The spend chart needs a count, and Codex reports no dollars. |
| `pauses` | The brief logs a `pauses` stream and the schema had nowhere to put it. The schedule grid reads it. |
| `loads.counts` as one JSON object | One column stays correct when a table is added. A column per table would drift. |
| Ledger values are strings | `jq --arg` escapes every value. The loader casts numbers. |
| Failed async `summary` | The last 1,500 bytes of `async.log`, redacted, when the pid is dead and there is no receipt. |

### Bot

| Job id | Bot |
|---|---|
| `followups-*` | OPS |
| `pulse-*`, `capture-*`, `reconcile-*`, `week-*` | STEWARD |
| `opportunity-*` | BUILDER |
| `keeper-*` | KEEPER |
| `w` + 8 hex, `eval-*` | EVAL |
| `smoke`, `smoke-q`, `wall-test`, `access-check`, `async-test`, `push-test-*` | SYSTEM |
| anything else | CHIEF |

### What the page cannot see

Grok's own app calls (Gmail, Slack, calendar, the browser) and Grok usage. Those stay in the Grok app.
