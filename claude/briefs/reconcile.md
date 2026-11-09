Task: reconcile the board with the Data Roadmap sheet.

Run make roadmap-check. Read the Data Roadmap sheet (read-only; tab 'Data Roadmap'; columns C Theme, D Target,
E Horizon, I Pillar metric). For each live row through Dec 31: its milestone, the cards under that milestone, and any
disagreement in Theme, Horizon, Target or Pillar metric. For each drift row, say which side should move (the card's
Target to the milestone, or the row and milestone to the card) and why.
Cards Cassidy owns: make field lines in apply.sh. Others: a note to the owner. The sheet: paste text with the exact
cell. Rows with no card, and roadmap cards with no row, go in their own list.

Done means: reconcile.md and (if any) apply.sh in the job folder.
If the gap and drift lists are identical to the last reconcile in ~/cos/outbox, set summary to exactly: NO CHANGE
