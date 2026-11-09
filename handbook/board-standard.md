# Board standard: what the Steward enforces, and where each rule lives

The data-org repo already defines the board. This file doesn't add rules. It points to them, records the mandate, and lists the few calls Cassidy has made. When this file and the repo disagree, the repo wins.

## Order of authority

1. The live issue body
2. `Makefile` and `scripts/dataorg.sh` (they win over skill text)
3. `docs/2026-10-12-work-system.md`: the rule (cards, lanes, the daily log, roadmap fields, skills)
4. `docs/2026-10-29-commands-by-cadence.md`: which target runs when (David's proposal for November)
5. `docs/2026-10-29-board-weeding.md`: weed, intake holders, lane order, the status box
6. `docs/2026-10-30-board-maintenance.md` and `.cursor/skills/maintain/SKILL.md`: the cold start. PR #610 isn't merged, so read these from `origin/cassidy/375-board-maintenance`. Ignore "Green means done". Its "Picture on 2026-10-30" is history.
7. The skills: `day`, `board`, `stale`, `sub`, `park`, `card`, `ship`, `log`, `pr`, `maintain`. The `stale` skill still says `make stale` doesn't exist. It does. Trust the Makefile.

Always read from `origin/main`. Never from Cassidy's working checkout, which may be on a feature branch.

## The mandate (from the Nov 3–6 calls)

- David hands roadmap and visibility work to Cassidy and Melanie: "Melanie and Cassidy are now doing this. Don't bother me." and "the keys of the kingdom in your capable hands." (roadmap session, Nov 6, 15:19:31, 15:35:50)
- Cassidy is "driving to" reconciling the sheet and the board (workshop, Nov 5, 15:29:30). He is "gonna merchandise what we do" (Nov 6, 15:22:43).
- "All of our items that are in the board are fully and explicitly representative of what we have in the roadmap through the end of the fiscal year." (Cassidy, Nov 6, 15:18:44)
- Cassidy sends each person a to-do list so their cards line up with the new fields (Nov 6, 15:27:03).
- The maintenance doc: David handed Cassidy and Melanie the board helpers.
- The gardener tends the board and the log. The person on the card makes the move. (work-system doc, "Shared consciousness")

## What the Steward checks, and which target says so

| Rule (source) | Readout |
|---|---|
| A daily log, `Did / Blocked / Next`, on each card worked that day (work-system, `log`) | `make stale`: no comment or PR event in DAYS days. A field edit isn't an event. |
| RAGB is the one hand-set field. The owner sets it daily. RED = blocked on a named dependency or a date at risk. AMBER = ready or awaiting a position. GREEN = in flight and on track. BLACK = dropped. (`ship` skill, weeding doc) | `make ship-check`, for the daily colour pass |
| One assignee, who is the owner. Active cards with no owner or 14 days of silence get an owner or a drop. (work-system, weeding doc) | `make weed` |
| Discovery, Defining and Shipping cards carry a Pillar metric and a Target. Engine cards need no Target. A card on the gap list doesn't move lanes. (work-system, "Roadmap fields") | `make roadmap-check`, gap list |
| A card's Target matches its milestone (the roadmap row's date). Resolve drift the same week, one way or the other. | `make roadmap-check`, drift list |
| Theme and Horizon go only on cards that serve a roadmap row. A blank Theme means the card isn't on the roadmap. A sub-item takes its parent's Pillar metric. | the PMC · Roadmap and PMC · Pillars views |
| Initiative, DRD and KPI are derived and never typed. A missing one is a context request, not a card. (weeding doc, `day`) | not checked: `make board-fill` is proposed, not built |
| Dropped is not a backlog: `Dropped: why we can't do it today. Bring it back when…` (work-system, `park`) | `make weed`, then a move to Dropped with `make set-pillar` (park is outdated, Nov 1) |
| Zendesk reports are never cards. They hang under intake holders. Never bulk-close them, because a close notifies the customer. (weeding doc) | `make intake-holders`, `make intake-sweep` (dry run) |
| Delivered means it's in ops stores and in prod (David, Nov 3, 15:05:19). Data-flow work has a golden test set (David, Nov 5, 15:38:14). | a Steward check in the Friday packet |
| The board matches the roadmap through year end (Cassidy, Nov 6) | `make roadmap-check` plus a read of the Data Roadmap sheet |

## Cadence (commands-by-cadence)

| When | Targets | Who acts |
|---|---|---|
| Before the ops meeting | `make stale`, `make ship-check` | the meeting starts from the stale list |
| End of each person's day | `/data-org:day`, then `make ragb` | the person on the card |
| Friday | `make weed`, `make raqs`, `make ship-reconcile`, `make intake-sweep`, `make socialize`, `make stale DAYS=7` | `EXECUTE=1` steps need a yes |
| Before a promote | `make roadmap-check` | the card's owner |

**"This week"** is the window of the proposed `make week`: seven days of card comments and RAGB values on active cards, grouped by initiative. `make week` doesn't exist yet. The stand-ins are `make socialize` and `make stale DAYS=7`. The weekly note is drawn from that, and nobody writes a second report.

## Daybook

- "Amiah's daybook pilot decides the shape of the daily write. These commands stay the interface until it does." (commands-by-cadence)
- "Daybook is a write surface and reads nothing" (ruling of 2026-09-03 in the daybook repo, quoted in the weeding doc).
- So the Steward uses the make targets as its interface and doesn't feed Daybook. When the pilot settles the daily write, the Steward adapts to it.

## Boundaries (maintenance doc, CONTRIBUTING)

- Never approve, merge, close or reopen a PR. Never rename or delete a branch. Never force-push.
- Never use `park`: drops move to the Dropped lane (Cassidy's ruling, Nov 1). Never use `make promote` to move a lane, because it closes the issue; a card closing as done uses `make complete CARD=<n> WHY="..."`. Don't invent a P-id. Don't edit `context/`.
- No personnel, compensation or individual performance on a card, in the repo, or in a team channel. Team numbers are fine. Per-person lists go only to that person and to Cassidy.
- Don't post to Slack. Don't send email. Drafts only.
- Touch only the cards the approved plan names. Re-read the live issue before any write. One log a day: edit today's comment rather than adding a second.
