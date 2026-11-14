Task: prepare follow-ups for yesterday's meetings.

For each note in ~/meetings dated the previous business day (and any ~/cos/zoom transcript modified since then)
that has a full transcript: use the meeting-analyst agent, one per meeting. List each commitment Cassidy made or is
owed, with the owner, the date, and the transcript timestamp. Label anything not stated outright "proposed".
For each commitment Cassidy owes: one short draft in his voice (the voice skill on the Mac; cassidy-voice in Grok), marked DRAFT, not sent.
For each commitment someone owes him that has a board card: the card number and whether today's log mentions it.
Commitments with no card: list them under "needs a card" (STEWARD proposes cards; don't create one).
A meeting on Cassidy's calendar yesterday with no transcript in either folder: list it under "needs transcript" with its date and title, so the Chief can offer the Zoom ladder (system-map.md, section 4).

Done means: followups.md in the job folder, one section per meeting, every line with a timestamp.
If there were no meetings with transcripts, set summary to exactly: NO CHANGE

DADR candidates (plan item 8). In each transcript and in Cassidy's Slack threads from the same day, look for a
decision: "we decided X" (a decision already made), or "A or B?" with a named decider (a decision still open). List
each under "DADR candidates" with the words in one line, the decider if named, the card it belongs to if any, and
the transcript timestamp (or the Slack permalink). A decision already made is recorded as discovered: its DADR card
ends in Completed No Delivery. Don't draft the DADR here: STEWARD's capture and the Chief decide; drafts are only for
Cassidy's own cards. Before listing one, check dadr/ on main and open PRs (gh pr list --repo wisecodeai/data-org
--state open --limit 200 --search DADR) so a decision that already has a DADR is named, not proposed again.
