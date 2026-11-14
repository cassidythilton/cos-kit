# Install

The kit lives in `~/cos/kit`, a git repo pushed to github.com/cassidythilton/cos-kit (private). Edit there, commit with a real message, push, then run `./install.sh` from it.

The kit is versioned by this file. `install.sh` is the only install step on the Mac. The Grok bots are set up by hand, one a day.

## 1. On the Mac (about 5 minutes)

```bash
cd ~/cos/kit && ./install.sh --online
```

It checks prerequisites, copies the kit into `~/cos/kit` (a git repo) and everything else into `~/cos`, creates `~/builds`, installs `cassidy-mode`, and proves the walls: 107 checks, no model. It creates `~/.claude/CLAUDE.md` only if you don't have one. Re-run it after every kit change. It backs up a kit-owned handbook file before replacing it and never touches your own (`people.md`, `workstreams.md`, `sources.md`).

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

Do these in order, so the rules are in place before the per-command card goes away.

1. **Settings → Permissions** (Auto-review on). **Always Ask**, one rule each: send an email or Slack message or post anywhere · create, change or delete a calendar event or respond to an invitation · edit a Google Sheet, Doc or Slide that isn't a new draft · comment on, approve, merge or close anything on GitHub, or edit a GitHub Project · buy anything or enter payment details · sign in to Zoom or download anything from Zoom · open more than 5 web pages for one task, or start a task expected to take more than 15 minutes · retry a step that already failed twice · run any command on my Mac that isn't ~/cos/bin/cos-run · run ~/cos/bin/cos-run with the draft, build, apply or eval lane.
2. **Settings → Permissions → Allow without Asking:** run ~/cos/bin/cos-run with the quick, investigate, receipt, note or pause lane. Leave the Plugin allowlist empty.
3. **Settings → Computer → Execution on this computer: Always allow.** Auto-review still checks every command against the rules above.
4. Save `claude-skills/cassidy-mode/SKILL.md` as the `cassidy-mode` skill, the voice skill as `cassidy-voice` (with `references/samples.md`), and `handbook/system-map.md` as `system-map`. Skills are shared by every Bot.
5. Never press **Always allow** on a `cos-run apply` card. Each batch needs its own yes for its own sha256.

## 3. The Bots (personal Bots have no description field: first message + skill + routine)

| When | Bot | Steps |
|---|---|---|
| Week 1, day 1 | Chief (your existing bot) | send the REMEMBER block; "save PLAYBOOK as a skill called chief-playbook"; create its results webhook routine; test one request per lane |
| Week 1, day 2 | OPS | REMEMBER; save `ops-playbook`; ask for the 06:30 routine and the webhook routine |
| Week 1, day 3 | STEWARD | REMEMBER; save `steward-playbook`; ask for the webhook routine; approve one small batch by hash |
| First build | BUILDER | REMEMBER; save `builder-playbook`; webhook routine; pick one opportunity; its first `cos-run build --slug <slug>` makes the workspace; approve its BRIEF.md and VERIFY.md |
| After 2 weeks | KEEPER | REMEMBER; save `keeper-playbook`; save `handbook/system-map.md` as the `system-map` skill and enable it for KEEPER and the Chief; webhook routine. Its first Friday audit replaces the old receipt. |

Every specialist (OPS, STEWARD, BUILDER, KEEPER) also gets the one-door rule as a lasting rule. It's in each file's REMEMBER block: the Chief is the only Bot that runs commands or writes anywhere, so every approval happens in the Chief's chat.

## 4. Webhook keys into the Keychain, then the schedule

For each Bot with a webhook routine, open the routine (click the Bot's name → Details → Routines → the routine). Copy **POST to** and **key**, then run this in your own terminal, so the key never goes through a chat:

```bash
security add-generic-password -U -a cos-url -s cos-webhook-steward -w 'PASTE-THE-POST-TO-URL-HERE'
```

```bash
security add-generic-password -U -a cos -s cos-webhook-steward -w
```

The first stores the URL, which isn't secret. The second prompts twice for the key: paste it, press Enter, paste it again, press Enter. Nothing shows as you paste, and the key stays out of your shell history.

Repeat with `cos-webhook-ops`, `cos-webhook-builder`, `cos-webhook-keeper` and `cos-webhook-chief` (the Chief's results webhook: finished `--async` jobs report there). Then:

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
| `claude/cos-run` | `~/cos/bin/` | the front desk: every lane (`cos-run <lane> --help`) |
| `evals/core.json` | `~/cos/evals/` | the core eval suite: five real requests with rubrics and must-nots |
| `claude/cos-gh` | `~/cos/bin/` | tier-0 GitHub writes (`cos-run gh`), ledgered in `~/cos/state/ledger/tier_zero.jsonl` with their undo |
| `claude/cursor-lake-hook`, `claude/lake/cli.json` | `~/cos/claude/` | the lake lane's walls: Cursor's preToolUse hook (runs the gate) and its permission config |
| `claude/cos-sched` | `~/cos/bin/` | the Mac's schedule (run by launchd): runs each scheduled job, skips if the Mac woke too late |
| `claude/cos-push` | `~/cos/bin/` | hands a receipt to a Bot's webhook routine; key read from the Keychain, never printed |
| `claude/cos-ledger` | `~/cos/bin/` | appends one redacted JSON line to `~/cos/state/ledger/<stream>.jsonl`. Always exits 0 |
| `claude/cos-db` | `~/cos/bin/` | `load`, `rebuild`, and read-only `sql`. The only writer of `~/cos/state/cos.db` |
| `claude/cos-dash` | `~/cos/bin/` | builds and opens the flight recorder at `http://127.0.0.1:8787` |
| `apps/flight-recorder/` | stays in the kit | the page and the read-only API |
| `claude/briefs/*.md` | `~/cos/claude/briefs/` | the scheduled jobs' briefs: followups, capture, reconcile, week, opportunity, keeper |
| `claude/verifier.md` | `~/cos/claude/` | the independent verifier's prompt (after every build job) |
| `claude-skills/cassidy-mode/` | `~/.claude/skills/`, `~/.cursor/skills/` | how you work: the restate-test-revise loop and your expectations; loaded via `~/.claude/CLAUDE.md` |
| `claude/board-pulse` | `~/cos/bin/` | the board readout from `make stale`, `ship-check`, `roadmap-check`, `weed` on fresh `origin/main` |
| `claude/lake-query` | `~/cos/bin/` | read-only data via data-org-notebook's `run_query.py`, with the canon, write and LIMIT guards; used only by the lake lane |
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

- v6 (Nov 9, evening): what the first live day taught.
  - **Off his plate:** `cos-obligations` owns review requests, finished cards and unanswered mentions until GitHub shows them closed. Standing approvals for comment-only PR reviews and for closing a finished card (no unchecked box, a day's notice, a veto). RSVPs and card logs stay one tap. `--schedule=obligations`.
  - **One door:** only the Chief runs commands or writes. A loophole ("never on a schedule") let STEWARD try raw GitHub mutations from its own chat.
  - **Async:** long lanes take `--async`, `cos-run receipt` reads a result, and finished jobs push to the Chief's results webhook. The Chief had re-asked one job about ten times.
  - **The flight recorder:** an append-only ledger, `~/cos/state/cos.db`, and a dark-console page at http://127.0.0.1:8787. `--schedule=dashboard` refreshes it every five minutes.
  - **Permissions:** read-only `cos-run` lanes run without a card. Everything else asks.
  - **Fixed:** scheduled jobs couldn't find `claude` under launchd's bare PATH. A job that never ran is redrafted, not handed to Cassidy. Dry runs no longer log skips. Review drafts carry one evidence entry per finding and lint in the allowed form. The installer checks Python scripts as Python.
  - 107 install checks.
- v5.2 (Nov 9, first live install): OPS brief at 06:30, follow-ups at 06:15. Fixed from the smoke tests: the gate blocked reads of the handbook (any `>` near a control path), and copies *from* a control file; it now blocks only writes into one. Report-only `make intake-holders`, `intake-sweep`, `board-intake` and `ship-reconcile` are allowed without `EXECUTE=1`. Jobs get read-only `cat`, `head`, `grep`, `jq` and `git -C … log/show`, and are told to run one simple command per call. The quick lane flags ESCALATE anywhere in the answer. The checker knows the exact apply allowlist.
- v5.1 (Nov 9): conformance pass against data-org and data-org-notebook (origin/main). The system map. Draft branches renamed `cassidy/cos-<job>`. The notebook read from a fresh `~/cos/notebook-main`. The writing standard, the boundary and `context/` enforced in jobs and the checker. Canon charter decision 14: no second-provider review of canon or label builds, and no canon or label text to the Grok bots. The Zoom web ladder. A sixth eval case for the boundary.
- v5 (Nov 9): the devil's-advocate pass against Grok Bot's docs. Bots install as REMEMBER + playbook skill (no description field). The Mac runs the schedule and pushes to webhook routines. Builds get baseline-vs-treatment, an independent verifier and proof records. `cos-run eval` (blinded, Codex judge) and `cos-run note`. KEEPER. `cassidy-mode` for Claude, Cursor and Grok. The kit lives in `~/cos/kit` under git. Fixed: bash 3.2 empty-array crash, Zoom transcripts unreadable by jobs. The gate now blocks edits to the system's own controls.
- v4 (Nov 8): BUILDER. `build` and `pair` lanes, `lake-query`, a gate with pair mode, a canon tripwire and infrastructure walls. Approved pushes of build branches and draft PRs in `apply`. The engineering standard. `install.sh` replaces the manual copy steps.
- v3 (Nov 8): STEWARD rebuilt on the repo's own targets (`roadmap-check`, `make field`). Jobs run on a fresh copy of `origin/main`. `apply` lane. `board-pulse`.
- v2 (Nov 8): Cursor `quick` lane. Repo skills replace the invented agents.
- v1 (Nov 7): Chief, OPS, `investigate` and `draft` lanes, the gate, the checker.

## Documents access for scheduled jobs (one step, once)

Scheduled jobs start from launchd, and macOS gives a launchd job only the access of the program launchd starts.
Every job now starts through one small program, `~/cos/bin/cos-launch`, so one grant covers them all (and nothing
else on the Mac, unlike granting `/bin/zsh`).

1. System Settings → Privacy & Security → Full Disk Access → **+**.
2. Press ⌘⇧G, paste `~/cos/bin/cos-launch`, choose it, and turn it on.
3. Run `cd ~/cos/kit && ./install.sh --schedule`. It rewrites the schedule to use cos-launch and runs a one-time
   launchd check: "a launchd job can read ~/Documents" must pass.

macOS only lets you add a command-line program under Full Disk Access, which covers more than Documents. That was
Cassidy's call (2026-11-12): any agent may use Documents. cos-launch runs only programs in `~/cos/bin`. If
`claude/cos-launch.c` ever changes, the installer rebuilds it and you grant it again.
