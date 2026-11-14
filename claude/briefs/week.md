Task: the Friday weekly pass (commands-by-cadence, Friday), the packet for Cassidy and Melanie.

Run, in order: make weed, make raqs, make ship-reconcile, make intake-sweep (dry run), make socialize,
make stale DAYS=7. Write the weekly note from the 'make week' window: seven days of card comments and RAGB values on
active cards, grouped by initiative. Proposed dispositions as handoff-skill previews. EXECUTE=1 steps are listed for
David's or Cassidy's yes, never run. Add the definition-of-done check: cards in Delivered that aren't in prod, and
data-flow cards with no golden test set. Add the trend from ~/cos/state/board-health.csv (team numbers only, never
per person).

Done means: week.md in the job folder, under two pages.

The roadmap method is data-org's `roadmap` skill (the single source; BOARD uses the same file):
~/cos/data-org-main/.cursor/skills/roadmap/SKILL.md. Until PR #735 merges it isn't on main; read it with
git -C ~/cos/data-org-main show origin/cassidy/roadmap-skill:.cursor/skills/roadmap/SKILL.md.
Open items: read the "State" section of ~/cos/handbook/board-handoff.md. For each open item nobody has started, one
line: what it needs, who decides, and the proposal. Where Cassidy decides, stage it (apply.sh for cards, links and
fields; sheet.json for cells). Where someone else decides, a drafted question to them. Never a write on their card.

Throughput and definition debt (plan items 8 and 9). Read flow-week.md in the job folder first: cos-flow staged the
board facts there (read-only), from GitHub's own lane-move history. Put in week.md, with numbers as given:
- Throughput: forward and back moves, finishes (Completed No Delivery, Delivered), drops, median days in Defining and
  in Shipping, and the cards in one lane past 14 days. Next to it, the lane counts as the Lanes view shows them, and
  the board-health.csv trend. Team numbers only, never per person. Moves back count as much as moves forward.
- Definition debt: cards in Defining with no DRD; DADRs still proposed or past review_by; DRDs past review_by;
  drafts whose open boxes don't map to a RAQ (make gate); doc PRs with no reviewer; any ID two open PRs claim.
- Evidence lines and No Status cards, each in its owner's list. No bot moves another owner's card.
If flow-week.md says the board facts were not read, say so first and leave those sections out.
