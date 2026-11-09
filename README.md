# cos-kit

> **Five bots, one Mac, nothing unapproved.** Cassidy's chief-of-staff system. Five Grok bots split the work: a Chief he talks to, and four specialists for his clock, the board, engineering builds and the bots themselves. His Mac does everything that touches the repos, the board, transcripts or data, through one front desk and its own clock. Nothing leaves the team, merges, or changes shared state without his yes on that exact action.

![version](https://img.shields.io/badge/version-5.2-2f55c8?style=flat-square)
![status](https://img.shields.io/badge/status-installed_2026--11--09-56E39F?style=flat-square)
![bots](https://img.shields.io/badge/bots-Grok_Bot_·_5-15181e?style=flat-square)
![engines](https://img.shields.io/badge/engines-Claude_Code_·_Cursor_Agent-D97757?style=flat-square&logo=anthropic&logoColor=white)
![mac](https://img.shields.io/badge/Mac-launchd_·_bash_·_gh-3d4452?style=flat-square&logo=apple&logoColor=white)
![checks](https://img.shields.io/badge/install_checks-103%2F103-56E39F?style=flat-square)
![license](https://img.shields.io/badge/license-private-5B6C5D?style=flat-square)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/architecture-dark.svg">
    <img src="docs/images/architecture-light.svg" alt="How the parts connect" width="900">
  </picture>
  <br>
  <em>How the parts connect. Cassidy asks the Chief. The Chief hands work to the four specialists, and runs <code>cos-run</code> on the Mac only after his tap. The Mac's clock runs the scheduled jobs and pushes each receipt to the bot that owns it.</em>
</p>

---

## Table of Contents

1. [What Problem Does This Solve?](#what-problem-does-this-solve)
2. [The Bots](#the-bots)
3. [Who Does What](#who-does-what)
4. [The Mac](#the-mac)
5. [The Flight Recorder](#the-flight-recorder)
6. [The Week](#the-week)
7. [How a Write Gets Approved](#how-a-write-gets-approved)
8. [The Walls](#the-walls)
9. [How It Learns](#how-it-learns)
10. [Rules That Come First](#rules-that-come-first)
11. [Install and Change](#install-and-change)
12. [Project Structure](#project-structure)

---

## What Problem Does This Solve?

Cassidy enforces the data org's board and roadmap, owns his own builds, and runs a short-handed team's operating rhythm. A single assistant chat can't hold all of that. It forgets, it acts on stale facts, and it has access it shouldn't use.

This kit splits the work by owner and puts walls where mistakes are expensive:

| Need | How the kit meets it |
| --- | --- |
| ![one](https://img.shields.io/badge/One_contact-2f55c8?style=flat-square) | Cassidy talks only to the Chief, which restates each ask as a brief and routes it |
| ![fresh](https://img.shields.io/badge/Fresh_facts-0f8a7e?style=flat-square) | Owners, dates, RAGB and status are fetched from their system of record every time, never remembered |
| ![board](https://img.shields.io/badge/Board_kept_true-b26a00?style=flat-square) | STEWARD runs the repo's own `make` targets daily and stages writes for his yes |
| ![proof](https://img.shields.io/badge/Proof,_not_promises-8a3fb5?style=flat-square) | Builds are verified before and after, by an independent verifier and a second model |
| ![learn](https://img.shields.io/badge/Gets_better-c0392b?style=flat-square) | KEEPER turns repeated mistakes into checks and tested fixes |

---

## The Bots

| Bot | Job | Runs | Never | Status |
| --- | --- | --- | --- | --- |
| ![chief](https://img.shields.io/badge/CHIEF-2f55c8?style=flat-square) | The only bot Cassidy talks to. Restates each ask as a brief, picks the lane, gets his yes. | When he messages it | Sends, merges, or changes a sheet or calendar without his yes | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![ops](https://img.shields.io/badge/OPS-0f8a7e?style=flat-square) | The morning brief, with follow-up drafts from yesterday's calls | Weekdays 06:30 | Sends anything, or runs commands on the Mac | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![steward](https://img.shields.io/badge/STEWARD-b26a00?style=flat-square) | The board (Project 1) and the Data Roadmap sheet, run on the repo's own targets | Daily, Tue/Thu, Fri | Writes on another owner's card, runs `EXECUTE=1`, edits the sheet | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![builder](https://img.shields.io/badge/BUILDER-8a3fb5?style=flat-square) | Turns board work that needs engineering into proven prototypes and draft PRs for their owners | Mondays 08:30 | Builds off the board, merges, deploys, touches production | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![keeper](https://img.shields.io/badge/KEEPER-c0392b?style=flat-square) | Audits the other bots weekly and proposes tested fixes | Fridays 13:00 | Changes a bot, skill, routine or this kit itself | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |

Each bot has a **REMEMBER** block (its lasting rules) and a **PLAYBOOK** saved as a shared Grok skill. Sources: [grokbot/](grokbot/).

---

## Who Does What

**Grok** handles conversation, mail, Slack, calendar and routing. **Cursor Agent** answers one-command lookups for cents. **Claude Code** does anything multi-step on the repos, transcripts or data, plus every checker and verifier. **Codex** reviews Claude's builds and judges its evals, so a different model family checks the work.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/workflow-dark.svg">
    <img src="docs/images/workflow-light.svg" alt="Who does what: nine requests traced to the bot, lane and engine, and the Chief's decision rule" width="1000">
  </picture>
  <br>
  <em>Nine real requests, from the bot that takes each one to the engine that does the work, and the rule the Chief uses to pick a lane. Regenerate with <code>python3 docs/src/workflow.py</code>.</em>
</p>

| Engine | Used for | Why that one |
| --- | --- | --- |
| ![grok](https://img.shields.io/badge/Grok-15181e?style=flat-square) | Chat, Gmail and Slack drafts, calendar, routing, routines, the Bots' browser | It holds the connected apps and the conversation. It never touches the Mac unattended. |
| ![cursor](https://img.shields.io/badge/Cursor_Agent-3d4452?style=flat-square) | `quick`: one read-only command, summarized | Cheapest. The script runs the command, and the model only reads the output. |
| ![claude](https://img.shields.io/badge/Claude_Code-c96442?style=flat-square&logo=anthropic&logoColor=white) | `investigate`, `draft`, `build`, the checker, the verifier | Multi-step work with the repo's skills, under the gate, with a receipt |
| ![codex](https://img.shields.io/badge/Codex-10a37f?style=flat-square) | Second-opinion review of builds, the blind eval judge | A different model family catches what Claude misses. Skipped for canon or label builds (decision 14). |

---

## The Mac

`cos-run` is the one way a bot reaches the Mac. Each run shows Cassidy an approval card with the exact command. Every job writes only into `~/cos/outbox/<job>/` and returns a `receipt.json`, and a separate checker reviews it before anyone calls the work done.

| Lane | Does | Engine | Cost |
| --- | --- | --- | --- |
| ![quick](https://img.shields.io/badge/quick-3d4452?style=flat-square) | Answers from one read-only command | Cursor Agent | cents |
| ![investigate](https://img.shields.io/badge/investigate-3d4452?style=flat-square) | Digs in and changes nothing | Claude Code | about $0.30 to $3 |
| ![draft](https://img.shields.io/badge/draft-3d4452?style=flat-square) | Prepares a doc or repo change on a `cassidy/cos-<job>` branch, never pushed | Claude Code | up to $12 |
| ![build](https://img.shields.io/badge/build-8a3fb5?style=flat-square) | One build slice, then before-and-after checks, an independent verifier and a second model's review | Claude Code · Codex | up to $20, plus about $6 |
| ![pair](https://img.shields.io/badge/pair-8a3fb5?style=flat-square) | Scaffolds a build workspace Cassidy drives in Cursor | none | free |
| ![apply](https://img.shields.io/badge/apply-eab308?style=flat-square) | Runs a write batch he approved by its sha256, once | none | free |
| ![eval](https://img.shields.io/badge/eval-c0392b?style=flat-square) | Tests a prompt change blind on the [core suite](evals/core.json) | Claude Code, judged by Codex | about $4 |
| ![note](https://img.shields.io/badge/note-c0392b?style=flat-square) | Records a correction for KEEPER | none | free |
| ![pause](https://img.shields.io/badge/pause-5B6C5D?style=flat-square) | Holds a scheduled slot for N days, `0` resumes | none | free |

Source: [claude/cos-run](claude/cos-run).

---

## The Flight Recorder

Every action on the Mac appends one line to `~/cos/state/ledger/`. `cos-db load` builds `~/cos/state/cos.db` from that ledger and the folders that already exist. The page at `http://127.0.0.1:8787` reads the database and nothing else. It never leaves this Mac.

| What you see | Where it comes from |
| --- | --- |
| ![jobs](https://img.shields.io/badge/Jobs_and_cost-141416?style=flat-square) | `jobs`, from the ledger plus each receipt |
| ![walls](https://img.shields.io/badge/Gate_blocks-c0392b?style=flat-square) | `gate_events`. Allows are not recorded |
| ![schedule](https://img.shields.io/badge/Schedule-0f8a7e?style=flat-square) | `schedule`, including runs the Mac slept through |
| ![learn](https://img.shields.io/badge/Corrections_and_evals-b26a00?style=flat-square) | `corrections`, `evals`, `board_health` |

<p align="center">
  <img src="docs/images/flight-recorder.png" alt="The flight recorder: jobs, spend, and what got blocked" width="900">
  <br>
  <em>Open it with <code>cos-dash</code>. Cursor and Codex report no dollars, so they show up as run counts. Grok's own app calls stay in the Grok app.</em>
</p>

Source: [claude/cos-ledger](claude/cos-ledger), [claude/cos-db](claude/cos-db), [apps/flight-recorder](apps/flight-recorder).

---

## The Week

`cos-sched` runs each job on the Mac under launchd and pushes the receipt to the owning bot's webhook routine. A job that finds nothing new sends nothing. A job the Mac slept through is reported as missed, never replayed with old data.

```
            MON          TUE          WED          THU          FRI
 06:15   followups ─────────────────────────────────────────────────▶ OPS
 06:30   brief     ─────────────────────────────────────────────────  OPS
 08:10   pulse     ─────────────────────────────────────────────────▶ STEWARD
 08:30   opportunity                                                  ▶ BUILDER
 10:00                reconcile                 reconcile             ▶ STEWARD
 10:00                                                       week     ▶ STEWARD
 13:00                                                       keeper   ▶ KEEPER
 16:00   capture   ─────────────────────────────────────────────────▶ STEWARD
```

| Slot | When | Goes to | What Cassidy sees |
| --- | --- | --- | --- |
| ![followups](https://img.shields.io/badge/followups-0f8a7e?style=flat-square) | Weekdays 06:15 | OPS | Drafts inside the 06:30 brief |
| ![pulse](https://img.shields.io/badge/pulse-b26a00?style=flat-square) | Weekdays 08:10 | STEWARD | Three lines and owner nudge drafts, before the ops meeting |
| ![capture](https://img.shields.io/badge/capture-b26a00?style=flat-square) | Weekdays 16:00 | STEWARD | A write batch for his cards, by sha256 |
| ![reconcile](https://img.shields.io/badge/reconcile-b26a00?style=flat-square) | Tue, Thu 10:00 | STEWARD | Drift, which side should move, sheet paste text |
| ![week](https://img.shields.io/badge/week-b26a00?style=flat-square) | Fri 10:00 | STEWARD | The weekly packet for him and Melanie |
| ![opportunity](https://img.shields.io/badge/opportunity-8a3fb5?style=flat-square) | Mon 08:30 | BUILDER | Up to three build ideas, each tied to a card |
| ![keeper](https://img.shields.io/badge/keeper-c0392b?style=flat-square) | Fri 13:00 | KEEPER | A scorecard and up to three fixes |

Sources: [claude/cos-sched](claude/cos-sched), [claude/briefs/](claude/briefs/).

---

## How a Write Gets Approved

Board writes never run inside a job. A job stages them, the receipt fingerprints them, and only the exact file Cassidy approved runs, once.

```
 STEWARD capture             Chief                 Cassidy              Mac
 ───────────────             ─────                 ───────              ───
 stage apply.sh   ──────▶   show batch    ──────▶  "yes to             cos-run apply
 DRY_RUN=1 preview           + sha256               3f9c…e1"  ──────▶  <job> <sha256>
 receipt.batch.sha256                               tap Allow            │
                                                    on the card          ├─ hash matches?   no ─▶ refuse
                                                                         ├─ allowlisted?    no ─▶ refuse
                                                                         ├─ ≤ 40 lines?     no ─▶ refuse
                                                                         └─ run once ─▶ applied.log
                                                                                        Chief re-reads each card
```

Allowed lines: the repo's own write targets (`make ragb`, `field`, `set-pillar`, `complete`, `promote`, `board-add`, `ship-link`, `context-request`), `gh issue comment --body-file`, and for builds a push of a `<name>/<branch>` build branch and `gh pr create --draft`. `EXECUTE=1`, closes, merges and deletes are refused.

---

## The Walls

| Wall | What it stops | Where |
| --- | --- | --- |
| ![cards](https://img.shields.io/badge/Approval_cards-2f55c8?style=flat-square) | Any Mac command Cassidy hasn't seen | Grok: Mac execution set to ask every time |
| ![rules](https://img.shields.io/badge/Custom_Rules-2f55c8?style=flat-square) | Sends, posts, calendar, sheets, GitHub writes, purchases, Zoom sign-in | Grok: Settings, Permissions |
| ![gate](https://img.shields.io/badge/The_gate-c0392b?style=flat-square) | Secrets, production writes, infrastructure, force-push, canon values, `context/` edits, edits to this kit | [claude/gate.sh](claude/gate.sh) |
| ![hash](https://img.shields.io/badge/Approval_by_hash-eab308?style=flat-square) | Any batch that differs from the one approved | [claude/cos-run](claude/cos-run) |
| ![lake](https://img.shields.io/badge/lake--query-0f8a7e?style=flat-square) | Writes, non-aggregate canon reads, unbounded queries | [claude/lake-query](claude/lake-query) |
| ![merge](https://img.shields.io/badge/No_merges-5B6C5D?style=flat-square) | Any agent merging or deploying. The furthest it goes is a draft PR, after his yes. | [handbook/engineering-standard.md](handbook/engineering-standard.md) |

---

## How It Learns

```
 correction ──▶ cos-run note ──▶ corrections.jsonl ──▶ KEEPER (Fri)
                                                          │
                       seen twice? ── no ──▶ stays a one-off
                           │
                          yes
                           ▼
        strongest fix: setup ▶ a check ▶ a skill or prompt edit ▶ memory
                           │
            prompt change? ── yes ──▶ cos-run eval core <proposed>  (blind, judged by Codex)
                           │
                           ▼
            Cassidy approves ──▶ commit in ~/cos/kit ──▶ ./install.sh
```

The baseline eval on 2026-11-09 scored **3.0 of 5** across six real requests, with **0** hard-rule violations. Sources: [evals/core.json](evals/core.json), [claude/briefs/keeper.md](claude/briefs/keeper.md).

---

## Rules That Come First

The team's rules win over this kit. Jobs read them fresh from `origin/main`, never from a working checkout.

| Source | Rule the kit follows |
| --- | --- |
| ![do](https://img.shields.io/badge/data--org-1f5d86?style=flat-square) | AGENTS.md, the writing standard (`make lint-writing`), the CONTRIBUTING boundary, `context/` read-only, `<name>/<topic>` branches, the Makefile over skill text |
| ![nb](https://img.shields.io/badge/data--org--notebook-1f5d86?style=flat-square) | Canon rows never cross the wire, `uv` only, the eligibility denominator, `wt/cc/<slug>` deliverables |
| ![canon](https://img.shields.io/badge/Canon_charter-1f5d86?style=flat-square) | Decision 14: canon terms and label context reach a model only through Data Org tooling. Decision 28: no canon or Pantry in the WISEintel MCP. |
| ![fg](https://img.shields.io/badge/Field_Guide-not_found-eab308?style=flat-square) | WISEcode AI Data Stewardship Field Guide v1.0 (Tolga). Open item. |

The full map of sources, rules and what may cross which wire is [handbook/system-map.md](handbook/system-map.md).

---

## Install and Change

```bash
cd ~/cos/kit && ./install.sh --online
```

`install.sh` checks prerequisites, copies the kit into `~/cos`, installs `cassidy-mode` for Claude and Cursor, and proves the walls with 103 checks. `--schedule` loads the launchd jobs, and `--schedule=<slot,…>` loads only those. Full steps, including the Grok setup and webhook keys, are in [INSTALL.md](INSTALL.md). The design and its reasons are in [PLAN.md](PLAN.md). A one-page overview is [docs/system-overview.html](docs/system-overview.html).

This folder is the only source. A change is an edit here, a commit with its reason, a push, then `./install.sh`. To undo one, revert the commit and reinstall.

---

## Project Structure

```
cos-kit/
├── claude/                  the Mac side
│   ├── cos-run              front desk: quick · investigate · draft · build · pair · apply · eval · note · pause
│   ├── cos-sched            the clock (launchd) · cos-push hands receipts to Grok webhooks
│   ├── cos-ledger           append-only ledger · cos-db loads it into cos.db · cos-dash opens the page
│   ├── gate.sh              the wall in front of every job
│   ├── lake-query           read-only data, canon aggregates only
│   ├── board-pulse          the board readout from the repo's make targets
│   ├── briefs/              the scheduled jobs' briefs
│   └── *.md, *.json         lane prompts, the verifier, settings, the receipt schema
├── grokbot/                 each bot's REMEMBER block and PLAYBOOK, the Custom Rules, the rules skill
├── handbook/                rules, the board standard, the engineering standard, the system map
├── builds-template/         a build workspace: BRIEF.md · VERIFY.md · HANDOFF.md · verify
├── evals/                   the core eval suite
├── claude-skills/           cassidy-mode, how Claude works with Cassidy
├── apps/flight-recorder/    the local page: what ran, what it cost, what got blocked
├── docs/                    the overview page, images, and docs/src/ to regenerate them
├── install.sh               installer and self-test
├── INSTALL.md               step by step
└── PLAN.md                  the design and its reasons
```

Not in this repo: `~/cos/handbook/people.md`, `workstreams.md` and `sources.md`, job receipts, and the webhook keys in the macOS Keychain.
