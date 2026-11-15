# Plan: a smoother chief-of-staff experience (approved 2026-11-14)

Cassidy approved this plan on 2026-11-14 in Claude Code. Read `HANDOFF.md` first. Everything stays on his Mac; the
goal is that working with the Chief feels as smooth as Cursor: fewer stops, fewer rituals, fewer scares.

## Build order

1. Build A: items 1, 2, 4 and 6 (Mac-side, installer tests, a live check on one of Cassidy's own cards).
2. Build B: items 8 and 9, which sit on top of the tiers (DRDs and DADRs in the daily flow; throughput).
3. Then items 3 and 5, with exact text for Cassidy to paste into Grok, including the STEWARD, OPS and Chief changes
   that 8 and 9 need.
Work in a fresh Claude Code session. Read HANDOFF.md, then this file, then the data-org sources it names.

| # | Change | Blocked by | Done when |
|---|---|---|---|
| 1 | GitHub tiers (below) | nothing | a week of tier-0 changes, each in the evening brief and the ledger with its undo |
| 2 | Approve with "yes": the Chief shows a batch in plain words; his "yes" applies it; the sha256 is checked behind the scenes, never shown | nothing | he approves a real batch by saying "yes" |
| 3 | Fewer cards: quick, investigate, atlas, gh-scan, receipt and the tier-0 lane go on Grok's always-allowed list; cards remain for apply, land and pushes | a Grok permissions change he makes | a day of lookups with no card |
| 4 | Fewer failures: `cos-run <lane> --help` with examples; refusals print the correct call; verdicts VERIFIED / NOT VERIFIED / INCONCLUSIVE. Overnight: the brief says "plugged in, lid open" before he approves; long and async jobs run under `caffeinate -i -s -w <pid>`; an interrupted job's receipt says "didn't finish, rerun?" | nothing | fewer blocked receipts next week than this week |
| 5 | The Chief answers like a person: the answer first; no ids, lanes, shas or checker notes unless asked; speaks up only when he's needed | a paste | five replies in a row need no translating |
| 6 | Subtract: remove the eval and pair lanes, `lake-query` from the bots' lanes, and `~/cos/bin/*.bak*`. Replace copy-paste with a `cos-run lake` lane (section below); a hand-run Cursor prompt stays as the fallback. Correct HANDOFF.md and README: canon stays on the Mac because of chat content, not queries (lake-query never ran in 303 jobs). | nothing | the checks pass with less code |
| 8 | DRDs and DADRs in the daily flow (section below): PR #524's four-row check, daily and weekly detection, drafts only for Cassidy's cards, `make next-id` re-checked before every push | Build A | a DRD or DADR candidate surfaces from a real day, and a draft reaches a draft PR with no ID clash |
| 9 | Throughput (section below): lanes move on evidence through Status only, never a bot move on others' cards, no No Status cards, lane counts and a Friday readout from GitHub's status-change history | Build A | a Friday brief with forward moves, finishes, days in lane and stuck cards that match the Lanes view |
| 7 | Bonus: Steve Preston (org owner) approves Grok's GitHub app for data-org, data-org-notebook, and read access to org Projects. Requested in Slack 2026-11-14. | Steve | a GitHub read in Grok with no Mac hop |

Dropped for now: cloud agents, moving work to the Grok VM, and retiring the Mac plumbing. Later: Lauren's
agent-compatibility scan of data-org, and moving the walls into data-org's CI.

## Item 1: GitHub tiers (Cassidy's answers: 1b, 2a, 3a)

| | His cards and PRs (author or assignee is cassidythilton) | Anyone's card on Project 1 |
|---|---|---|
| Tier 0: just do it. A line in the evening brief AND a ledger entry with the undo. | labels, assignee, milestone; sub-issue and blocked-by links; board-add; the roadmap fields (Pillar metric, Theme, Horizon, Target); his own lane moves (`make set-pillar`); an issue he dictated; pushes to `cassidy/*`; opening a draft PR (marking it ready is tier 1: it can request reviews, which notifies people) | board-add; filling a BLANK roadmap field (`make field` without `REPLACE=1`), only with the value from the card's Data Roadmap row (a sub-item copies its parent's Pillar metric); the value cites the sheet row |
| Tier 1: one "yes" in the chat, text shown inline | comments, review replies, RAGB, `make complete`, marking a PR ready, requesting a review | replacing a set field (`REPLACE=1`), such as Target drift; linking it as a sub-issue or blocker |
| Tier 2: always ask, with a preview | merges, closes, deletes | lane moves, assignee changes, PR approvals, issue bodies, drops |
| Never | | RAGB (the owner sets it), Initiative, DRD, KPI (derived, never typed) |

Rules for the build:
- Use data-org's own interface. Every board write goes through its make targets (`field`, `set-pillar`,
  `board-add`, `ragb`, `complete`), never raw `gh project item-edit`, except the undo of a filled field (`make field`
  can't clear one). Read the work system and skills before writing anything, from `origin/main`:
  `docs/2026-10-12-work-system.md`, `docs/2026-10-29-board-weeding.md`, `.cursor/skills/{card,sub,ship,log,board,day,promote,park}`,
  `plugins/data-org` (the Claude plugin, `/data-org:*`), and the roadmap skill on
  `origin/cassidy/roadmap-skill:.cursor/skills/roadmap/SKILL.md`. Where the Makefile and a skill disagree, the
  Makefile wins (`handbook/board-standard.md`).
- A `cos-run gh` lane runs tier 0 only, from a fixed list. Before each write: re-read the live card; check
  ownership, or that the field is blank and the value matches the roadmap row; record the old value, the new value
  and the undo command in the ledger. Anything else is refused, naming its tier.
- The Chief's 4:30 sweep adds "Done without asking" to the evening brief from that ledger.
- Before tier 0 touches other people's cards: Cassidy tells Melanie about the blank-field exception himself, and one
  card proves the board stores values exactly as the sheet writes them. Until then, tier 0 is his cards only.
- Rules to update in his words: cassidy-mode ("Others' cards get a note, not an edit") and STEWARD ("never writes on
  another owner's card") each gain the blank-field exception.
- The hard lines don't otherwise change: drafts only for Slack and email; no merges, closes or approvals without his
  yes; never repeat a token.

## data-org's two plugins

- `plugins/data-org` (Claude Code): wraps the Makefile and `gh`. This is the one the tiers follow.
- `plugins/data-org-cowork-plugin` (v0.3.0, for Claude Cowork): drafts DRDs and DADRs and hands back paste-ready
  `make`/`gh` commands instead of running them ("No git, no gh, no GitHub API, ever"). Not used by the bots. Read its
  `day`, `card`, `sub`, `log` skills only as a second statement of the same rules.

## Lauren Tan's plugins to weigh (github.com/poteto/plugins, MIT)

Read each, then adopt the idea where it fits; don't install wholesale. Say in the build notes what was taken and why.

| Plugin | Idea | Where it fits |
|---|---|---|
| `cli-for-agent` | non-interactive flags, `--help` with examples, fast errors that print the correct call, dry-run, idempotency | item 4: `cos-run` and the `cos-run gh` lane |
| `pstack` | principles: encode-lessons-in-structure, subtract-before-you-add, never-block-on-the-human (irreversible still asks), prove-it-works, build-the-lever; skills: `verify-this`-style verdicts, `show-me-your-work` decision log, `reflect` | item 4 verdicts; item 6; the tier-0 ledger can borrow show-me-your-work's one-row-per-decision shape (what, why, evidence, result) |
| `continual-learning` | a stop hook that, every N turns, mines new transcripts and updates learned preferences in place | keeps `cassidy-mode` current instead of a monthly re-mine. Must follow its transcript-scoping rule (only this workspace's transcripts) and never write canon or lake-chat content. Propose; Cassidy approves before it's on. |
| `ralph-loop` | a stop hook re-feeds the same prompt until a completion phrase appears or an iteration cap is hit | overnight builds: run a build until `./verify` passes, with a hard cap and the caffeinate rule from item 4. Only for build-lane work in `~/builds/<slug>`, never for anything that writes to GitHub or the board. |
| `thermos` / `interrogate` | several models review the same diff | already done (Codex plus a Claude checker); no change |

## DRDs and DADRs in the daily flow

The repo already says when the work needs a DRD or a DADR: Cassidy's PR #524 (open since 2026-10-26, no review
yet) adds a four-row check to `docs/2026-10-12-work-system.md` and to all three `day` skills. The bots use that check,
not one of their own. Until #524 merges, read it from its branch, and say so.

| Signal (PR #524) | The plan adds |
|---|---|
| The card enters Defining, or other teams build on the data | a DRD sub-item, when the card has no DRD |
| Two or more real options, or a choice that needs a decider | a DADR card in Defining |
| The work changes an existing DRD | a PR that amends that DRD |
| A question, a probe, a readout, or a task inside one team | no DRD; one sentence on the card |

When the bots look for it:
- Daily (STEWARD, 16:00 capture): only cards worked today, from the board and the Agent Atlas recent-work list. Read
  each card's DRD line and `drd/` first, so nobody gets a second DRD for the same requirement.
- From calls and Slack (OPS follow-ups, 06:15): "we decided X", or "A or B?" with a named decider, is a DADR
  candidate. A decision already made is recorded as discovered (it ends in Completed No Delivery). Cite the
  transcript timestamp.
- Weekly (STEWARD, Friday `week`): definition debt. Cards in Defining with no DRD; DADRs past `review_by` or still
  `proposed` with no vote; Drafts whose open boxes don't map to a RAQ (`make gate`); doc PRs with no reviewer.

Who drafts (owners own their work):
- Cassidy's cards: the bot offers a draft. Others' cards: a line in that owner's to-do list, never a draft of their
  doc. A DADR's deciders are named in it; the CDO ratifies. No job ever flips a status to Approved or accepted.

How a draft gets made:
1. A draft job (`cos-run draft --base main`) follows the repo's `draft-drd` or `draft-dadr` skill. Those are
   interviews, and a job can't interview, so it fills every answer it can source (card, transcript with timestamp,
   Slack, related DRDs), and returns at most three numbered questions only Cassidy can answer: the requirement as a
   commitment, the ranked drivers, the owner.
2. After his answers: `make next-id`, `make scaffold`, the sections, then `make gate` and `make lint-writing`.
   A DRD and a DADR go in separate PRs (the DRD uses `Closes`, the DADR `Refs`, per the work system).
3. Tier 0 pushes it to a `cassidy/<issue>-<topic>` branch and opens a draft PR. Right before the push, re-run
   `make next-id`: if the number is now claimed by another open PR, renumber first. Put the ID in the PR title
   (`DRD-00NN (Draft): <title>`), so people see the claim.
4. Tier 1: marking it ready and requesting the one non-author review a Draft needs.
- What goes to Grok: the title, the ID, the PR link and the questions. Not the doc text. A DRD cites canon tables and
  aggregates, never canon values.

When Cassidy drafts himself in Claude Cowork: its `handoff` skill returns ready-to-paste `make`/`gh` lines. He pastes
the block to the Chief, which runs the tier-0 lines and asks about the rest by tier. The Cowork plugin itself never
runs git or gh.

Found while planning (2026-11-14): DRD-0034 is claimed twice. Cassidy's #681 added
`drd/DRD-0034-label-facts-on-each-packaged-food.md` at 13:46Z on Nov 13; Nicholas's #768 added
`drd/DRD-0034-what-available-means-for-a-food-barcode.md` at 15:17Z. `make next-id` reads open PRs' files, so it
would have flagged it; it likely wasn't run. Whichever merges second fails the gate's duplicate-ID check.

## Throughput (David, PR #704, 2026-11-11)

David: "I depend on the Lanes view to understand throughput." He asked Cassidy for a Makefile pass and a process he
can adopt to keep the Lanes view current. So the system must keep lanes true, using the board's own Status field, and
never at the cost of honesty.

Facts checked 2026-11-14:
- GitHub records every lane move as `ProjectV2ItemStatusChangedEvent` on the issue timeline: from, to, who, when
  (e.g. #630 → Discovery by cassidythilton, 2026-10-31). Throughput can be counted, not guessed.
- Our `~/cos/state/board-health.csv` has stale, weed and roadmap counts, but no lane counts.
- `make board-add` without `PILLAR` leaves Status empty. The board's "No Status" column (5 cards today) is invisible
  to the Lanes view.

1. Lanes move on evidence, through native actions only. Moves use `make set-pillar` (Status), finishes use
   `make complete`. Never `make promote` to move a lane (it closes the issue), never a close from a PR. The evidence
   that earns each move is the work system's lane table (a DRD passes its gate, the deciders choose an option, the
   increment ships and its VRs pass, a consumer can use it).
2. Who moves what (fits the tiers): Cassidy's own cards, tier 0 when the evidence is on GitHub (a merged DRD PR, an
   accepted DADR, a merged ship PR), with the evidence cited in the ledger; `make complete` is tier 1. Others' cards:
   never moved by a bot. STEWARD's daily capture lists "evidence says #N can move to <lane>: <evidence link>" in that
   owner's to-do list. The person on the card makes the move.
3. Every tier-0 board-add lands in a lane: `PILLAR=Intake` for anyone's card unless Cassidy names one for his own.
   Never leave a card in No Status. The daily pulse lists No Status cards for their owners.
4. Measure it, read-only: add lane counts to `board-health.csv` daily (a cumulative-flow line), and a weekly readout
   from the status-change events: forward moves, cards finished (Completed No Delivery, Delivered), median days in
   Defining and in Shipping, and cards in one lane past 14 days. It goes in the Friday `week` brief.
5. Offer it to David as the team's tool, not a private one: once the readout is right for two weeks, propose it to
   data-org as a `make` target (a PR Cassidy owns, David reviews), so David reads throughput from the repo he
   already trusts. Until then the board itself stays the source; the readout only explains it.
6. Don't game it. A lane move without evidence is worse than a stale card. No bot moves a card to make a number
   look better, and the readout counts moves back (Shipping → Defining) as well as forward.

Open for Cassidy: David's three items on #704 (the card is #700; "Parked" vs "Dropped" is Cassidy's call; nobody
owns targets in Pillar metric descriptions now) and his ask for a Makefile pass and a meeting on the Lanes process.
Replying on #704 is a tier-1 comment.

## The lake lane (replaces copy-paste; 2026-11-14)

Cassidy: launching a Cursor agent from Grok, with logging, gates and his approval, beats copy-paste. The bots still
never see the lake; a Cursor agent on his Mac does, and only an aggregates-only result comes back.

- `cos-run lake <job> "<question>"`. Tier 1 with a preview: the Chief shows the question, the tables it expects to
  read and the shape of the answer; his "yes" launches it. Never in tier 0, never on a schedule.
- Engine: Cursor CLI (`agent -p`, as the quick lane already uses), pinned to a Claude model. Canon text never goes
  to a non-Claude model (canon charter decision 14, as the kit reads it). Fallback if Cursor can't be gated as below:
  Claude Code with `gate.sh`, which is already proven.
- Where it runs: a data-org-notebook worktree, reading only through `lake-query` (read-only; `wcx` refuses writes;
  canon tables only aggregated; a LIMIT or `--save`). Needs his VPN and `<env>-laker` sign-in; without them the job
  stops at once with "connect the VPN and sign in", not a failure.
- Gates, to verify in the build: Cursor's own permission config (allow `lake-query`, `uv run`, reads; deny writes,
  network tools, git push, gh) and Cursor hooks running the same checks as `gate.sh`. If either can't be proven
  with refusal tests, use the Claude Code fallback.
- Output: `~/cos/outbox/<job>/result.md`: counts, rates and ids, each with its query. The canon tripwire checks the
  file before anything reaches Grok; a hit holds the result on the Mac and says so.
- Logging: the ledger records the job, the Cursor agent id, the queries run and the tripwire result. Agent Atlas
  indexes the chat (it will be a lake chat), so it can be found again; its content stays on the Mac.

## Grok-side state must survive (2026-11-14)

Cassidy has refined bots, skills and routines inside Grok, and the Chief holds about 94 memory facts he asked it to
remember. The new system must keep them. Nothing in this plan deletes Grok memory or routines, but a paste can
contradict a memory, and a bot reset would lose it.

1. Export first: each bot writes its memory, playbook, skills, routines and the Custom Rules verbatim to
   `~/cos/grok-live/` (the Chief's test run started 2026-11-14 10:01). Check the count (the Chief reported 94 facts).
2. Reconcile: compare with `kit/grokbot/`; Cassidy's live versions win; conflicts with this plan go to him.
3. Sort every memory fact into one of three:
   - a lasting rule: copy it into the kit (`grokbot/<bot>.md` or `handbook/rules.md`), so it survives a reset and
     every pasted version carries it;
   - a fact that changes (owners, dates, status, RAGB): flag it, since the system map says those are fetched, not
     remembered; Cassidy decides whether it stays;
   - a one-off reminder: should be a routine, not a memory.
4. Keep the live export out of git unless Cassidy says otherwise: memory may hold notes about people.
5. Every later paste is written against the live export, and the Chief confirms afterwards that no memory fact was
   contradicted.

The Chief's routines on 2026-11-14 (from Cassidy's screenshot): Morning brief (weekdays ~6:30), GitHub asks watch
(hourly on weekdays, 8:00 to 18:00), SPINS outreach reminder (#630, once Nov 16 9:00), Bird-dog Nicholas items
(fixture, V1 label; weekdays ~9:00), Agent Atlas daily pull (weekdays ~15:45), Daily call action items (pre-sweep,
weekdays ~15:50), End-of-day sweep and reconciliation (weekdays ~16:30), cos-run results webhook. To check in the
reconcile: the Morning brief may duplicate OPS's 06:15 follow-ups and brief; the hourly GitHub watch overlaps OPS's
obligations script (every two hours) and should use one `gh-scan` per run, not several reads.

## Decisions after the Grok export (Cassidy, 2026-11-14: 1a 2a 3a)

1. One morning brief, owned by the Chief. OPS's 6:30 "OPS morning brief" routine is turned off; OPS keeps the
   06:15 follow-ups webhook and the obligations webhook, and feeds the Chief.
2. Every brief, sweep and the hourly GitHub watch makes one `cos-run gh-scan` call, not separate `gh` reads.
3. The eval lane stays (KEEPER tests prompt and skill changes with it before proposing). Item 6 no longer removes it.

Reconcile rules (no decision needed): Cassidy's live Grok text wins over the kit; fold lasting memory rules into the
Chief's playbook so the newest rule also ranks highest; remove stale `~/meetings` references; the automatic revision
round counts as the first of the Chief's three retries; every paste is written against `~/cos/grok-live/`.
Notes: `~/cos/grok-live/RECONCILE.md` (kept out of git).

## BUILDER, two-model diligence (Cassidy, Nov 15: 1b 2c 3a)

After the Nov 15 test (diligence caught #651 on its own; the kill review lost Codex's answer to a parsing bug, fixed in
e5e896a), Cassidy asked for more sophistication on both reasoning and diligence:
1. Claude and Codex (GPT-5.3-codex-high via the Cursor CLI) each run their own blind diligence pass on the candidates.
2. A script compares the two passes card by card (agree CHECKED, agree DEAD, disagree).
3. Cross-examination, one round each: Claude attacks Codex's CHECKED ideas and Codex attacks Claude's; each may concede
   or defend once, with citations.
4. Verdict by script: survives only if both end CHECKED and unrefuted; "contested" goes to Cassidy with both arguments;
   the rest are out, each with its reason.
5. Grok (BUILDER) ranks loosely, as today (decision 2c), over survivors and contested ideas, each labeled; the models'
   consensus order and score lines go with them as advice. BUILDER can't promote an idea that's out.
Decisions: (1b) Codex reads code, PRs, the board, receipts AND Slack, but Slack only as a digest Claude writes and
screens for canon first (the canon tripwire checks it before Codex sees it); transcripts never go to Codex. (2c) Grok
ranks loosely. (3a) Up to $30 per run, all models together.
