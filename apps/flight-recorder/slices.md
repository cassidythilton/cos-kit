# Slices

Shape C from `shaping.md`. Each slice ends in something Cassidy can run.

## Breadboard

```
+------------------------------------------------------------------+
| Flight recorder          [ Today | 7 days | 30 days ]   freshness |
+------------------------------------------------------------------+
| jobs | Claude spend | checker pass | blocks | missed | corrections |
+------------------------------------------------------------------+
| Spend by day: stacked dollars by lane, run counts by engine       |
| table of the same numbers                                          |
+------------------------------------------------------------------+
| Jobs table → drawer: brief, receipt, checker, files, commands,     |
|   gate, pushes, applies, folder path                               |
+------------------------------------------------------------------+
| Walls: blocks and asks, top rules, the commands                    |
| Approvals: sha256, lines, result, job                              |
| Schedule: slot × day                                               |
| Learning: corrections, latest eval, board-health trend             |
+------------------------------------------------------------------+
| Footer: what this cannot see                                       |
+------------------------------------------------------------------+
```

Affordances: the window picker, three filter pickers, a text search, a row that opens the drawer, Show table on each chart, a source line on every section, copy the job folder path. No writes.

## Slices

| Slice | Demonstrable | Status |
|---|---|---|
| 1. Recorder | `cos-ledger` appends a redacted line and exits 0 even when the folder is not writable. `cos-run`, `gate.sh`, `cos-push`, `cos-sched` call it without changing decisions. | next |
| 2. Database | `cos-db load` on a temp HOME builds every table. A second load leaves the same counts. Real `~/cos/outbox` jobs since 2026-11-09 backfill, with files and commands from transcripts. | after 1 |
| 3. API | `http://127.0.0.1:8787` serves JSON. It binds only that address, refuses POST, and starts a load when the last one is older than 60 seconds without making the request wait. | after 2 |
| 4. Page | One page, light tokens, custom pickers, source and freshness on every section, empty states. Screenshot review. | after 3 |
| 5. Install and docs | `./install.sh` passes the old checks and the new ones. Gate added time under 20 ms. KEEPER's brief, the system map, README, INSTALL. | after 4 |

## Out of these slices

Amplify, a replica, sign-in, Grok or Keychain edits, loading launchd. The plist generator is in `install.sh`. Cassidy runs it.
