Task: find this week's build opportunities for BUILDER. At most three. The board is the gate.

Read, in this order:
1. The last pulse, capture and reconcile receipts in ~/cos/outbox (STEWARD's view of the board and roadmap).
   Cards that are RED or stalled for want of engineering time; roadmap rows due Nov 25 or Dec 31 that are behind or
   have no owner.
2. Last week's ~/meetings notes and ~/Documents/Zoom transcripts: stated pain, "someone should build…", manual
   workarounds (hand loads, copy-paste), each with its timestamp. Use the meeting-analyst agent, one per meeting.
3. Data-team Slack threads from the last 7 days (read-only search): repeated asks and blockers.
4. Zendesk intake: make intake-holders counts if the target exists (dry run only); otherwise say it wasn't read.
5. ~/builds/*/HANDOFF.md: what the two active builds still need.

Score every candidate on one line: the number it moves · whose problem it is (a named person) · the data it needs
(read-only? canon?) · blast radius · size (one week or less) · reversibility. Prefer a named owner's explicit ask and
the Nov 25 milestone. A candidate with no board card is marked "needs a card first" (STEWARD proposes it); it can't
be picked until the card exists.

Done means: opportunities.md in the job folder: the top three with their score lines and sources, then the rest in
one line each.
If nothing new since last week's opportunity receipt, set summary to exactly: NO CHANGE
