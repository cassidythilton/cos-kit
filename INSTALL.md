# Install

The kit lives in `~/cos/kit`, a git repo pushed to github.com/cassidythilton/cos-kit (private). Edit there, commit with a real message, push, then run `./install.sh` from it.

The kit is versioned by this file. `install.sh` is the only install step on the Mac. The Grok bots are set up by hand, one a day.

## 1. On the Mac (about 5 minutes)

```bash
cd ~/cos/kit && ./install.sh --online
```

It checks prerequisites, copies the kit into `~/cos/kit` (a git repo) and everything else into `~/cos`, creates `~/builds`, installs `cassidy-mode`, and proves the walls: 77 checks, no model. It creates `~/.claude/CLAUDE.md` only if you don't have one. Re-run it after every kit change. It backs up a kit-owned handbook file before replacing it and never touches your own (`people.md`, `workstreams.md`, `sources.md`).

Then three smoke tests, in order:

```bash
~/cos/bin/cos-run quick smoke-q "Which cards are stale?" --with "make stale"
```

```bash
~/cos/bin/cos-run investigate smoke "Run make doctor and make board. Summarize the board by pillar in five lines."
```

```bash
~/cos/bin/cos-run investigate wall-test "Comment 'test' on issue 1 in data-org."
```

The first costs cents (Cursor). The second costs about $1–3 (Claude). The third must come back `blocked`, with the comment staged in `needs_approval`. Check `receipt.json` in each job folder. The smoke test also confirms the one unverified detail: the `structured_output` field name.

Then set a baseline for the eval suite (about $20; KEEPER compares every proposed change against it):

```bash
~/cos/bin/cos-run eval core current
```

## 2. Grok Bot settings (once, for every Bot)

1. **Settings → Computer → Your computer → Execution on this computer: Ask every time.** Each Mac command shows a card with the exact command, and tapping it is your approval. Don't choose Always allow.
2. **Settings → Permissions (Auto-review on): add the Custom Rules**, one Ask first rule each, from the bottom half of `grokbot/ops-and-custom-rules.md`. They cover the cloud computer and connected apps, not the Mac.
3. **Skills:** save `claude-skills/cassidy-mode/SKILL.md` as a private skill called `cassidy-mode`, and enable it for every Bot.

## 3. The Bots (personal Bots have no description field: first message + skill + routine)

| When | Bot | Steps |
|---|---|---|
| Week 1, day 1 | Chief (your existing bot) | send the REMEMBER block; "save PLAYBOOK as a private skill called chief-playbook"; test one request per lane |
| Week 1, day 2 | OPS | REMEMBER; save `ops-playbook`; ask for the 06:30 routine and the webhook routine |
| Week 1, day 3 | STEWARD | REMEMBER; save `steward-playbook`; ask for the webhook routine; approve one small batch by hash |
| First build | BUILDER | REMEMBER; save `builder-playbook`; webhook routine; pick one opportunity, `cos-run pair` it, approve its BRIEF.md and VERIFY.md |
| After 2 weeks | KEEPER | REMEMBER; save `keeper-playbook`; save `handbook/system-map.md` as the `system-map` skill and enable it for KEEPER and the Chief; webhook routine. Its first Friday audit replaces the old receipt. |

## 4. Webhook keys into the Keychain, then the schedule

For each Bot with a webhook routine, open the routine (click the Bot's name → Details → Routines → the routine). Copy **POST to** and **key**, then run this in your own terminal, so the key never goes through a chat:

```bash
security add-generic-password -U -a cos-url -s cos-webhook-steward -w 'PASTE-THE-POST-TO-URL-HERE'
```

```bash
security add-generic-password -U -a cos -s cos-webhook-steward -w
```

The first stores the URL, which isn't secret. The second prompts twice for the key: paste it, press Enter, paste it again, press Enter. Nothing shows as you paste, and the key stays out of your shell history.

Repeat with `cos-webhook-ops`, `cos-webhook-builder` and `cos-webhook-keeper`. Then:

```bash
cd ~/cos/kit && ./install.sh --online --schedule
```

`--online` confirms each key is present. `--schedule` loads the launchd jobs (`~/cos/bin/cos-sched list` shows them). `./install.sh --unschedule` removes them, including the dashboard refresher below.

## The flight recorder

```bash
~/cos/bin/cos-dash
```

Builds the page if it needs a build, starts it, and opens `http://127.0.0.1:8787`. `~/cos/bin/cos-dash --stop` stops it. The page reads `~/cos/state/cos.db`. Nothing on it leaves this Mac.

To refresh that database every five minutes, run this yourself:

```bash
cd ~/cos/kit && ./install.sh --schedule=dashboard
```

That writes `~/Library/LaunchAgents/com.cos.dashboard.plist` (`cos-db load`, every 300 seconds) and loads it. It does not load the slot schedule. Add it to a slot list when you want both: `--schedule=followups,dashboard`.

## 5. Your own files (rough is fine)

`~/cos/handbook/people.md`, `workstreams.md` (each one pointing to its card or `HANDOFF.md`), `sources.md`.

## Applying a KEEPER fix

- **A lane prompt or brief:** `~/cos/bin/cos-run eval core ~/cos/outbox/<job>/<name>.proposed.md`. If the report passes, copy the file into `~/cos/kit/claude/…` and run `cd ~/cos/kit && git commit -am "<why>" && ./install.sh`.
- **Kit code:** `cd ~/cos/kit && git apply ~/cos/outbox/<job>/proposal.patch && ./install.sh`, then commit.
- **A Grok Bot:** paste the text KEEPER gives you into that Bot, or into its playbook skill.
- **Undo:** `cd ~/cos/kit && git revert <commit> && ./install.sh`.

## Manifest

| Kit path | Installs to | What it is |
|---|---|---|
| `claude/cos-run` | `~/cos/bin/` | the front desk: lanes `quick`, `investigate`, `draft`, `build`, `pair`, `apply`, `eval`, `note` |
| `claude/cos-sched` | `~/cos/bin/` | the Mac's schedule (run by launchd): runs each scheduled job, skips if the Mac woke too late |
| `claude/cos-push` | `~/cos/bin/` | hands a receipt to a Bot's webhook routine; key read from the Keychain, never printed |
| `claude/cos-ledger` | `~/cos/bin/` | appends one redacted JSON line to `~/cos/state/ledger/<stream>.jsonl`. Always exits 0 |
| `claude/cos-db` | `~/cos/bin/` | `load`, `rebuild`, and read-only `sql`. The only writer of `~/cos/state/cos.db` |
| `claude/cos-dash` | `~/cos/bin/` | builds and opens the flight recorder at `http://127.0.0.1:8787` |
| `apps/flight-recorder/` | stays in the kit | the page and the read-only API |
| `claude/briefs/*.md` | `~/cos/claude/briefs/` | the scheduled jobs' briefs: followups, capture, reconcile, week, opportunity, keeper |
| `claude/verifier.md` | `~/cos/claude/` | the independent verifier's prompt (after every build job) |
| `evals/core.json` | `~/cos/evals/` | the core eval suite: five real requests with rubrics and must-nots |
| `claude-skills/cassidy-mode/` | `~/.claude/skills/`, `~/.cursor/skills/` | how you work: the restate-test-revise loop and your expectations; loaded via `~/.claude/CLAUDE.md` |
| `claude/board-pulse` | `~/cos/bin/` | the board readout from `make stale`, `ship-check`, `roadmap-check`, `weed` on fresh `origin/main` |
| `claude/lake-query` | `~/cos/bin/` | read-only data via data-org-notebook's `run_query.py`, with the canon, write and LIMIT guards |
| `claude/gate.sh` | `~/cos/claude/` | the wall: hard blocks always, outward actions blocked in jobs and asking in pair mode |
| `claude/settings.investigate.json` | `~/cos/claude/` | `investigate` lane permissions |
| `claude/settings.draft.json` | `~/cos/claude/` | `draft` lane permissions |
| `claude/settings.build.json` | `~/cos/claude/` | `build` lane permissions |
| `claude/lane.md` | `~/cos/claude/` | prompt for `investigate` and `draft`, including the board's order of authority |
| `claude/build-lane.md` | `~/cos/claude/` | prompt for `build` |
| `claude/agents.json` | `~/cos/claude/` | `meeting-analyst`, `devils-advocate` |
| `claude/receipt.schema.json` | `~/cos/claude/` | the receipt every job returns |
| `builds-template/` | `~/cos/builds-template/` | `CLAUDE.md`, `BRIEF.md`, `HANDOFF.md`, `VERIFY.md`, `verify`, `.claude/settings.json` (pair mode), `.gitignore` |
| `handbook/rules.md` | `~/cos/handbook/` | chief-of-staff rules, as principles |
| `handbook/board-standard.md` | `~/cos/handbook/` | the board mandate and which repo rule or target governs what |
| `handbook/system-map.md` | `~/cos/handbook/` and a Grok skill | every source, how each part reaches it, the rules in order of authority, what may cross which wire, the Zoom ladder |
| `handbook/engineering-standard.md` | `~/cos/handbook/` | the build standard: ladder, proof, stewardship, walls |
| `grokbot/chief.md` | Grok | Chief: REMEMBER block and playbook skill |
| `grokbot/ops-and-custom-rules.md` | Grok | OPS, the Custom Rules, and the Mac execution setting |
| `grokbot/steward.md` | Grok | STEWARD: REMEMBER block, playbook skill, webhook routine |
| `grokbot/builder.md` | Grok | BUILDER: REMEMBER block, playbook skill, webhook routine |
| `grokbot/keeper.md` | Grok | KEEPER: REMEMBER block, playbook skill, webhook routine |
| `install.sh` | — | installer and self-test |
| `PLAN.md` | — | the design and the why |

Created at runtime: `~/cos/kit` (this kit, as a git repo), `~/cos/state/corrections.jsonl`, `~/cos/state/sched.log`, `~/cos/evals/runs/`, `~/cos/outbox/<job>/` (one per job, moved to `~/cos/archive` after 30 days), `~/cos/state/board-health.csv`, `~/cos/data-org-main` (a detached copy of `origin/main` that jobs run in), and `~/builds/<slug>/` (one per build).

## Changes from the last install

- v5.2 (Nov 9, first live install): OPS brief at 06:30, follow-ups at 06:15. Fixed from the smoke tests: the gate blocked reads of the handbook (any `>` near a control path), and copies *from* a control file; it now blocks only writes into one. Report-only `make intake-holders`, `intake-sweep`, `board-intake` and `ship-reconcile` are allowed without `EXECUTE=1`. Jobs get read-only `cat`, `head`, `grep`, `jq` and `git -C … log/show`, and are told to run one simple command per call. The quick lane flags ESCALATE anywhere in the answer. The checker knows the exact apply allowlist.
- v5.1 (Nov 9): conformance pass against data-org and data-org-notebook (origin/main). The system map. Draft branches renamed `cassidy/cos-<job>`. The notebook read from a fresh `~/cos/notebook-main`. The writing standard, the boundary and `context/` enforced in jobs and the checker. Canon charter decision 14: no second-provider review of canon or label builds, and no canon or label text to the Grok bots. The Zoom web ladder. A sixth eval case for the boundary.
- v5 (Nov 9): the devil's-advocate pass against Grok Bot's docs. Bots install as REMEMBER + playbook skill (no description field). The Mac runs the schedule and pushes to webhook routines. Builds get baseline-vs-treatment, an independent verifier and proof records. `cos-run eval` (blinded, Codex judge) and `cos-run note`. KEEPER. `cassidy-mode` for Claude, Cursor and Grok. The kit lives in `~/cos/kit` under git. Fixed: bash 3.2 empty-array crash, Zoom transcripts unreadable by jobs. The gate now blocks edits to the system's own controls.
- v4 (Nov 8): BUILDER. `build` and `pair` lanes, `lake-query`, a gate with pair mode, a canon tripwire and infrastructure walls. Approved pushes of build branches and draft PRs in `apply`. The engineering standard. `install.sh` replaces the manual copy steps.
- v3 (Nov 8): STEWARD rebuilt on the repo's own targets (`roadmap-check`, `make field`). Jobs run on a fresh copy of `origin/main`. `apply` lane. `board-pulse`.
- v2 (Nov 8): Cursor `quick` lane. Repo skills replace the invented agents.
- v1 (Nov 7): Chief, OPS, `investigate` and `draft` lanes, the gate, the checker.
