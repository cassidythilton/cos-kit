# System map

The one place that says where every source lives, how each part of the system reaches it, and which rules govern it. KEEPER reads it every run, and so does any job that needs to find something. When a source moves, a rule changes, or a channel is added, KEEPER proposes the edit here first. Facts that change daily (owners, dates, RAGB, status) are never written here. They are fetched.

Last checked: 2026-11-09 (data-org origin/main 16876d5, data-org-notebook origin/main 9430359).

## 1. Rules, in order of authority

| Rule | Where it lives | Read from |
|---|---|---|
| The live issue body | GitHub, wisecodeai/data-org | `gh issue view` |
| The Makefile and `scripts/dataorg.sh` (they win over skill text) | data-org | `~/cos/data-org-main` |
| data-org operating rules: AGENTS.md, CONTRIBUTING.md (the boundary), `standards/writing.md`, `standards/glossary.md` | data-org | `~/cos/data-org-main` |
| The board system: `docs/2026-10-12-work-system.md`, `docs/2026-10-29-commands-by-cadence.md`, `docs/2026-10-29-board-weeding.md` | data-org | `~/cos/data-org-main` |
| Board maintenance cold start (PR #610, unmerged) | branch `cassidy/375-board-maintenance` | `git show origin/cassidy/375-board-maintenance:<path>` |
| Data stewardship (David, 2026-10-08): canon rows never cross the wire | data-org-notebook AGENTS.md | `~/cos/notebook-main` |
| Notebook house rules: AGENTS.md, HANDOFF.md, README.md, INFORMATION_HIERARCHY.md, `queries/lib/food_eligibility.sql` | data-org-notebook | `~/cos/notebook-main` |
| Canon charter decisions 14 (the airlock) and 28 (no canon or Pantry in the WISEintel MCP) | data-org `docs/research/R002-canon-charter/charter.qmd` | `~/cos/data-org-main` |
| WISEcode AI Data Stewardship Field Guide v1.0 (Tolga, 2026-09-22) | **not found** in either repo or Cassidy's Drive search | open item: ask Tolga or David |
| food-enrichment rules (the lake, The Pantry): AGENTS.md, `make check` | wisecodeai/food-enrichment | a build's `repos/` clone |
| Cassidy's rules: `rules.md`, `board-standard.md`, `engineering-standard.md`, `cassidy-mode` | this kit | `~/cos/handbook`, `~/.claude/skills/cassidy-mode` |
| Grok Bot behavior: apps, routines, skills, approvals, local execution | cursor.com/docs/grok-bot and cursor.com/help/grok-bot | the web |

## 2. Sources

| Source | System of record for | A Mac job reads it | A Grok Bot reads it | Limits |
|---|---|---|---|---|
| Project 1, the Data Org Initiatives board | cards, lanes, RAGB, owners, Targets | `make` targets and `gh` in `~/cos/data-org-main` | through the Chief and cos-run | writes only by an approved `apply` batch |
| Data Roadmap sheet `1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM` | roadmap rows, themes, horizons, targets | Sheets connector, read-only | Google Sheets app, read-only | no edits; paste text with the exact cell |
| GitHub repos: data-org, data-org-notebook, food-enrichment, WISEintelligence | code, DRDs, DADRs, PRs | `gh`, git (fresh origin/main) | GitHub app (failed on data-org before; use the Mac) | no comments, merges or closes without Cassidy's yes |
| Meeting notes and transcripts `~/meetings` | what was said, with timestamps | direct read; the `meeting-analyst` agent and `meeting-reanalysis` skill | through cos-run | a call claim needs the full transcript and a timestamp |
| Zoom transcript exports `~/Documents/Zoom` | calls not in `~/meetings` | direct read | through cos-run | same |
| Zoom web (Cassidy's account) | a call missing from both folders | no | last resort, see section 4 | one named meeting, transcript only, ask first |
| Slack | asks, blockers, commitments, decisions in thread | Slack connector, read and search only | Slack app (posts as Cassidy: drafts only) | channel list in section 3 |
| Zendesk intake | customer-reported issues | `make intake-holders`, `make intake-sweep` (dry run); `#customer-new-issues` | through cos-run | a close notifies the customer: never by an agent |
| Warehouse (app Postgres) and The Pantry (DuckLake) | the data | `lake-query` only (VPN, `<env>-laker` SSO) | never | canon: aggregates and IDs only; read-only always |
| Gmail and Google Calendar | mail, schedule | not used | Gmail and Calendar apps | drafts only; no calendar change without a yes |
| Google Drive and Docs | charters, decks, memos | Drive connector, read-only | Drive app | no edits to others' files |
| Cassidy's Claude and Cursor transcripts | how he works | only a path he names, or the monthly cassidy-mode re-mine of his own projects | no | never glob across other people's or unrelated projects |
| `~/cos/outbox/*/receipt.json` | what every job did, cost, checker and verifier results | direct read | webhook bodies | receipts summarize; read artifacts for detail |
| `~/cos/state/` | corrections, schedule log, board-health trend | direct read | no | team numbers only, never per person in public |
| `~/cos/state/ledger/*.jsonl` | append-only record of jobs, gate blocks and asks, pushes, applies, the schedule, corrections, pauses | direct read | no | commands and paths only; secrets redacted; never file contents or canon values |
| `~/cos/state/cos.db` | the flight recorder: jobs, costs, files touched, commands, gate events, schedule, corrections, evals, board health | `cos-db sql`, read-only | no | built by `cos-db load` from the ledger and the folders; writers never open it |
| `~/cos/evals/` | eval suites and reports | direct read | through KEEPER's report | |
| `~/cos/kit` (git) | the system itself | direct read; changes by Cassidy only | no | the gate blocks agent edits |
| `~/builds/*/HANDOFF.md`, `BRIEF.md`, `VERIFY.md` | each build's state | direct read | through BUILDER | |

## 3. Slack channels

| Use | Channels |
|---|---|
| Read for work signals (capture, opportunities, follow-ups) | `#data-team` (C0BMLSDDNDT), `#the-pantry` (C0CFNFA6UGY), `#garde-manger` (C0C3TL2NSG3, The Pantry datalake), `#canon-charter` (C0CD46EQ57U), `#datasembly-data` (C0BLJ76B6TZ), `#customer-new-issues` (C0C7PPG89UM, the ticket flow), `#ai-at-wisecode` (C0B6AM7HY3D), `#wisecode-ai-alpha` (C0BLN84P4R2) |
| Read only when Cassidy names a thread | `#data-org-water-cooler` (C0C3L96NMD5), `#not-data-org-leads` (C0BMS2QMLGZ), incident channels, `#general` |
| Never read for this system | `#hiring-announcements`, `#hiring-software-developer-and-data-engineer`, any personnel or HR channel, DMs he hasn't pointed to, `#owls` (individual recognition), `#random`, `#socialmedia` |

Channels that appear in his work but not in his membership list (for example the infra channel with Steve, and Nicholas's pipeline channel) are read only through a thread link he gives.

## 4. Getting a call transcript: the escalation ladder

1. `~/meetings/<date>-<slug>.md`: the note and its transcript.
2. `~/Documents/Zoom/<meeting name>.txt`.
3. Ask Cassidy whether a transcript exists, and where.
4. **Last resort: Zoom web.** Only when steps 1 to 3 fail, only for one named meeting, and only after Cassidy says yes to that meeting. The Chief opens zoom.us in the Bots' browser, signed in as Cassidy (a Vault or 1Password login, or he takes over for single sign-on). It goes to Recordings, finds that meeting's cloud recording, and downloads the transcript file only (`.vtt` or `.txt`), never the video or audio. It moves the file to `~/Documents/Zoom/` on the Mac (an approval card), then deletes its copy from the Bots' computer, which every Bot shares. It never changes Zoom settings, shares a recording link, or opens a meeting it wasn't asked for. Then the job that needed it re-runs from step 2.

A Mac job never logs into Zoom. When it needs a missing transcript, it returns status `blocked` with "needs transcript: <meeting, date>", and the Chief offers step 3 or 4.

## 5. What crosses which wire

| From, to | What may go | What never goes |
|---|---|---|
| Lake or warehouse, to Claude on the Mac | rows except canon values; canon aggregates and IDs | canon names, terms, aliases, flag assignments |
| Mac job, to the Grok Bots (receipts, webhooks) | summaries, IDs, counts, card numbers, draft text | canon terms, label text or images, credentials, raw data rows |
| Mac job, to another model provider (Codex review, eval judge) | diffs and receipts of open builds | anything from a canon or label build (canon charter decision 14) |
| Anything, to data-org or a team channel | what the writing standard and the boundary allow | personnel, compensation, individual performance, verbatim executive quotes, RAGB values in files, CDO ADR contents |
| Anything, to a shared link | nothing | AI conversation links with WISEcode information; public Bot share links |

## 6. Who's who

`~/cos/handbook/people.md` (Cassidy's file) holds names, roles and what each person owns, as factual RACI. Never performance, compensation or personnel notes.
