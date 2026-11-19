# Memory manager

What it is: one place on the Mac that holds what the Bots should remember, and makes each Bot's remember block from
it. It's change 11 in `docs/plan-2026-11-19-lean-on-agents.md`. The tool is `claude/cos-memory`. It runs no model.

## Why

Memory lived in six places that never agreed. The Chief's remember block grew to about 19,000 characters, with the
same rule said three ways and old facts nobody checked. Stale memory caused the Nov 19 "overdue" message.

## What it keeps, and what it refuses

| Kind | What | How long |
|---|---|---|
| Rule | How Cassidy wants things done. "Drafts only for Slack and email." | Until he changes it. |
| Fact | People, systems, decisions. "Jeff leads the app team." | Until its review-by date (90 days by default). Then the weekly cleanup retires it unless someone re-checks it. |
| Open item | Anything still waiting: a review, a reply, a follow-up. | Refused. Open items are read live from the Mac's one list, so they're never stale. |
| History | What happened: a run, a message sent, a webhook result. | Refused. It stays in the ledgers and Agent Atlas, looked up when needed. |

Every entry has: `id` (r-… for a rule, f-… for a fact), `kind`, `text` (plain words), `bots` (a list from chief, ops,
steward, builder, keeper, claude, or "all"), `source` (where it came from), `added` (date), `review_by` (facts only),
and `status`: proposed, active or retired. Some entries also carry `pin` (always in the block), `replaces` (the entry
it takes over from on accept), `merged_from`, `retired_reason`, `decided`, `notes` and `imported`.

## Where it lives

`~/cos/memory/entries.jsonl`, one entry per line, in its own small git repo. The first command creates it. Every
change is one commit, so any change can be undone: `cos-memory undo` reverses the last one with a new commit (so the
undo can be undone too), and `cos-memory history` shows the log. Nothing else writes this file.

The tool refuses text that looks like a key, token or signed URL, and never prints one back.

## How a memory gets in

1. Someone proposes it: `cos-memory propose "<text>" --kind rule|fact --bots chief,ops|all --source "<where>"`. A fact
   can take `--review-by YYYY-MM-DD`. A rule that takes over from an old one can say `--replaces <id>`; accepting it
   retires the old one. `--pin` marks a hard line that must always be in the block.
2. Cassidy says yes or no: `cos-memory accept <id> ...` or `cos-memory reject <id> ...`. Only active entries reach a Bot.
3. `cos-memory retire <id> --reason "..."` takes one out later. `pin` and `unpin` change the pin.

A proposal that says the same thing as one already in the store is refused, with the id of the one that's there.

## The one-time import

`cos-memory import` seeds proposals from the five remember blocks (`~/cos/grok-live/after/<bot>-remember.md`) and the
corrections ledger (`~/cos/state/ledger/corrections.jsonl`). It:

- splits long memories at sentence ends into pieces of about 450 characters, keeping a sentence that leans on the one
  before ("it", "this") with it;
- folds obvious duplicates into the first one (their Bots are added to it), and notes likely ones ("may say the same
  as r-…; accept one, reject the other");
- guesses rule or fact: corrections are rules (a correction about one card is a fact), lines that say never, always,
  only, must and the like are rules, the rest are facts;
- pins the hard lines it recognizes (drafts only, never repeat a key, access is never authorization, he/him, the one
  door, never merge);
- leaves out, and lists as NOT imported: open items, dated one-offs (waivers, "this morning", webhook results with a
  time stamp) and history ("I sent…");
- marks memories the export cut off ("the end is missing").

Everything comes in as proposed. Nothing reaches a Bot until it's accepted. It runs once; `--force` runs it again.
`--remember-dir` and `--corrections` point it at other files.

A dry run against the Nov 19 files gave 150 proposals (124 rules, 26 facts), folded 14 duplicates, and left out 12.

## Making a remember block

`cos-memory render <bot>` writes `~/cos/grok-live/apply/<bot>-remember-<YYYYMMDD>.md`, which Cassidy pastes into
that Bot. `--out <file>` writes elsewhere; `--out -` prints it. The block:

- holds only that Bot's active entries (its own plus "all");
- puts rules first, then facts; pinned entries first, then newest first;
- stays under 6,000 characters. When it doesn't fit, the oldest unpinned facts go first, then the oldest unpinned
  rules. The block says how many were left out, and render lists their ids. Pinned entries never go; if they alone
  pass the cap, render stops and says so.

On the Nov 19 import, accepted whole, the Chief's 92 entries don't fit: 69 are left out. That's the signal to reject
and merge during review, not to raise the cap.

## The weekly cleanup (KEEPER)

`cos-memory clean` does four things and writes one short report:

1. Merges duplicates: the same words, or nearly (85% of the meaningful words shared). The newer wording stays, with
   both entries' Bots; the other is retired as "merged into r-…".
2. Retires facts past their review-by date.
3. Flags possible contradictions, and changes neither: two entries about the same thing (half their meaningful words
   shared) where one says never, off, disabled or don't and the other says always, on, enabled or must. It's
   deliberately cautious; Cassidy settles each one.
4. Lists facts whose source or text points at a GitHub card or PR (a link, or `repo#N`), so a later step can check
   whether that card is still open and that person still the owner.

The report goes to `~/cos/outbox/memory-clean-<YYYYMMDD>/receipt.json` in the kit's receipt shape:
`{"job","lane":"memory","receipt":{"status","summary","open_questions",...}}`. The summary reads "kept / merged /
retired / needs Cassidy"; each possible contradiction and the count of waiting proposals is an open question. Details
are under `receipt.memory`. `clean --dry-run` prints the same report and changes nothing.

## Status

`cos-memory status` shows, per Bot, its active rules and facts, its proposals waiting, and its block size against the
cap, plus facts due for review in the next 14 days. `cos-memory list [--status] [--kind] [--bot]` and
`cos-memory show <id>` look at entries.

## Tests

`claude/tests/test-memory.sh` runs everything against a temporary home and checks the real `~/cos/memory` isn't
touched. Run it alone with `bash claude/tests/test-memory.sh`, or `source` it from `install.sh`, which supplies
`pass`, `fail` and `$KIT`.

## Not done yet

- A `cos-run memory …` lane to call it from the Bots, and a KEEPER schedule for the weekly clean.
- The GitHub re-check of the facts clean lists.
- Feeding Claude Code's memory and the cassidy-mode skill from the store (render works for `claude`, but nothing
  installs it).
- Turning a correction that recurs into a check (the rule ladder), and the Friday brief's memory measures.
