# Plan: a smoother chief-of-staff experience (approved 2026-11-14)

Cassidy approved this plan on 2026-11-14 in Claude Code. Read `HANDOFF.md` first. Everything stays on his Mac; the
goal is that working with the Chief feels as smooth as Cursor: fewer stops, fewer rituals, fewer scares.

## Build order

1. Items 1, 2, 4 and 6, in one build: Mac-side, each with installer tests, and a live check on one of Cassidy's own
   cards.
2. Then items 3 and 5, which come with exact text for Cassidy to paste into Grok.

| # | Change | Blocked by | Done when |
|---|---|---|---|
| 1 | GitHub tiers (below) | nothing | a week of tier-0 changes, each in the evening brief and the ledger with its undo |
| 2 | Approve with "yes": the Chief shows a batch in plain words; his "yes" applies it; the sha256 is checked behind the scenes, never shown | nothing | he approves a real batch by saying "yes" |
| 3 | Fewer cards: quick, investigate, atlas, gh-scan, receipt and the tier-0 lane go on Grok's always-allowed list; cards remain for apply, land and pushes | a Grok permissions change he makes | a day of lookups with no card |
| 4 | Fewer failures: `cos-run <lane> --help` with examples; refusals print the correct call; verdicts VERIFIED / NOT VERIFIED / INCONCLUSIVE. Overnight: the brief says "plugged in, lid open" before he approves; long and async jobs run under `caffeinate -i -s -w <pid>`; an interrupted job's receipt says "didn't finish, rerun?" | nothing | fewer blocked receipts next week than this week |
| 5 | The Chief answers like a person: the answer first; no ids, lanes, shas or checker notes unless asked; speaks up only when he's needed | a paste | five replies in a row need no translating |
| 6 | Subtract: remove the eval and pair lanes, `lake-query` from the bots' lanes, and `~/cos/bin/*.bak*`. Add the lake handoff: Claude writes a prompt, Cassidy runs it in Cursor, and results come back as `~/cos/inbox/<job>/result.md` with aggregates and ids only, checked by the canon tripwire. Correct HANDOFF.md and README: canon stays on the Mac because of chat content, not queries (lake-query never ran in 303 jobs). | nothing | the checks pass with less code |
| 7 | Bonus: Steve Preston (org owner) approves Grok's GitHub app for data-org, data-org-notebook, and read access to org Projects. Requested in Slack 2026-11-14. | Steve | a GitHub read in Grok with no Mac hop |

Dropped for now: cloud agents, moving work to the Grok VM, and retiring the Mac plumbing. Later: Lauren's
agent-compatibility scan of data-org, and moving the walls into data-org's CI.

## Item 1: GitHub tiers (Cassidy's answers: 1b, 2a, 3a)

| | His cards and PRs (author or assignee is cassidythilton) | Anyone's card on Project 1 |
|---|---|---|
| Tier 0: just do it. A line in the evening brief AND a ledger entry with the undo. | labels, assignee, milestone; sub-issue and blocked-by links; board-add; the roadmap fields (Pillar metric, Theme, Horizon, Target); his own lane moves (`make set-pillar`); an issue he dictated; pushes to `cassidy/*`; opening a draft PR and marking it ready | board-add; filling a BLANK roadmap field (`make field` without `REPLACE=1`), only with the value from the card's Data Roadmap row (a sub-item copies its parent's Pillar metric); the value cites the sheet row |
| Tier 1: one "yes" in the chat, text shown inline | comments, review replies, RAGB, `make complete` | replacing a set field (`REPLACE=1`), such as Target drift; linking it as a sub-issue or blocker |
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
