# STEWARD skill: roadmap-board

Install: in STEWARD's chat, send "Save everything under SKILL as a private skill called roadmap-board. Use it for any
work on the Data Roadmap sheet, Project 1, Product project, Window, the Pillar Metrics tab or the roadmap-check lists."
Then paste the SKILL section.

Source: the BOARD agent's handoff, `~/Documents/Data-Org-Repos/data-org-agent-handoff.md`, sections 1 to 4, trimmed to
STEWARD's role. ZoomMirror copies the whole file to `~/cos/handbook/board-handoff.md`, so jobs always read BOARD's
current version, including its "State" section. When the two disagree, the handoff on the Mac wins; tell the Chief
this skill needs a refresh (KEEPER owns that).

## SKILL

ROLE
  You prepare; the Chief runs after my yes. Every proposal is a diff table first: each card, field, link and sheet
  cell that would change, its old and new value, and the owner. At most three numbered questions, each with options,
  your recommendation first. After a write the job reads it back and says what it checked and what it didn't.
  Current state (open PRs, cards in flight, open items, dates) lives in ~/cos/handbook/board-handoff.md on my Mac.
  Ask the Chief for a cos-run quick read of it; don't rely on memory for state.

PROJECT 1, "Data Org Initiatives" (wisecodeai). Resolve field ids by name at run time.
  Status: Intake, Discovery, Defining, Shipping, Delivery Prep, Delivered; terminal Completed No Delivery, Dropped.
  Pillar metric: "FoodTruth · FT1 Ingredients parsed" ... "Health outcomes · H1 Not yet defined", plus
    "Enables · <code>", "Enables · all", "Engine". Engine hides a card from the PMC views.
  Product project: 1 Relevance, 2 Ingredient truth, 3 Health outcomes, 4 Nutrient testing, 5 Contaminant testing.
    Set by make field from the Pillar metric. The board UI does NOT fill it: a metric set in the UI leaves it blank,
    and the make roadmap-check project list catches those cards.
  Theme, Horizon, Target (a date), Window (an iteration: Nov 2026, Dec 2026, Q1 2027).
  Views: 1 Lanes; 11 PMC · Roadmap; 12 PMC · Pillars; 13 Product projects.
  Repo milestones (data-org): Nov 25, Dec 31, Jan 31, Feb 28, Mar 31. A milestone carries the roadmap row's date;
    Target carries the card's own date. Drift = the two disagree.
  Commands: make set-pillar (moves a lane, closes nothing), make board-add, make field (keeps a set value unless
    REPLACE=1), make roadmap-check [CARD=n] (gap, drift and project lists), make complete. Never make promote to move
    a lane: it closes the issue. DRY_RUN=1 first, always.

DATA ROADMAP SHEET (1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM), tab "Data Roadmap" (sheetId 0)
  Read only the tab named exactly "Data Roadmap". "Copy of Data Roadmap 1" is a stale copy: never read or cite it.
  People re-sort it by hand. Find a row by its name in column A, never by a row number.
  A item · B Status · C Theme (a board Theme option, spelled exactly) · D Target Date YYYY-MM-DD · E Horizon ·
  F Release Tier · G Persona · H is_EN40 · I Data Org Responsible (the Pillar metric, exactly as the board option) ·
  J Github Reference (rich-text links, one per card, or "No card") · K Product project (a per-row FORMULA reading I;
  never type into it, except "5 Contaminant testing" on a contaminant row) · L Summary · M Artifact.
  Columns N to AA are older planning flags (Priority, Effort, Feasibility, ...); AB:AC is the Horizon-windows lookup.
  Rows under "Outside current roadmap (EXTRA's)" are off the roadmap through Mar 31, 2027.
  Never propose a column insert: it shifts letters that formulas and docs name. Insert rows.

PILLAR METRICS TAB (sheetId 1100). Headers on row 6; one metric per row, 7 to 16.
  A Code · B Pillar · C Product project · D Metric · E What counts · F Target text · G Status (formula) ·
  H Rows that move it (formula) · I Rows that enable it (formula) · J the column-I value · K Target value ·
  L Target date · M Current · N As of · O Verdict (formula). Insert with insertRange on the table rows only.

METRICS AND CHRIS KNOCH'S FIVE PRODUCT PROJECTS (named Nov 9; the map is Pillar Metrics column C and
scripts/product_projects.json in data-org; they change together)
  FT1, FT2 -> 2 Ingredient truth. FT3 -> 1 Relevance. N1, N2 -> 1 Relevance (base layer; Cassidy, Nov 10).
  V1, V2, V3 -> 1 Relevance. N3 -> 4 Nutrient testing. H1 -> 3 Health outcomes.
  Contaminant testing -> 5, set by hand; a new FT4 metric needs David and Melanie.
  Choosing a metric: (1) the code whose number the work's finish changes; (2) if none, Enables · <code>;
  (3) Enables · all only for platform work serving every metric; (4) Engine for how the team runs;
  (5) nothing fits: leave it blank and say so. A sub-item takes its parent's metric.

CHECKS TO RUN ON EVERY RECONCILE
  - Theme in C is a real board option (a typo like "Esential 40 Coverage" matches nothing).
  - Live rows with no Theme, no metric in I, or "No card" in J: a list for me, with the likely card if one exists.
  - Cards with a Pillar metric but no Product project (the board-UI gap).
  - Drift between Target and milestone, with which side should move and why.
  - Row K disagreeing with the Pillar Metrics map.

PUTTING AN ITEM ON THE ROADMAP (prepare it; the Chief runs it after my yes)
  1. Find the card first: search issues across every wisecodeai repo, read parents and sub-issues. A tracking card
     fits a row when all its sub-issues serve one product project. Bundles #654 to #657 often hold a "No card yet".
  2. Find the row by name; if missing, propose a new live row placed by date.
  3. The diff table: cards to create (owner, parent, blocked-by, lane, every field, milestone) and the sheet cells.
  4. After my yes the Chief runs it. Body of a new card: lane and finish line first, "## Milestones" checkboxes, the
     DRD or "none exists", related cards, parent, roadmap row.
  5. Verify: make roadmap-check CARD=<n> per card and the full lists; read the row back.

TRAPS
  - The GitHub API limit (5,000 an hour) is shared with my other sessions. "unknown owner type" from gh project
    means it's near the limit; check gh api rate_limit before a batch.
  - Grouping and date-field view settings are UI-only. Say so; don't plan an API change for them.
  - A milestone change bumps an issue's updatedAt (it shows as activity on make stale). Field edits don't.
  - Closing an issue can notify a customer (zendesk-sync). Never propose a casual close.
  - Until PR #735 merges: make set-pillar IN=food-enrichment needs IN=wisecodeai/food-enrichment, and make field takes
    Product project and Window only on the #735 branch.
  - Makefile .PHONY conflicts: PRs that each add a target merge in order and rebase.
  - Batch board changes: snapshot first, guarded writes that only set a differing value, re-dump and diff every
    other field (zero changes expected). A batch that fails midway with "Something went wrong" is safe to rerun.

OWNERS
  Another person's card gets a field value or a link with my yes, never a body edit or a comment. Their decisions
  are theirs: tell me who to ask. Never touch Nicholas's food-enrichment pipeline code.
