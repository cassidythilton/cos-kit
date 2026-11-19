# Plan: lean on the agents (proposed 2026-11-19, not yet approved)

Cassidy's ask, Nov 19: the morning and evening sweeps take him a full day. He approves every command and every Docs or
Sheets edit, and the Bots write like machines ("row 15's J column … #767 in place of #778"). He trusts the Bots now. He
wants to review proposals and results, not each command; to be written to as a person new to all this; Slack drafts
always saved in Slack, never sent; and more overnight work like the available-foods rubric BUILDER wrote while he slept.

## What the numbers say (from ~/cos/state/ledger/jobs.jsonl, Mon Nov 16 to Thu Nov 19)

- The Bots ran 768 commands on his Mac in four days, about 190 a day. Each one was a card he tapped.
- 717 of them (93%) only read or prepared something: quick 346, investigate 231, preview 57, atlas 18, gh-scan 8.
- 52 changed something: apply 35, apply-sheet 9, land 8. That's about 13 a day.
- Why the "Allow without asking" rules didn't help: Grok's "Execution on this computer" setting is separate from
  Custom Rules. While it's "Ask every time", every Mac command makes a card, whatever the rules say (Grok docs,
  approvals-security-and-privacy page).

So almost all of his tapping guards reads. The safety that matters is already on the Mac: a write only runs if it is
byte-for-byte the batch he saw, from a fixed list, with owner checks, and it's logged with its undo.

## The new deal, in one paragraph

The Bots work on their own and bring him two things: proposals (what they want to change, in plain words, a few
times a day in one list) and results (what they did, each with an undo). He says yes to a proposal list once, not to
each command. Reads, research, drafts and small fixes on his own cards just happen and show up in the evening list.
The hard stops stay hard: anything other people see first (sending, posting, merging, approving, closing someone
else's work) still waits for his yes.

## Changes

| # | Change | What he notices | Built where |
|---|---|---|---|
| 1 | Stop tapping reads. Execution on this computer → "Always allow". Custom Rules (Ask first) stop: any command that isn't ~/cos/bin/cos-run; cos-run apply, apply-sheet, land, lake; anything that sends or posts. | ~190 cards a day become ~3 approval lists a day | Grok settings (his taps, from a paste) |
| 2 | Hard backstops on the Mac, so (1) doesn't rest on Grok's judgment: apply, apply-sheet and land refuse a batch that wasn't previewed first (the preview is what he says yes to); a daily "what changed" ledger page; a one-line kill switch (Execution → Never allow). | Same safety as today on writes | cos-run + installer tests |
| 3 | Sweeps assembled on the Mac, not by the Chief. At 6:00 and 4:00 the Mac runs the GitHub scan, call notes, today's chats, daily-log capture and owed replies itself, and pushes one packet to the Chief. The Chief turns it into the brief; it runs almost no commands. | Briefs arrive ready; fewer stalls and failures | cos-sched (launchd), like STEWARD's |
| 4 | The brief becomes a one-page decision list: at most 5 decisions, each answerable "1-yes 2-no 3-later"; then "Done without asking" (with undo); then FYI. Everything else waits for the next sweep. | A sweep takes minutes, not a day | Chief playbook |
| 5 | Plain-language rule for every Bot ("write to me like I'm new to this"): name things by what they are, never a bare number ("the ingredient re-parse card", linked); no column letters, row numbers, shas, lanes or acronyms unless explained; each item says what happened, why it matters to me, what I need to do (or "nothing"). Previews show card titles, not numbers. KEEPER checks a sample of messages each week. | Messages read like a colleague wrote them | all five playbooks, cos-gh plain, KEEPER |
| 6 | Slack drafts only in Slack's own Drafts (slack_send_message_draft), every Bot; a Custom Rule "Ask first before sending any Slack message"; "Disable drafts" stays off on every Bot. KEEPER flags any send. | Drafts wait in Slack for him | playbooks, Grok setting |
| 7 | More done without asking (tier 0), each in the evening list with its undo: daily logs on his own cards; edits to Docs the Bots created; comments he dictated word for word; the roadmap-sheet fills the Chief already proposes daily. | Fewer approvals in each list | standing-approvals.json, cos-gh |
| 8 | Night shift (BUILDER, nightly, 10 PM to 6 AM, Mac plugged in): up to two jobs a night from a queue. Kinds: write-ups for asks made of him (like the rubric: sources, a draft, open questions for the owner); prototypes on a build branch with tests; review drafts for PRs waiting on him; research on a question he dropped in ("tonight: …"). Nothing leaves: Docs stay private drafts in his Drive, PRs stay drafts, Slack stays drafts. The morning brief opens with "While you slept": what was made, a 3-line summary each, one decision each (share, revise, drop). | Something new and finished most mornings | BUILDER playbook, cos-sched, build lane |

## What stays hard (unchanged)

Sending or posting anything (Slack, email, GitHub comments) waits for his yes. Merges, approvals, closes, and anything
on other owners' cards beyond the blank-field rule wait for his yes. Canon stays on the Mac. Nicholas's live pipeline
is never touched. A Bot never pushes to someone else's branch.

## Rollout

1. Build 2, 3, 5 (previews), 6 and 7 on the Mac, with tests. Then the Grok pastes for 1, 4, 5, 6 and 8.
2. Week one: KEEPER compares every change in the ledger with a yes or a tier-0 rule; any gap is a stop.
3. Night shift starts with write-ups only; prototypes join after a week of clean mornings.

## Decisions for Cassidy

1. Switch Grok to "Always allow" with the Ask-first rules and the Mac backstops? (yes / keep tapping)
2. Tier 0 additions in change 7: all four, or which?
3. Night shift's first kind of work: write-ups for asks, PR review drafts, prototypes, or research questions?
