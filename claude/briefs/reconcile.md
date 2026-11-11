Task: reconcile the board with the Data Roadmap sheet.

Read first: ~/cos/handbook/board-handoff.md (the BOARD agent's handoff: the fields, the sheet's columns, the metric
rules, the traps, and its current state). Where it and the Makefile disagree, the Makefile wins.

Run make roadmap-check (gap, drift and project lists). Read the sheet (spreadsheet 1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM),
only the tab named exactly "Data Roadmap" (never "Copy of Data Roadmap 1") and the "Pillar Metrics" tab. Find rows by
the text in column A, never by an old row number. For each live row through Dec 31: its milestone, the cards under it,
and any disagreement in Theme (C), Target (D), Horizon (E) or Pillar metric (I). Also check:
- C is spelled exactly as a board Theme option;
- live rows with no Theme, no metric, or "No card" in J (name the likely card if one exists);
- cards with a Pillar metric but no Product project;
- K disagreeing with the Pillar Metrics column C map.
For each drift, say which side should move and why.

Outputs. Cards Cassidy owns: make field lines in apply.sh. Others: a note to the owner, never a write. Sheet cells
Cassidy owns the decision on: sheet.json, one entry per cell with tab, row (as read now), row_name (column A as read
now), col, old (as read now) and new. Never column A, J or K. J links go in reconcile.md as paste text. Rows with no
card, and roadmap cards with no row, go in their own list.

Done means: reconcile.md and, if any, apply.sh and sheet.json in the job folder.
If the gap, drift and sheet-check lists are identical to the last reconcile in ~/cos/outbox, set summary to exactly: NO CHANGE
