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

DRDs and DADRs (plan item 8). Read flow-capture.md in the job folder first: cos-flow staged the board facts there
(read-only). For each card worked today it gives the card's DRD line, the DRDs and DADRs on main and in open PRs,
and the structural rows of PR #524's four-row check. PR #524 is open, not merged: say "per PR #524 (open)" when you
use the check. Apply the check to each card worked today, and only to those:
1. Enters Defining, or other teams build on the data: a DRD sub-item, when the card has no DRD.
2. Two or more real options, or a choice that needs a decider: a DADR card in Defining. Read today's comments,
   transcripts and Slack for this row; cite the line or the transcript timestamp.
3. Changes an existing DRD: a PR that amends that DRD.
4. A question, a probe, a readout or a one-team task: no DRD, one sentence on the card.
Never propose a second DRD for a requirement that already has one (read the DRD line and drd/ first). Each row you
add states its signal in one line; a card with no row says why in one line. Cassidy's cards: a row in plan.md that
offers a draft (the Chief runs cos-run draft <job> "<brief>" --doc drd|dadr --card <card>). Others' cards: a line in
that owner's to-do list in notes.md, never a draft of their doc. Never stage a status change to Approved or accepted.
notes.md gets a section "DRD and DADR check" with one line per card worked today.

Lane evidence (plan item 9). flow-capture.md also lists "evidence says #N can move to <lane>" lines and open cards
in No Status. Copy each line for another owner into that owner's to-do list in notes.md, with its link. Never stage a
lane move on another owner's card. For Cassidy's own cards, a move goes in apply.sh only when the evidence is on
GitHub and the promote bars hold, as above; a finish is make complete, never make promote.
