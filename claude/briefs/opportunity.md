Task: find this week's build opportunities for BUILDER. At most three, and fewer is a fine answer. The board is the gate.

Two passes. The first finds candidates. The second proves or kills each one before it can be ranked. On Nov 14, two
of three ranked ideas died on a premise nobody had checked (#651 assumed an IQA confidence score that doesn't exist,
and it overlapped Nicholas's own milestone). The second pass exists so that doesn't reach Cassidy again.

PASS 1: CANDIDATES. Read, in this order:
1. The last pulse, capture and reconcile receipts in ~/cos/outbox (STEWARD's view of the board and roadmap).
   Cards that are RED or stalled for want of engineering time; roadmap rows due Nov 25 or Dec 31 that are behind or
   have no owner.
2. Last week's call transcripts in ~/cos/zoom: stated pain, "someone should build…", manual workarounds (hand loads,
   copy-paste), each with its timestamp. Use the meeting-analyst agent, one per meeting.
3. Data-team Slack threads from the last 7 days (read-only search): repeated asks and blockers.
4. Zendesk intake: make intake-holders counts if the target exists (dry run only); otherwise say it wasn't read.
5. ~/builds/*/HANDOFF.md: what the active builds still need.
6. ~/cos/handbook/build-exclusions.md (Cassidy's file): work he has ruled out. Drop any candidate it covers, and list
   it at the end as "excluded: <why>".

Keep at most six candidates for pass 2. A candidate with no board card is marked "needs a card first" (STEWARD
proposes it) and goes no further.

PASS 2: DILIGENCE, for each candidate, before any ranking. Read the real thing, not a summary of it. Write a DILIGENCE
block for each, with every line cited (file:line, PR or issue number with what you read, or a transcript timestamp):
- Premise: the one thing the build assumes exists or is true (a field, a score, a table, an API, a rule). Open the
  actual code, PR or doc that would hold it and quote the line. If it isn't there, the candidate is dead: say so and
  stop. "The card says so" is not a premise check.
- Owner and overlap: the card's owner, their open milestones, their open PRs, and any DRD or DADR on it. If the build
  would do work they already planned, the move is "offer help to <owner>", not a build. Say which.
- User: the named person who would use the result, and what they would do differently with it.
- Data: what it reads, whether read-only is enough, and whether canon is involved (aggregates and IDs only).
- Smallest useful version: one slice of a week or less, and what it waits on (a merge, a decision, an owner).
Mark each candidate CHECKED (every line backed), DEAD (premise false, or excluded), OFFER (overlaps an owner's planned
work) or NOT CHECKED YET (something couldn't be read; say what). Only CHECKED candidates can be ranked.

RANK the CHECKED ones on one line each: the number it moves · whose problem it is · the data it needs · blast radius ·
size · reversibility. Prefer a named owner's explicit ask and the Nov 25 milestone.

Done means: opportunities.md in the job folder, in this order: the ranked CHECKED candidates with their score lines
and DILIGENCE blocks; then OFFER, NOT CHECKED YET, DEAD and excluded, one line each with the reason. The receipt's
summary names how many candidates each status got. If nothing new since last week's opportunity receipt, set summary
to exactly: NO CHANGE

After you finish, a different model (Codex) reviews every ranked candidate and tries to kill it. Write each DILIGENCE
block so a skeptic can check it without redoing your work.
