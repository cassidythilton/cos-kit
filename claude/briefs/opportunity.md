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
3. Data-team Slack threads from the last 7 days (read-only search, the work-signal channels in the system map):
   repeated asks and blockers. Write slack-digest.md in the job folder as you go: one line per relevant thread,
   "- <channel> <date>: <what was asked or blocked, in your words> (<permalink>)". Your words only: no quotes of food,
   label or canon text, no canon table names, no personnel content. Codex reads this file (after a canon tripwire) and
   cites it as slack-digest.md:<line>; it never sees Slack itself or any transcript.
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

Also write diligence.json in the job folder, the same content for the scripts that run after you:
{"window": "YYYY-MM-DD to YYYY-MM-DD", "excluded": ["<idea>: <why>"], "candidates": [{"id": "<card number, or a slug
if no card>", "card": "wisecodeai/<repo>#<n>" or null, "idea": "<one line, your words: no quotes, no canon, nothing
from a call>", "status": "CHECKED|OFFER|DEAD|NOT CHECKED YET", "reason": "<one sentence>", "score_line": "<CHECKED
only>", "rank": <1.. among CHECKED, else null>, "evidence": [{"field": "premise|owner|user|data|smallest", "claim":
"...", "cite": "...", "kind": "code|pr|issue|board|receipt|slack|doc|transcript"}]}]}
Every line of a DILIGENCE block is one evidence item. Anything from a call is kind "transcript"; a script holds those
on the Mac before Codex sees your work, so a premise backed only by a call won't convince Codex.

RANK the CHECKED ones on one line each: the number it moves · whose problem it is · the data it needs · blast radius ·
size · reversibility. Prefer a named owner's explicit ask and the Nov 25 milestone.

Done means: opportunities.md in the job folder, in this order: the ranked CHECKED candidates with their score lines
and DILIGENCE blocks; then OFFER, NOT CHECKED YET, DEAD and excluded, one line each with the reason. The receipt's
summary names how many candidates each status got. If nothing new since last week's opportunity receipt, set summary
to exactly: NO CHANGE

After you finish, a different model (Codex) does its own blind pass over the same candidates (it sees only the card
and your one-line idea), then each of you attacks the other's CHECKED ideas once, and a script decides: an idea
survives only if both of you end at CHECKED and neither refutation stands. Write each DILIGENCE block so a skeptic
can check it without redoing your work.
