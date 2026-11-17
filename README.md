# cos-kit

> **Five bots, one Mac, nothing unapproved.** Cassidy's chief-of-staff system. Five Grok bots split the work: a Chief he talks to, and four specialists for his clock, the board, engineering builds and the bots themselves. His Mac does everything that touches the repos, the board, transcripts or data, through one front desk and its own clock. It owns what's waiting on him until it's closed. Nothing leaves the team, merges, or changes shared state without his yes on that exact action, except the two kinds of work he pre-approved.

![version](https://img.shields.io/badge/version-6.0-3d80f1?style=flat-square)
![status](https://img.shields.io/badge/status-installed_2026--11--09-56E39F?style=flat-square)
![bots](https://img.shields.io/badge/bots-Grok_Bot_·_5-15181e?style=flat-square)
![engines](https://img.shields.io/badge/engines-Claude_Code_·_Cursor_Agent-D97757?style=flat-square&logo=anthropic&logoColor=white)
![mac](https://img.shields.io/badge/Mac-launchd_·_bash_·_gh-3d4452?style=flat-square&logo=apple&logoColor=white)
![checks](https://img.shields.io/badge/install_checks-196%2F196-56E39F?style=flat-square)
![updated](https://img.shields.io/badge/updated-2026--11--14-56E39F?style=flat-square)
![license](https://img.shields.io/badge/license-private-5B6C5D?style=flat-square)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/architecture-dark.svg">
    <img src="docs/images/architecture-light.svg" alt="How the parts connect" width="900">
  </picture>
  <br>
  <em>How the parts connect. Cassidy asks the Chief. The Chief hands work to the four specialists, and runs <code>cos-run</code> on the Mac only after his tap. The Mac's clock runs the scheduled jobs and pushes each receipt to the bot that owns it.</em>
</p>

> **New agent?** Start with [HANDOFF.md](HANDOFF.md), the cold-start note: the rules, where everything lives, how to change it safely, and what's open.

---

## Table of Contents

1. [What Problem Does This Solve?](#what-problem-does-this-solve)
2. [The Bots](#the-bots)
3. [Who Does What](#who-does-what)
4. [What's Waiting on Cassidy](#whats-waiting-on-cassidy)
5. [The Mac](#the-mac)
6. [The Flight Recorder](#the-flight-recorder)
7. [The Week](#the-week)
8. [How BUILDER Picks a Build](#how-builder-picks-a-build)
9. [How a Write Gets Approved](#how-a-write-gets-approved)
10. [The Walls](#the-walls)
11. [How It Learns](#how-it-learns)
12. [Rules That Come First](#rules-that-come-first)
13. [Install and Change](#install-and-change)
14. [Project Structure](#project-structure)

---

## What Problem Does This Solve?

Cassidy enforces the data org's board and roadmap, owns his own builds, and runs a short-handed team's operating rhythm. A single assistant chat can't hold all of that. It forgets, it acts on stale facts, and it has access it shouldn't use.

This kit splits the work by owner and puts walls where mistakes are expensive:

| Need | How the kit meets it |
| --- | --- |
| ![one](https://img.shields.io/badge/One_door-3d80f1?style=flat-square) | Cassidy talks only to the Chief. It's the only bot that runs commands or writes anywhere, so every approval happens in one chat |
| ![plate](https://img.shields.io/badge/Off_his_plate-56E39F?style=flat-square) | Review requests, mentions and finished cards are owned until GitHub shows them closed, not just flagged |
| ![fresh](https://img.shields.io/badge/Fresh_facts-e54796?style=flat-square) | Owners, dates, RAGB and status are fetched from their system of record every time, never remembered |
| ![board](https://img.shields.io/badge/Board_kept_true-e66f30?style=flat-square) | STEWARD runs the repo's own `make` targets daily and stages writes for his yes |
| ![proof](https://img.shields.io/badge/Proof,_not_promises-e79738?style=flat-square) | Builds are verified before and after, by an independent verifier and a second model |
| ![learn](https://img.shields.io/badge/Gets_better-757675?style=flat-square) | KEEPER turns repeated mistakes into checks and tested fixes |

---

## The Bots

| Bot | Job | Runs | Never | Status |
| --- | --- | --- | --- | --- |
| ![chief](https://img.shields.io/badge/CHIEF-3d80f1?style=flat-square) | The only bot Cassidy talks to, and the only one that runs commands. Restates each ask as a brief, picks the lane, gets his yes, reports finished jobs. | When he messages it | Sends, merges, or changes a sheet or calendar without his yes | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![ops](https://img.shields.io/badge/OPS-e54796?style=flat-square) | The morning brief, with follow-up drafts from yesterday's calls. Owns the obligations ledger until each item is closed. | Weekdays 06:30, and every two hours | Sends anything, or runs a command | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![steward](https://img.shields.io/badge/STEWARD-e66f30?style=flat-square) | The board (Project 1) and the Data Roadmap sheet, run on the repo's own targets | Daily, Tue/Thu, Fri | Writes on another owner's card, runs `EXECUTE=1`, edits the sheet | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![builder](https://img.shields.io/badge/BUILDER-e79738?style=flat-square) | Turns board work that needs engineering into proven prototypes and draft PRs for their owners | Mondays 08:30 | Builds off the board, merges, deploys, touches production | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |
| ![keeper](https://img.shields.io/badge/KEEPER-757675?style=flat-square) | Audits the other bots weekly and proposes tested fixes | Fridays 13:00 | Changes a bot, skill, routine or this kit itself | ![live](https://img.shields.io/badge/-live-56E39F?style=flat-square) |

Each bot has a **REMEMBER** block (its lasting rules) and a **PLAYBOOK** saved as a shared Grok skill. Sources: [grokbot/](grokbot/).

**The Chief is the only door.** The four specialists never run a command and never write to GitHub, the board, a calendar or a sheet. They may keep Gmail and Slack drafts and their own notes. Everything else goes to the Chief, so approval cards appear in one chat. This rule closed a loophole on 2026-11-09, when STEWARD tried raw GitHub mutations from its own chat and an Ask first rule stopped it.

---

## Who Does What

**Grok** handles conversation, mail, Slack, calendar and routing. **Cursor Agent** answers one-command lookups for cents. **Claude Code** does anything multi-step on the repos, transcripts or data, plus every checker and verifier. **Codex** reviews Claude's builds, judges its evals, and does its own diligence on BUILDER's ideas, so a different model family checks the work.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/workflow-dark.svg">
    <img src="docs/images/workflow-light.svg" alt="Who does what: ten requests traced to the bot, lane and engine, and the Chief's decision rule" width="1000">
  </picture>
  <br>
  <em>Ten real requests, from the bot that takes each one to the engine that does the work, and the rule the Chief uses to pick a lane. Regenerate with <code>python3 docs/src/workflow.py</code>.</em>
</p>

| Engine | Used for | Why that one |
| --- | --- | --- |
| ![grok](https://img.shields.io/badge/Grok-15181e?style=flat-square) | Chat, Gmail and Slack drafts, calendar, routing, routines, the Bots' browser | It holds the connected apps and the conversation. It never touches the Mac unattended. |
| ![cursor](https://img.shields.io/badge/Cursor_Agent-3d4452?style=flat-square) | `quick`: one read-only command, summarized | Cheapest. The script runs the command, and the model only reads the output. |
| ![claude](https://img.shields.io/badge/Claude_Code-c96442?style=flat-square&logo=anthropic&logoColor=white) | `investigate`, `draft`, `build`, the checker, the verifier | Multi-step work with the repo's skills, under the gate, with a receipt |
| ![codex](https://img.shields.io/badge/Codex-10a37f?style=flat-square) | Second-opinion review of builds, the blind eval judge, BUILDER's second diligence pass and cross-examiner | A different model family catches what Claude misses. Skipped for canon or label builds (decision 14). |

---

## What's Waiting on Cassidy

The system's job is to take things off his plate, not to list them. `cos-obligations` runs every two hours on workdays. It collects everything waiting on him, and the item stays owned until its system of record shows it closed.

| Kind | Found by | Closed when |
| --- | --- | --- |
| ![review](https://img.shields.io/badge/Review_request-e54796?style=flat-square) | `gh search prs --review-requested=@me` | GitHub no longer lists him as a requested reviewer |
| ![close](https://img.shields.io/badge/Finished_card-e66f30?style=flat-square) | his open work-items whose linked PRs (`Tile:`, `Refs`) have all merged | the issue is closed by `make complete` |
| ![reply](https://img.shields.io/badge/Unanswered_mention-e54796?style=flat-square) | mentions in the last 14 days with no comment from him after them | he comments after the mention |

**Standing approvals**, chosen by Cassidy on 2026-11-09, in [handbook/standing-approvals.json](handbook/standing-approvals.json) (his copy lives in `~/cos/handbook/`):

| Work | Mode | Safeguards |
| --- | --- | --- |
| ![a](https://img.shields.io/badge/Comment--only_PR_review-56E39F?style=flat-square) | the Mac finishes it, then tells him | a Claude job drafts it with one evidence entry per finding, lint clean, checker pass, head commit unchanged, and the exact line `gh pr review N --comment …` (never approve, never request changes) |
| ![d](https://img.shields.io/badge/Close_a_finished_card-56E39F?style=flat-square) | the Mac finishes it, then tells him | his own work-items only, never an epic, every linked PR merged, **no unchecked box in the body**, announced a day ahead, vetoable with `cos-obligations --veto` |
| ![b](https://img.shields.io/badge/RSVPs-5B6C5D?style=flat-square) | one tap, after he looks | |
| ![c](https://img.shields.io/badge/His_card_logs_and_RAGB-5B6C5D?style=flat-square) | one tap, after he looks | |

The unchecked-box rule exists because the first version would have closed #423: its PR merged, but six milestones were still open. A job that fails without spending anything (no login, no PATH) is redrafted, not handed to him. Sources: [claude/cos-obligations](claude/cos-obligations), [claude/briefs/review.md](claude/briefs/review.md).

---

## The Mac

`cos-run` is the one way a bot reaches the Mac. Each run shows Cassidy an approval card with the exact command. Every job writes only into `~/cos/outbox/<job>/` and returns a `receipt.json`, and a separate checker reviews it before anyone calls the work done.

| Lane | Does | Engine | Cost |
| --- | --- | --- | --- |
| ![quick](https://img.shields.io/badge/quick-3d4452?style=flat-square) | Answers from the read-only commands passed with `--with` (gh, gh search, gh api reads, git, make targets). Its model can't run anything itself. | Cursor Agent | cents |
| ![investigate](https://img.shields.io/badge/investigate-3d4452?style=flat-square) | Digs in and changes nothing | Claude Code | about $0.30 to $3 |
| ![atlas](https://img.shields.io/badge/atlas-3d4452?style=flat-square) | Finds a past chat in Agent Atlas by name, or lists recent work for a sweep, through `cos-atlas`. Lake chats give ids and card numbers only. | Claude Code | about $0.30 to $1 |
| ![gh-scan](https://img.shields.io/badge/gh--scan-3d4452?style=flat-square) | Everything in GitHub that may need Cassidy, in two GraphQL searches. Says "GitHub read failed" plainly, never an empty list. | none | free |
| ![draft](https://img.shields.io/badge/draft-3d4452?style=flat-square) | Prepares a doc or repo change on its own branch from `--base` (fetched fresh), never pushed by the job. The receipt carries the diff's sha256; an approved `cos-push-draft` can push it to one of his `cassidy/*` PR branches. | Claude Code | up to $12 |
| ![build](https://img.shields.io/badge/build-e79738?style=flat-square) | One build slice, then before-and-after checks, an independent verifier and a second model's review | Claude Code · Codex | up to $20, plus about $6 |
| ![gh](https://img.shields.io/badge/gh-eab308?style=flat-square) | Tier 0: small GitHub writes on Cassidy's own cards (labels, assignee, milestone, links, board-add, roadmap fields, lane moves with evidence, a draft PR). Re-reads the card, writes through data-org's make targets, reads back, and ledgers old, new, evidence and the undo. Everything else is refused, naming its tier. | none ([claude/cos-gh](claude/cos-gh)) | free |
| ![preview](https://img.shields.io/badge/preview-eab308?style=flat-square) | A staged batch in plain words with each line's tier, and the call to run on his "yes". He never sees a sha256. | none | free |
| ![apply](https://img.shields.io/badge/apply-eab308?style=flat-square) | Runs a write batch he approved (by its sha256, which the Chief keeps), once | none | free |
| ![apply-sheet](https://img.shields.io/badge/apply--sheet-eab308?style=flat-square) | Writes exactly the cells of a sheet.json he approved by its sha256. The gate allows no other cell. | Claude Code (sonnet) | cents |
| ![lake](https://img.shields.io/badge/lake-3d4452?style=flat-square) | One data question after his yes. Cursor CLI on a Claude model, walled twice: Cursor's permission config and a preToolUse hook that runs the gate allow only reads and `lake-query`. Canon tables touched: the answer is held on the Mac. No VPN: "connect the VPN and sign in". | Cursor Agent (Claude) | cents to $1 |
| ![eval](https://img.shields.io/badge/eval-757675?style=flat-square) | Tests a prompt change blind on the [core suite](evals/core.json). KEEPER's test before it proposes a prompt or skill change. | Claude Code, judged by Codex | about $4 |
| ![fix](https://img.shields.io/badge/fix-c0392b?style=flat-square) | Fixes this kit in its own worktree, tested in a macOS sandbox, reviewed by Codex and a checker | Claude Code · Codex | about $3 to $4 |
| ![land](https://img.shields.io/badge/land-c0392b?style=flat-square) | Lands an approved fix: fast-forward, install, roll back if a check fails, push. `revert` undoes it. | none | free |
| ![note](https://img.shields.io/badge/note-757675?style=flat-square) | Records a correction for KEEPER | none | free |
| ![pause](https://img.shields.io/badge/pause-5B6C5D?style=flat-square) | Holds a scheduled slot for N days, `0` resumes | none | free |
| ![receipt](https://img.shields.io/badge/receipt-5B6C5D?style=flat-square) | A job's result, "running", or "didn't finish, rerun?" with the exact call | none | free |

**Long jobs run with `--async`.** Grok's terminal call gives up before a 3-minute job ends, and the Chief used to re-ask until Cassidy had approved the same job ten times. Now `investigate`, `atlas`, `draft`, `build`, `eval`, `fix`, `land` and `lake` return in under a second, run detached, and push their receipt to the Chief's results webhook when they finish. The Chief never re-runs a job because a reply didn't come back; it checks with `cos-run receipt`.

**Every lane explains itself.** `cos-run <lane> --help` prints its arguments and examples, and a refused call prints the call that would have worked. Receipts lead with a verdict: VERIFIED (an independent check passed), NOT VERIFIED (it failed) or INCONCLUSIVE (nothing checked it). Long jobs run under `caffeinate -i -s -w <pid>`; one that stops without a receipt reads "Didn't finish ... Rerun?" with the exact call.

**Jobs fix their own misses once.** A Claude checker grades each receipt as blocking or notes. If something blocks, the job gets one revision round with the checker's findings. A receipt still blocked leads with "Needs you:" and one plain question; notes show as "Unverified:".

**Scheduled jobs reach ~/Documents** through `cos-launch`, a small compiled launcher with Full Disk Access that starts every launchd job. It runs only programs in `~/cos/bin`.

Source: [claude/cos-run](claude/cos-run).

---

## The Flight Recorder

Every action on the Mac appends one line to `~/cos/state/ledger/`. `cos-db load` builds `~/cos/state/cos.db` from that ledger and the folders that already exist. The page at `http://127.0.0.1:8787` reads the database and nothing else. It never leaves this Mac.

| What you see | Where it comes from |
| --- | --- |
| ![jobs](https://img.shields.io/badge/Jobs_and_cost-141416?style=flat-square) | `jobs`, from the ledger plus each receipt |
| ![walls](https://img.shields.io/badge/Gate_blocks-c0392b?style=flat-square) | `gate_events`. Allows are not recorded |
| ![schedule](https://img.shields.io/badge/Schedule-e54796?style=flat-square) | `schedule`, including runs the Mac slept through |
| ![learn](https://img.shields.io/badge/Corrections_and_evals-757675?style=flat-square) | `corrections`, `evals`, `board_health` |

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
 08–16   obligations every two hours ───────────────────────────────▶ OPS
```

| Slot | When | Goes to | What Cassidy sees |
| --- | --- | --- | --- |
| ![followups](https://img.shields.io/badge/followups-e54796?style=flat-square) | Weekdays 06:15 | OPS | Drafts inside the 06:30 brief |
| ![pulse](https://img.shields.io/badge/pulse-e66f30?style=flat-square) | Weekdays 08:10 | STEWARD | Three lines and owner nudge drafts, before the ops meeting |
| ![capture](https://img.shields.io/badge/capture-e66f30?style=flat-square) | Weekdays 16:00 | STEWARD | A write batch for his cards, by sha256 |
| ![reconcile](https://img.shields.io/badge/reconcile-e66f30?style=flat-square) | Tue, Thu 10:00 | STEWARD | Drift, which side should move, sheet paste text |
| ![week](https://img.shields.io/badge/week-e66f30?style=flat-square) | Fri 10:00 | STEWARD | The weekly packet for him and Melanie |
| ![opportunity](https://img.shields.io/badge/opportunity-e79738?style=flat-square) | Mon 08:30 | BUILDER | Up to three build ideas that Claude and Codex each checked and failed to break, plus contested ones for him to call |
| ![keeper](https://img.shields.io/badge/keeper-757675?style=flat-square) | Fri 13:00 | KEEPER | A scorecard and up to three fixes |
| ![obligations](https://img.shields.io/badge/obligations-e54796?style=flat-square) | Weekdays 08, 10, 12, 14, 16 | OPS | What the Mac finished under standing approval, and what needs one tap |

Scheduled jobs run with an explicit PATH (`~/.local/bin`, `/opt/homebrew/bin`), because launchd's bare PATH hid the Claude CLI on the first day. A dry run records nothing.

Sources: [claude/cos-sched](claude/cos-sched), [claude/briefs/](claude/briefs/).

---

## How BUILDER Picks a Build

**BUILDER only shows Cassidy ideas that two different models proved, and that each failed to break.** On Nov 14, two of
three ranked ideas died on premises nobody had checked (#651 assumed an IQA confidence score that doesn't exist, and
overlapped its owner's own milestone). Since Nov 15 the research happens on the Mac, where the code and cards are.
Claude and Codex each do their own diligence, a script compares them, each attacks the other's CHECKED ideas once, and
a script decides. Fewer than three ideas is a normal, honest result. Cassidy's decisions: Codex reads code, PRs, the
board, receipts and a canon-screened Slack digest, never transcripts (1b); Grok ranks loosely (2c); $30 per run (3a).

```mermaid
flowchart TD
  T["Trigger<br/>Monday 08:30, or on request"] --> P1["Claude's pass, on the Mac<br/>candidates from board, calls, Slack, builds;<br/>diligence per idea; slack-digest.md"]
  P1 --> C["Checker<br/>opens the cited lines; one revision round"]
  C -->|blocked| X["Nothing ranked<br/>the receipt says why"]
  C -->|pass| W["Canon tripwire<br/>digest, receipts, idea text;<br/>call evidence held on the Mac"]
  W --> P2["Codex's blind pass<br/>card and one-line idea only;<br/>walled: reads and GitHub reads, no writes"]
  P2 --> CMP["Compare (script)<br/>agree CHECKED · agree DEAD · disagree"]
  CMP --> XA["Cross-examination, one round each<br/>Claude attacks Codex's CHECKED,<br/>Codex attacks Claude's; concede or defend once"]
  XA --> V["Verdict (script)"]
  V -->|both CHECKED, unrefuted| S["Survives"]
  V -->|a refutation defended| CT["Contested<br/>both arguments side by side"]
  V -->|anything else| O["Out, with its reason"]
  S --> B["BUILDER ranks loosely<br/>models' consensus order as advice"]
  CT --> B
  B --> Y["Cassidy picks one<br/>yes to its brief, then a build"]
```

| Status (each model) | Means | What happens |
| --- | --- | --- |
| CHECKED | Premise quoted from the real code or PR, owner's plans read, a named user, data reachable | Cross-examined by the other model |
| OFFER | The owner already planned this work (a milestone, PR, DRD or DADR) | Offer help to the owner; never build next to them |
| DEAD | The premise is false, or the idea is on `~/cos/handbook/build-exclusions.md` | Out, with the reason |
| NOT CHECKED YET | Something couldn't be read | Out, with what's missing |

| Verdict | Rule | BUILDER |
| --- | --- | --- |
| Survives | Both models end at CHECKED, and no refutation stands | Ranks it |
| Contested | One side refuted it and the other defended, with citations | Shows it labeled; Cassidy decides before any build |
| Out | Everything else, including an idea the cap kept from being cross-examined | Lists it with the reason; can't promote it |

What crosses to Codex: the cards and one-line ideas (blind), `slack-digest.md`, this week's pulse, capture, reconcile
and week receipts, `build-exclusions.md`, and in cross-examination Claude's case with every call-sourced line replaced by
"held on the Mac". Each passes the canon tripwire first; a hit holds that file on the Mac and the receipt says so.
Codex runs through the Cursor CLI in `<job>/codex/ws`, behind `claude/codex/cli.json` and `claude/cursor-codex-hook`:
it reads only that folder and `~/cos/data-org-main` (a file naming a canon table is refused), runs only GitHub reads,
and can't write, post or reach the web. Proved live on Nov 15 (15 of 15 refusals and reads as intended).

The $30 cap covers every model in the run. Codex's cost is estimated from its tokens at list price, because the Cursor
CLI reports tokens, not dollars. A step that doesn't fit doesn't start, and neither does any step after it; the receipt
names them. The result is `builder.md` and the receipt's `diligence` block. Sources:
[claude/briefs/opportunity.md](claude/briefs/opportunity.md), [claude/cos-diligence](claude/cos-diligence),
[claude/cursor-codex-hook](claude/cursor-codex-hook), [grokbot/builder.md](grokbot/builder.md).

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

Allowed lines: the repo's own write targets (`make ragb`, `field`, `set-pillar`, `complete`, `promote`, `board-add`, `ship-link`, `context-request`), `gh issue create`, `gh issue edit` (labels, assignees, milestone, title, and a body from the job folder), `gh issue comment --body-file`, `cos-link sub|blocked-by|unsub|unblock`, `gh pr comment`, `gh pr review`, `gh pr merge`, `gh pr ready`, `cos-push-draft` to one of his `cassidy/*` branches (fast-forward only, refused if the branch moved), `cos-share` for files a colleague asked for (a `cassidy/*` branch started from theirs, with a draft PR into theirs; never a push to their branch), and for builds a push of a `<name>/<branch>` build branch and `gh pr create --draft`. `EXECUTE=1`, raw closes and deletes are refused. Sheet edits go through `apply-sheet` the same way. Kit fixes go through `land` the same way.

---

## The Walls

| Wall | What it stops | Where |
| --- | --- | --- |
| ![door](https://img.shields.io/badge/One_door-3d80f1?style=flat-square) | Any specialist running a command or writing outside a draft | each bot's REMEMBER block |
| ![rules](https://img.shields.io/badge/Permissions-3d80f1?style=flat-square) | Allowed without asking: `cos-run` quick, investigate, receipt, note, pause. Always asks: any other Mac command, `cos-run` draft, build, apply, eval or lake, sends, posts, calendar, sheets, GitHub writes, purchases, Zoom sign-in | Grok: Settings, Permissions and Computer |
| ![gate](https://img.shields.io/badge/The_gate-c0392b?style=flat-square) | Secrets, production writes, infrastructure, force-push, canon values, `context/` edits, edits to this kit | [claude/gate.sh](claude/gate.sh) |
| ![hash](https://img.shields.io/badge/Approval_by_hash-eab308?style=flat-square) | Any batch that differs from the one approved | [claude/cos-run](claude/cos-run) |
| ![lake](https://img.shields.io/badge/lake--query-3d4452?style=flat-square) | Writes, non-aggregate canon reads, unbounded queries. Runs only inside the lake lane; the other lanes and the gate refuse it. | [claude/lake-query](claude/lake-query), [claude/lake/cli.json](claude/lake/cli.json), [claude/cursor-lake-hook](claude/cursor-lake-hook) |
| ![tiers](https://img.shields.io/badge/GitHub_tiers-eab308?style=flat-square) | Tier 0 writes on anyone else's card (off until Cassidy switches it on), and anything above tier 0 without his yes | [claude/cos-gh](claude/cos-gh) |
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

The baseline eval on 2026-11-09 scored **3.0 of 5** across six real requests, with **0** hard-rule violations. Sources: [evals/core.json](evals/core.json), [claude/briefs/keeper.md](claude/briefs/keeper.md). Cassidy kept the eval lane on 2026-11-14 (plan, "Decisions after the Grok export").

**Why canon stays on the Mac.** The risk is chat content, not queries: a Claude or Cursor chat that read canon (a lake chat in Agent Atlas), a transcript or a doc. `lake-query` never ran a query in 373 jobs through 2026-11-14 (cos.db `commands` table); one eval job called `run_query.py` directly. So the walls that matter are on what leaves the Mac: lake chats give bots ids and counts only, the checker fails a receipt carrying canon terms, and the lake lane holds any answer that touched a canon table.

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

`install.sh` checks prerequisites, copies the kit into `~/cos`, installs `cassidy-mode` for Claude and Cursor, and proves the walls with 196 checks. `--schedule` loads the launchd jobs, and `--schedule=<slot,…>` loads only those (`--schedule=obligations,dashboard` adds the obligations ledger and the five-minute dashboard refresh). Full steps, including the Grok setup and webhook keys, are in [INSTALL.md](INSTALL.md). The design and its reasons are in [PLAN.md](PLAN.md). A one-page overview is [docs/system-overview.html](docs/system-overview.html).

This folder is the only source. A change is an edit here, a commit with its reason, a push, then `./install.sh`. To undo one, revert the commit and reinstall.

---

## Project Structure

```
cos-kit/
├── claude/                  the Mac side
│   ├── cos-run              front desk: quick · investigate · atlas · gh-scan · draft · build · gh · preview · apply · apply-sheet · lake · eval · fix · land · note · pause · receipt
│   ├── cos-gh               tier-0 GitHub writes, each ledgered with its undo; plain words for a staged batch
│   ├── cos-launch.c         the launcher every launchd job starts through (Full Disk Access, ~/cos/bin only)
│   ├── cos-gh-scan          the GitHub scan · cos-atlas, the Agent Atlas CLI · cos-link, cos-push-draft for approved batches
│   ├── cos-sandbox-test     runs a fix's installer in a macOS sandbox · zoom-mirror.applescript builds ZoomMirror.app
│   ├── cos-sched            the clock (launchd) · cos-push hands receipts to Grok webhooks
│   ├── cos-obligations      what's waiting on Cassidy, owned to closure, with his standing approvals
│   ├── cos-ledger           append-only ledger · cos-db loads it into cos.db · cos-dash opens the page
│   ├── gate.sh              the wall in front of every job
│   ├── lake-query           read-only data, canon aggregates only (the lake lane's one command)
│   ├── lake/, cursor-lake-hook   the lake lane's Cursor permission config and its preToolUse hook
│   ├── board-pulse          the board readout from the repo's make targets
│   ├── briefs/              the scheduled jobs' briefs
│   └── *.md, *.json         lane prompts, the verifier, settings, the receipt schema
├── grokbot/                 each bot's REMEMBER block and PLAYBOOK, the Custom Rules, the rules skill
├── handbook/                rules, the board and engineering standards, the system map, standing approvals
├── builds-template/         a build workspace: BRIEF.md · VERIFY.md · HANDOFF.md · verify
├── evals/                   the core eval suite
├── claude-skills/           cassidy-mode, how Claude works with Cassidy
├── apps/flight-recorder/    the local page: what ran, what it cost, what got blocked
├── HANDOFF.md               the cold-start note for a new agent
├── docs/                    the overview page, images, and docs/src/ to regenerate them
├── install.sh               installer and self-test
├── INSTALL.md               step by step
└── PLAN.md                  the design and its reasons
```

Not in this repo: `~/cos/handbook/people.md`, `workstreams.md` and `sources.md`, job receipts, and the webhook keys in the macOS Keychain.
