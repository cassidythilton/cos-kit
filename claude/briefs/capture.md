Task: capture Cassidy's day onto the board (the day skill), as a reviewable batch.

Cold start with the maintain skill (PR #610's branch until it merges). Then use the day skill on Cassidy's day:
today's ~/meetings notes and ~/cos/zoom transcripts, PRs he opened or merged in wisecodeai repos, his Slack
threads with a commitment, and changed HANDOFF.md files in his projects. One plan row per outcome (log / card / sub /
pr / drop / context-request), per the work-system table. A drop is a move to the Dropped lane with make set-pillar, never park.
Logs follow "The day" in docs/2026-10-12-work-system.md. For each of his own cards he worked today, write one log
body file in exactly these three lines and nothing else:
Did: <what moved, with its source>
Blocked: <the blocker, even when another team owns it, or none>
Next: <the next step>
Skip a card with no work today. Detail about a sub-item goes on the sub-item; the card log links it. Then the
apply.sh lines (make ragb after each log, per commands-by-cadence).
Lane moves, on his own cards only: make set-pillar CARD=<n> TO=<lane>, only where today's evidence shows the work is
now in that lane. set-pillar checks no gate, so first run make roadmap-check (a card on its gap list does not move)
and check the promote bars ("Promote a card"): done for the next step named, relevance current, sequence clear,
priority named, Pillar metric set, and a Target for a move into Shipping. Each move is its own apply.sh line; notes.md
cites its evidence and each bar. A finished task is make complete CARD=<n> WHY="...", not a move. A drop stays make
set-pillar TO=Dropped.
notes.md also gets two sections. "Touched, no log": each card that came up today with no log staged, where it came
up, and why no log. "No card": each piece of work with no card, its source line or transcript timestamp, and the
likely card or a proposed gh issue create.
Work by others that has no card: a draft note to its owner. Re-read every live card before you plan a write.
Never write on a card someone else owns: no log, lane move or RAGB there; it becomes a nudge or a note. Throughput
stays at team level: no sums per person.

Done means: plan.md, notes.md, the log body files and apply.sh in the job folder; summary "Capture: N rows. Batch
<sha256>: K writes on your cards (G logs, L lane moves). U touched with no log. C with no card. P notes for others."
If there is nothing to capture today, set summary to exactly: NO CHANGE
