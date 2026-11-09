# Chief of staff v2

As of November 9, 2026 (v5). Builds on `chief-of-staff-support-and-access-2026-11-07.md`.

## In one paragraph

You talk to one Grok bot, the **Chief**. It handles mail, Slack and calendar itself. When a job needs your Mac (the repo, GitHub, transcripts), it runs one command, `cos-run`, and picks the cheapest engine that can do the job. **Cursor Agent** answers quick repo questions for pennies. **Claude Code** does multi-step work, with the same settings, skills and model you use in Cursor every day. Both engines follow the repo's own playbook: `AGENTS.md` and the 28 data-org skills. A second bot, **OPS**, runs your personal routines. A third, **STEWARD**, keeps the initiatives board and the roadmap true every business day. A fourth, **BUILDER**, runs engineering builds from opportunity to a proven prototype to a candidate for The Pantry. A fifth, **KEEPER**, looks after the other four: every Friday it finds what keeps going wrong and proposes a tested fix. Scheduled work starts on your Mac, not in a bot, and the results are pushed to the bots.

## What changed on November 9: the devil's-advocate pass

I read Grok Bot's own documentation (cursor.com/docs/grok-bot and /help/grok-bot) against everything we built. Several of my earlier assumptions were wrong.

| # | What I'd assumed | What's true | The fix |
|---|---|---|---|
| 1 | Each bot has a Description field to paste into | **Personal Bots no longer have a description.** A Bot's job is its first message, which it remembers, plus skills. | Each `grokbot/*.md` is now a REMEMBER block (lasting rules) and a PLAYBOOK saved as a private skill. Skills survive a Duplicate; memory doesn't. |
| 2 | A Custom Rule could limit which Mac commands a bot runs | **Custom Rules (Auto-review) cover the Bots' cloud computer and apps, not your Mac.** Mac commands have a separate setting with three choices only: Ask every time, Always allow, Never allow. "Always allow" would let any bot run anything. | Keep it on **Ask every time**. The card shows the exact command, and that tap is your approval. For `apply`, it shows the sha256. |
| 3 | Bot routines could call the Mac on a schedule | **Routines run in the cloud, and a Mac command waits for your tap.** A 08:15 pulse would sit on an approval card. | **The Mac runs its own schedule** (`cos-sched` under launchd) and pushes each receipt to the bot's **webhook routine**. Bots never start a Mac command unattended. If the Mac was asleep, the bot is told "MISSED", so it doesn't reuse old data. |
| 4 | "Start a new chat per task" | **Each Bot has one conversation**, with memory and summaries managed by Grok. | Removed that advice. The playbook lives in skills, so a long conversation doesn't erode it. |
| 5 | Separate bots are separate boundaries | **All your Bots share one cloud computer, its files and its logins,** and connected apps act as you (a Slack post from a bot is a post from you). | The walls that matter are Auto-review "Ask first" rules, the Mac setting, and `gate.sh`. No tokens go on the cloud computer. |
| 6 | The kit could live where it was built | It sat in a folder this app deletes with the session. | `install.sh` now keeps it in **`~/cos/kit` as a git repo**. Every change is a commit you can read and revert. |
| 7 | `cos-run` was tested | The self-test never ran a Claude lane. A dry trace found that **macOS's bash 3.2 crashes on empty arrays**, so every `investigate` without `--resume` would have died. Jobs also couldn't read `~/Documents/Zoom`. | Both fixed. A live smoke test is still the first install step. |
| 8 | One checker was enough | The checker was the same model family as the worker, and it read claims rather than running anything. | Builds now get a **baseline-vs-treatment run, an independent verifier that runs the code, and a different-family review** (below). |
| 9 | OPS's Friday receipt audited the system | It overlapped with KEEPER's job. | It moved to KEEPER. |

**On the Zoom bot.** I found no documented Grok Bot feature that joins calls. What exists is a **Zoom app connector**, which **fails to authorize from the desktop app today (error 4700, no workaround)**, per Grok's help center. Third-party services can put a bot into a call. Even when the connector works, I'd **keep `~/meetings` and `~/Documents/Zoom` as the record**:
- They're full, local and timestamped, and every claim rule ("a call claim needs the transcript and a timestamp") rests on them.
- A bot joining calls is a visible recorder in partner calls (Datasembly, OGD), and it sends WISEcode conversations to a third party.
- Two transcript sources would disagree, and then neither is the record.

Use the connector, once it works, only read-only, for a call missing from `~/meetings`. One thing is worth adopting now: Grok's **voice chat**. After an important call, give the Chief a two-minute spoken debrief. The full transcript lands in the chat as your notes. If you heard about a Zoom feature somewhere specific, send me the link. If it's real and newer than the docs, I'll fold it in.

## Conformance with data-org and data-org-notebook (checked November 9)

I read both repos' rules from origin/main (data-org 16876d5, data-org-notebook 9430359): AGENTS.md, CONTRIBUTING.md, `standards/writing.md`, the notebook's AGENTS.md, HANDOFF.md and README, and the canon charter's decisions. Most of the kit already followed them:
- canon rows never cross the wire;
- `uv` only;
- read-only data through `run_query.py`;
- worktrees, PR-first, never `main`;
- the Makefile wins;
- write skills as previews;
- owners merge.

Seven gaps, all fixed:

| Gap | Rule | Fix |
|---|---|---|
| Draft branches were `cos/<job>` | data-org: branches are `<name>/<topic>` | now `cassidy/cos-<job>` |
| Jobs read the notebook from your checkout | read rules from origin/main | a fresh `~/cos/notebook-main` worktree; `lake-query` still runs from your checkout, where `.env` lives |
| The writing standard wasn't enforced on team-bound text | data-org AGENTS.md: it covers issue comments, PR text and agent replies | jobs run `make lint-writing` on every team-bound file; the checker fails a file without a clean run |
| The boundary list was partial | CONTRIBUTING.md: no verbatim executive quotes, no RAGB values in files, ADRs by id only | added to the lane prompt and the checker; transcript quotes stay in receipts, not team docs |
| `context/` could be edited | read-only, overwritten by a publish step | the gate blocks edits to data-org `context/` |
| Notebook conventions weren't in the build rules | `wt/cc/<slug>`, notebook + Quarto + numbered SQL, eligibility denominator, pg_catalog recon, BLUF and Blocked table | in the engineering standard, the lane prompt and the build brief |
| Decision 14 wasn't applied | canon charter decision 14: canon terms and **label context** reach a model only through Data Org tooling built to the AI Data Stewardship Field Guide | Claude on your Mac is that tooling. Canon and label builds skip the Codex review. Nothing sent to the Grok bots carries canon terms or label text. |

**Open item:** the WISEcode AI Data Stewardship Field Guide v1.0 (Tolga, 2026-09-22) governs credentials, sharing and commits. It isn't in either repo, and your Drive search doesn't find it. Until someone sends it, the kit follows decision 14 and the notebook's rules strictly. When it turns up, KEEPER folds it in.

## KEEPER's context: the system map

`handbook/system-map.md` (also a Grok skill for KEEPER and the Chief) is the one place that lists:
- every rule, in order of authority;
- every source (board, roadmap sheet, repos, `~/meetings`, `~/Documents/Zoom`, Zoom web, Slack, Zendesk, the lake, Gmail, Drive, your transcripts, receipts, evals, the kit), with how a Mac job and a Grok bot each reach it;
- which Slack channels to read, and which never to read (the hiring channels, `#owls`, DMs you haven't pointed to);
- what may cross which wire.

KEEPER's Friday audit reads it first, then the rules fresh from both repos, then the week's evidence. Besides mistakes, it reports three things:
- **rules drift:** a repo change the kit depends on;
- **conformance breaks:** a bot output that broke a repo rule;
- **context health:** a source that went dark, PR #610 merging, the Field Guide turning up.

## Getting a call transcript: the ladder

1. `~/meetings`.
2. `~/Documents/Zoom`.
3. Ask you.
4. **Last resort, after your yes for that one meeting:** the Chief signs in to zoom.us in its browser as you, downloads only that meeting's transcript file (never video or audio), moves it to `~/Documents/Zoom` on your Mac, deletes its copy from the shared Bot computer, and re-runs the job.

A Mac job never logs into Zoom. It returns "needs transcript: <meeting, date>", and the Chief offers step 3 or 4. The morning follow-ups also list yesterday's meetings with no transcript, so a gap surfaces the next day.

## How it works, in plain words

**`cos-run` is a front desk on your Mac.** The Chief can't reach into your Mac freely. It can hand one note to the desk. The desk decides which worker gets it, gives that worker a fixed set of keys, puts everything they produce into one folder (`~/cos/outbox/<job>/`), and hands back a one-page receipt. The Chief reads the receipt, never the worker's whole conversation. That keeps it cheap and keeps stray files off your Mac.

**The lanes are how much the worker may touch:**

| Lane | Plain meaning | Engine | Typical cost |
|---|---|---|---|
| `quick` | "Look something up and tell me." The desk runs one approved read-only command, such as `make stale`, and the worker only reads the output and answers. | Cursor Agent, `ask` mode, Composer 2.5 | cents, about 5 seconds |
| `investigate` | "Dig into this and report back. Touch nothing." Reads the repo, board, PRs and transcripts. Writes only its report. | Claude Code (Opus 5.5) | up to $3 |
| `draft` | "Prepare it, but don't ship it." Works on its own copy of the repo, on its own branch. Can write and commit there. Can never push, merge or comment. | Claude Code (Opus 5.5) | up to $12 |
| `build` | "Do the next slice of this build, then prove it." Works in `~/builds/<slug>`. Afterwards the desk checks it three ways (below). | Claude Code, then a verifier, then Codex | up to $20, plus about $6 of checking |
| `eval` | "Test this proposed prompt change before we adopt it." | Claude runs both versions, Codex judges blind | about $4 per case per version |
| `note` | "Remember this correction." One line into `~/cos/state/corrections.jsonl` for KEEPER. | no model | free |

**`gate.sh` is the bouncer.** Before Claude runs any command or opens any file, the bouncer checks it against a blocklist: push, merge, comment, close, `EXECUTE=1`, board-write `make` targets, delete, secrets. If it's on the list, the command doesn't run. Claude is told to write the proposed action into the receipt's "needs approval" section instead. A rule in a prompt is a request. The bouncer is a locked door.

**The checker is a second pair of eyes.** After a Claude job, a fresh Claude session that didn't do the work reads the receipt and fails it if a claim has no evidence, a "decision" isn't recorded anywhere, or a file was created and not listed.

**Two clocks.** When you're in a chat, the bot asks the Mac (a card, a tap). On a schedule, the Mac runs the job itself and hands the bot the result. A bot never runs something on your Mac while you're not looking.

| Mac time | Job | Goes to |
|---|---|---|
| weekdays 06:15 | follow-ups from yesterday's calls | OPS (into the 06:30 brief) |
| weekdays 08:10 | board pulse (model-free read, Cursor summary) | STEWARD |
| Tue, Thu 10:00 | roadmap reconcile | STEWARD |
| weekdays 16:00 | your capture onto the board | STEWARD |
| Fri 10:00 | the weekly pass | STEWARD |
| Mon 08:30 | build opportunities | BUILDER |
| Fri 13:00 | the audit of every bot and lane | KEEPER |

A job that finds nothing new answers `NO CHANGE`, and nothing is sent, so no bot turn is spent on it.

## Aligned to how you already work

What I found on your Mac:

- You run **Claude Code inside Cursor** (the extension, `claude-vscode`), on Opus 5.5 in auto mode. `claude -p` is the same engine. It reads the same `CLAUDE.md`/`AGENTS.md`, the same `~/.claude/skills` (`voice`, `meeting-reanalysis`, `app-*`) and the same `data-org` plugin. A `cos-run` job behaves like your Cursor sessions, just headless.
- `data-org` already has the playbook: `AGENTS.md`, `docs/2026-10-12-work-system.md`, and skills in **two places**. `.cursor/skills/` has 28 (Cursor reads these). `plugins/data-org/skills/` has 18 (Claude reads these). Both include `day`, `board`, `stale`, `log`, `park` and `gate`. Only Cursor has `handoff`, `orient`, `draft-drd`, `draft-dadr` and `app-*`.
- **Cursor Agent CLI** (`agent`, 2026.11.05) works headless. I tested it in `ask` mode: it listed all 28 skills in 5 seconds on about 12K input tokens. `plan` mode can't run shell commands, so the `quick` lane has the desk run the command and Cursor only reads the result.
- You keep **`HANDOFF.md`** at the top of project folders (`image-extractor`, `data-org-notebook`). That's exactly the "state lives in a file, not a chat" pattern. The system uses it as each project's status page.

What changed in the kit because of this:

1. **No invented specialists.** The repo skills *are* the specialists. Claude jobs are told to open the skill's `SKILL.md` and follow it. I removed my `board-analyst`, `writer` and `data-analyst` agents. Only `meeting-analyst` (used to fan out across calls) and `devils-advocate` (for judgment calls) remain.
2. **Write-skills become previews.** `log`, `park`, `promote`, `intake`, `ship`, `card` and `pr` run as previews. Their exact commands land in "needs approval" in the `handoff` skill's format: `DRY_RUN=1` first, then the real line.
3. **Cursor is the cheap lane, not a forbidden one.** `quick` uses Cursor Agent. Inside a job, starting another agent is still blocked. Only the desk picks engines.
4. **Your interactive Cursor sessions stay yours.** The system never resumes or writes into them. It reads `HANDOFF.md` for status and, when your live work needs input, leaves a brief file you can open with `@` in Cursor.

**Which engine for what:**

| Job | Engine |
|---|---|
| "What's stale?", "What's in Ship & Delivery?", "What did PR 212 change?", "Which skill files X?" | `quick` (Cursor) |
| EOD reconcile, board-health, call follow-ups, partner prep, "what did we actually decide about gold schema" | `investigate` (Claude) |
| DRD/DADR drafts, reports, a repo doc change, Did/Blocked/Next text for a whole lane | `draft` (Claude) |
| Building things: image-extractor, apps, pipelines | **You, in Cursor with Claude**, interactively. The Chief only reads `HANDOFF.md` and tracks the open loops. |

## The bots: how you compare to "the team" setups

| Seat (unicode / m4lka guides) | What it's for | In your setup |
|---|---|---|
| Chief of Staff | the only bot you talk to; routes | **Chief** (Grok) |
| Ops / routines | owns the clock; keeps routines off the chatty bot | **OPS** (Grok) |
| Misc | random requests, so specialists stay clean | **Dropped.** The Chief does small errands itself. Add Misc only if the Chief's conversation keeps filling with one-offs. |
| Playbook Owner / bot builder | owns the standards; audits and fixes the other bots | **KEEPER.** It owns the *system's* playbook: the bots' skills, the lane prompts, the briefs, the gate, the eval suite. It proposes; you approve and apply. The team's playbook (`AGENTS.md`, the work-system doc, the repo skills) still belongs to people, through PRs. |
| Source of Truth | answers from your docs with sources | **The `quick` and `investigate` lanes.** Your sources live on the Mac, not in the cloud bot. |
| Checker | says no without proof | **The checker pass** inside `cos-run`, with a fresh context every time |
| Specialists (1–2) | the jobs you do by hand weekly | **The repo skills**, run by Cursor or Claude. A new domain becomes a skill, not a bot. |

**So: five bots.** The guides land on 5–6 seats because their bots *are* the workers. Yours aren't. The work happens in Cursor and Claude, which already have specialists (skills), parallel workers (subagents) and a playbook (`AGENTS.md`). Each extra bot is earned by a domain with its own clock and its own memory: the board, the builds, and the system itself.

| Bot | Owns | Talks to you | Install |
|---|---|---|---|
| **Chief** | routing, open loops, approvals, restating your requests | yes, the only one | week 1 |
| **OPS** | your personal clock: morning brief and follow-up drafts | through the Chief | week 1 |
| **STEWARD** | Project 1 and the roadmap sheet: pulse, capture, reconcile, weekly pass, owner nudges | through the Chief, plus write batches you approve | week 1 |
| **BUILDER** | engineering: opportunities, briefs, build workspaces, proof, candidates for The Pantry | through the Chief, plus briefs and batches you approve | when you pick the first build |
| **KEEPER** | the other bots: weekly audit, repeated mistakes, tested fixes, roster changes | through the Chief, Fridays | after two weeks of receipts |

Every bot reply and every bot-to-bot message costs usage, so the bots stay silent unless something needs you.

## Verification and evals: Lauren's method, without auto-merge

Lauren's talk, as the posts summarize it: **trust is the bottleneck.** The sequence is agent → skill → verification → eval → subagents. "Every failure became a skill, every skill an eval." Lauren's pstack plugin (poteto/plugins) has a `prove-it-works` principle, `verify-this` (a falsifiable claim, baseline vs treatment, one verdict), an orchestrator's verifier ("Run the code. Reading the diff is not verification"), a blinded `eval` playbook, and `reflect` (route each lesson into a skill edit, with a person's approval). Chonsy's post adds the proof contract. You've ruled out auto-merge. Everything up to the merge carries over.

| Lauren's practice | Here |
|---|---|
| Proof requirements: BASELINE, BEHAVIOR, QUALITY, PERFORMANCE, SKILL, each a PASS / FAIL / NOT_RUN evidence record | `receipt.proofs` on every build. The checker fails a missing proof, an unfixed FAIL, or a NOT_RUN with no blocker. |
| A verification skill per feature (entry point, preconditions, actions, expected result, failure states) | `VERIFY.md` in every build workspace. `./verify` implements it. Regressions it caught are kept. |
| Baseline vs treatment | After each headless build, `cos-run` runs today's `./verify` against the code from before the job. Failing before and passing after is fail-to-pass. Passing both times means the check is vacuous, and the build isn't proven. |
| The verifier runs the code, in its own context | A fresh Claude runs in a **throwaway copy** of the workspace, criterion by criterion. It returns live-verified / test-verified / check-only / verifier-blocked / verifier-failed, and it can't change the build. |
| Different models check each other | Codex reviews the diff. The eval judge is Codex too, a different family from the Claude worker. |
| Evals, blinded | `cos-run eval core <proposed prompt>` runs the current and proposed versions on the same five real requests. Job IDs are neutral, so the agent doesn't know it's being tested. One judge scores both in one pass by shuffled label. A change is promoted only if it scores at least as well, with no must-not violations. |
| Every failure becomes structure | `cos-run note` records each correction. KEEPER turns repeats into a check first, a skill edit second, and memory last. |
| Auto-merge | **No.** The ladder stops at a draft PR, after your yes. That stays true even when the evals look perfect. |

## KEEPER, the bot that maintains the bots

Akari's post describes Lauren's version: a bot that reads every conversation, finds the bot that keeps making the same mistake, and rewrites its skills. Yours does the first two and **proposes** the third.

- **What it reads** (Fridays, via the Mac): every receipt (status, checker failures, verifier levels, cost), your corrections, missed and failed scheduled runs, eval reports, and the kit's git log. Grok doesn't document a way for one bot to read another bot's chat. The receipts and your corrections carry the same signal, so recording corrections matters.
- **What it sends**: a five-line scorecard, up to three fixes ranked by value (each with its evidence, its rung, and an eval result when it changes a prompt), and the one thing you wouldn't miss.
- **What it never does**: change a bot, skill, routine or kit file itself. The gate blocks any job from editing `~/cos/kit`, `~/cos/claude`, skills, or the schedule. You apply each change: paste text into a bot, or `git apply` plus `./install.sh` for the kit.
- **Roster**: it's the only bot that proposes adding, merging or retiring a bot.
- **Monthly**: it proposes re-mining `cassidy-mode` from your transcripts.

## Your daily loop, built into Claude and Grok

Morty's post on Lauren's prompting: draft → restate → clarify the goal → constraints → good and bad examples → test → revise, until it's reliable. That's how you already work. Your first message is a rough draft, and you correct as you go. I mined about 190 of your messages to Claude in Cursor to write it down as **`cassidy-mode`**:

- **In Claude (Cursor and the CLI):** a skill in `~/.claude/skills` and `~/.cursor/skills`, loaded in every session through `~/.claude/CLAUDE.md` (created only if you don't have one). For anything non-trivial, Claude restates your ask as a brief (goal, done-means, constraints, an example when format matters, stop-if). It asks at most three numbered questions, which you answer "1-yes 2-…" the way you already do. It tests against done-means before showing you anything, and it turns each correction into a rule. It also encodes what the transcripts show you expect: the tldr first, evidence you can check, the bolder option next to the safe one, design detail, owners own their work, document then proceed, drafts in your voice.
- **In Grok:** the Chief restates every request above a quick lookup as a brief, shows you the brief, the lane and the cost cap, and starts when you say go. The same `cassidy-mode` text is saved as a Grok skill for every bot.
- **Closing the loop:** a correction is recorded with `cos-run note`, a repeat becomes a fix, and a fix gets an eval case so it can't come back unnoticed.

## The board steward

Your charter, per the Nov 3–6 calls: you and Melanie hold "the keys of the kingdom", you're "driving" the sheet-and-board reconcile, and the board must be "fully and explicitly representative" of the roadmap through year end. On Oct 30 you said you were spending "a big chunk" of your time on board cleanup. The Steward takes that cleanup off you. You keep the enforcement decisions.

**It runs your existing system. It doesn't invent one.** The data-org repo already defines the board: the work-system doc (the rule), David's commands-by-cadence and board-weeding docs, the Makefile (which wins over skill text), the board skills (`day`, `log`, `card`, `sub`, `park`, `ship`, `pr`, `stale`, `board`), and your `maintain` cold start on PR #610. `handbook/board-standard.md` only points to those, records the mandate, and maps each rule to the target that checks it. Jobs always run against a fresh copy of `origin/main`, never your working checkout. That checkout is on `cassidy/630-label-facts-providers` with uncommitted files.

**Baseline today**, from `board-pulse`, which only wraps `make stale`, `make ship-check`, `make roadmap-check` and `make weed` at `16876d5`:
- 21 weed candidates.
- 30 of 61 Discovery, Defining and Shipping cards missing a Pillar metric or Target.
- 2 Target-vs-milestone drifts: #652 and #653, against "Nov 25 · November slice to Live".
- 7 Shipping or Delivery Prep cards with no RAGB, and 6 flagged untouched.

**Its loop follows commands-by-cadence:**

| When | What | Output |
|---|---|---|
| 08:10 daily | Before the ops meeting: `make stale`, `ship-check`, `roadmap-check`, `weed` | 3 lines to the Chief, plus one nudge draft per owner naming the exact fix ("post today's log with /data-org:day") |
| 16:00 daily | Your capture: `maintain` cold start, then the `day` skill over your meetings, PRs, Slack and `HANDOFF.md` changes | a write batch for your cards (log, then `make ragb`), and notes for others |
| Tue + Thu | Roadmap reconcile: `make roadmap-check` plus a read of the sheet's columns C, D, E and I | for each drift row, which side should move. `make field` lines for your cards, paste text for the sheet |
| Fri | The weekly pass, in David's order: `weed`, `raqs`, `ship-reconcile`, `intake-sweep` (dry run), `socialize`, `stale DAYS=7` | the weekly note from the `make week` window, plus dispositions as `handoff` previews. `EXECUTE=1` steps are listed, never run. |

**Enforcement without doing the work:**
- The person on the card makes the move. The Steward never logs, sets RAGB, moves or parks someone else's card. It drafts the nudge, and you send it.
- Escalation (proposed for you): day 1 the nudge; day 2 the ops-meeting list, which already starts from `make stale`; day 3+ your private brief with one suggested action.
- Team numbers only in public. Per-person lists go only to that person and to you.

**Write batches, so one yes covers many writes.** For writes that are yours (logs and RAGB on your cards, `make field` where a roadmap row decides the value), the job writes `apply.sh`. The receipt carries its sha256. You say yes to that hash in the Chief chat, and `cos-run apply` runs exactly that file, once, from the fresh copy of `main`. It only accepts the repo's own write targets (`make ragb/field/set-pillar/complete/promote/board-add/ship-link/context-request`) and `gh issue comment --body-file`, at most 40 lines. `EXECUTE=1`, closes, merges and deletes are refused.

**Corrections from last turn:**
- **No Cards column needed.** The repo already links the sheet to the board: milestones carry the roadmap row dates, a blank Theme means "not on the roadmap", and `make roadmap-check` reports drift.
- **Daybook doesn't read anything.** "Daybook is a write surface and reads nothing" (the 2026-09-03 ruling quoted in the weeding doc), and the pilot decides the shape of the daily write. The Steward uses the make targets as its interface and adapts when the pilot lands.
- **Required fields are Pillar metric and Target**, per `roadmap-check`. Engine cards are exempt from Target. Theme and Horizon apply only to cards that serve a roadmap row. Initiative, DRD and KPI are derived, never typed. My earlier pulse flagged Theme and Horizon on every card, which was wrong.

**Two repo fixes would tighten this.** Both are your call:
1. **Merge PR #610** (`maintain` and the maintenance doc) after rebasing it (41 commits behind) and fixing "Green means done" to the `ship` skill's meaning. Until then, jobs read it from the branch.
2. **Update the `stale` skill**, which still says `make stale` doesn't exist.

## The builder

**The role.** An engineering lead for a short-handed team. It finds problems worth solving, shapes them into small, safe builds, proves them, and hands the good ones to their owners in the owners' format. Like Lauren's "matcha", it splits the work and never builds. The building happens in build workspaces on your Mac, either headless or with you driving Claude in Cursor, the way you built the image extractor.

**What it borrows:**

| Practice | Source | How it shows up |
|---|---|---|
| Verification is the job | Lauren, pstack | every build has `VERIFY.md` and `./verify` (`seed`, `run`, `screenshot`, `check`). It fails until "done means" is true. After each job, `cos-run` runs it before and after the change, and an independent verifier runs the code (see Verification and evals). |
| The autopilot ladder | Lauren | investigate → prototype (sandbox) → candidate (draft PR in the owner's repo). Production is never an agent's rung. |
| Reproduce first; restate; two failures then stop; principle, not incident | Lauren | `build-lane.md` and the engineering standard |
| A checker in its own context | the team guides | a fresh Claude checker, plus a **second opinion from a different model family** (Codex via Cursor) on the diff |
| State in a file, fresh sessions | your image-extractor habit | `HANDOFF.md` per build, a fresh session at every phase boundary |
| The repo's rules win | food-enrichment `AGENTS.md`, data-org | `make check`, package boundaries, changelog fragments, DADRs, `Tile: #n` |
| Canon never crosses the wire | David, 2026-10-08 | the gate and `lake-query` block non-aggregate canon reads. For the ontology, code runs on canon locally and reports aggregates, and Amiah reviews the values. |

**The pipeline:** opportunity (scored, at most 3 proposed weekly, only from work on a board card) → `BRIEF.md` and `VERIFY.md` (your yes) → build (pair or headless, at most 2 active) → proof (`./verify` fail-to-pass, the verifier at live- or test-verified, the checker passes) → candidate (summary, DADR when there's a real choice, a draft PR prepared to the owner's repo rules) → your yes on the batch hash → the owner merges and operates.

**Safety, in three layers:**
1. **Hard walls in every mode**, including when you drive: secrets; writes to shared databases or the lake; Terraform, CDK, Amplify, kubectl, Helm and AWS writes; publishing packages and running deployments; force-push; pushing to `main`; non-aggregate canon reads.
2. **Outward actions** (push, PR, issue, board, Slack, outbound HTTP, deletes) are blocked in headless jobs and staged for your hash approval. In pair mode they ask you in the session.
3. **Approval by hash.** `apply` accepts a push only for a `name/branch` build branch, never `main`, and a PR only as `--draft`. It runs each batch once, exactly as you reviewed it.

**Its first portfolio**, from the live board:
- **#651 IQA low-confidence flag** (Nicholas, Nov 25), with Matt's golden-set harness. The best first build: dated, read-only, and easy to verify.
- **#650 Pantry publish** (Nicholas, Nov 30). Investigate first, then a draft PR to `food-enrichment` only if Nicholas asks.
- **#156 and #374, the Slack and Zendesk agents.** Test channel and test project only.
- **P020 ontology** (#665, rulings #582–#585). Aggregate-only tooling.

## Context windows and history: what to watch

There are three different "memories". Each needs different care.

**1. Grok Bots.** Each Bot has one conversation. Grok keeps its lasting rules, important facts and summaries in memory, so it doesn't replay every message (per Grok's docs). Earlier posts measured 75–88% of tokens going to re-reading; treat that as the cost of long conversations, not a reason to restart them.
- **The playbook lives in skills, not memory.** Skills are versioned in your kit, survive a Duplicate, and are the thing KEEPER edits. Memory holds only the short REMEMBER block.
- **Duplicate carefully.** A duplicated Bot keeps its skills and routines but not its memory, so re-send the REMEMBER block.
- **Fast-changing facts are never remembered.** Status, owners and dates are always fetched. Once a month, ask each Bot what it remembers and remove anything stale.
- **Scheduled reports are short.** Webhook bodies are capped, and `NO CHANGE` runs aren't sent at all.

**2. Claude and Cursor sessions on your Mac.**
- **`cos-run` jobs never accumulate.** Each job starts fresh and the checker runs with no history. A multi-step job can continue with `--resume <id>`, but that's opt-in and per job.
- **Your own Cursor sessions do.** Your image-extractor session is one conversation over 3 days, 62 MB on disk, and has auto-compacted 11 times. It keeps working, but each compaction summarizes older turns, and detail gets lost each time. You already have the fix in `HANDOFF.md`: at each phase boundary, ask Claude to update `HANDOFF.md`, then start a **fresh** session with `@HANDOFF.md`. You get sharper context, cheaper turns and less drift.

**3. Files on disk.** These never enter a context window unless something reads them.
- `~/.claude/projects` is 249 MB of transcripts. That's harmless. Claude Code cleans old transcripts on its own schedule (the `cleanupPeriodDays` setting). Raise it if you want to keep them longer.
- `~/cos/outbox` grows one folder per job. `cos-run` moves folders older than 30 days to `~/cos/archive` on its own. Nothing is deleted.
- Auto-memory files: once a month, run the `consolidate-memory` skill.

**Bottom line:** you never need to purge for capacity. You need one habit: **fresh Cursor sessions from `HANDOFF.md` at phase boundaries.** The Grok side is handled by keeping playbooks in skills and reports short.

## Rollout

1. **Install and test** (INSTALL.md): `./install.sh --online`, then a live `quick`, `investigate`, and a blocked action, then `cos-run eval core current` for baseline scores.
2. **Handbook.** Fill in `people.md`, `workstreams.md` (each workstream points to its `HANDOFF.md` or card) and `sources.md`.
3. **Week 1: Chief, OPS, STEWARD.** Set the Mac execution setting to Ask every time and add the Custom Rules. Send each Bot its REMEMBER block, save its playbook skill, create its webhook routine, and put the webhook key in the Keychain. Then `./install.sh --schedule`.
4. **When you pick the first build: BUILDER.** #651 is the best first build.
5. **After two weeks: KEEPER.** Its first audit replaces the old Friday receipt. Cut whatever you wouldn't miss.

## Honest limits

- Your Mac must be awake for any `cos-run` job. Scheduled runs it slept through are skipped and reported as MISSED, never replayed late.
- Grok doesn't document a way for one Bot to read another's conversation. KEEPER works from receipts and the corrections you record, so a correction you don't record is a lesson it can't learn.
- The eval suite is five cases. It catches regressions in behavior that matters (walls, evidence, stewardship), not every nuance. Grow it from real failures.
- `cos-run eval` and the verifier cost money: about $20 for a baseline eval, and about $6 per build job for checking. KEEPER's scorecard shows it.
- The receipt's `structured_output` field and Cursor's `--trust` flag in headless runs are verified by the smoke test, not before it.
- The data-org skill sets differ between Cursor (28) and the Claude plugin (18). Claude jobs read `handoff`, `orient`, `draft-drd` and `draft-dadr` from `.cursor/skills/` by path.
- I couldn't watch Lauren's videos. What I adopted comes from Lauren's published pstack repo and the posts' quotes.
