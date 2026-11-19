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
| 5 | Plain language, one sanctioned format (handbook/plain-language.md): every item says what happened, why it matters, what he needs to do; things are named "[#767 · Ingredient re-parse](link) — your card with Evgeny · November roadmap item, due Tue Nov 25"; never hashes, job ids, row numbers or column letters. The Mac keeps one list of short names so every Bot says the same name; the Mac's packets and previews arrive already in this format, so the Bots copy rather than compose. KEEPER checks a sample weekly. | Messages read like a colleague wrote them | handbook, all five playbooks, cos-gh plain, a names list STEWARD keeps |
| 6 | Slack messages can't be sent by any agent, by construction (section below). | Every message waits in Slack's Drafts for him | Grok settings, a Mac draft lane, tests |
| 7 | More done without asking (tier 0), each in the evening list with its undo: daily logs on his own cards; edits to Docs the Bots created; comments he dictated word for word; the roadmap-sheet fills the Chief already proposes daily. | Fewer approvals in each list | standing-approvals.json, cos-gh |
| 9 | Monitoring of every process, with who started what (section below). | A failure reaches him within 15 minutes, in plain words, with a fix already started | cos-health, a run list, heartbeats |
| 10 | Once done, it stays done (section below). | Nothing he finished comes back unless something new happened | cos-obligations, the packet, a done lane |
| 11 | Memory manager (section below; approved Nov 19). | Bots stop repeating stale things; one memory, kept tidy | one store on the Mac, KEEPER's weekly cleanup |
| 8 | Night shift, all nine kinds, inside a budget (section below; approved Nov 19). | Something finished most mornings, at a known cost | cos-sched night, recipes per kind, the existing lanes |

## Change 6: no agent can send a Slack message

Not "flag it after": take the ability away, and test that it stays away.
1. Disconnect Slack from Grok (Settings → Apps). No Bot can then post, reply or react in Slack at all.
2. Drafts go through the Mac only: a new cos-run slack-draft lane. Claude on the Mac gets exactly one Slack write,
   "save a draft" (slack_send_message_draft), plus reads to find the conversation. Send, schedule, canvas, list and
   reaction tools are denied in its settings and blocked again by the gate. A Claude Code deny is a hard wall, not a
   judgment call. The lane logs each draft (where, first line) for the evening list.
3. Slack reading for the briefs moves to the Mac's packet (change 3), read-only.
4. Installer tests prove it every install: the draft lane's settings allow no send tool; the gate blocks every Slack
   send tool for every lane; no other settings file allows a Slack write. A failed test stops the install.
5. A tripwire, only to prove the wall holds: hourly, the Mac looks for any message in his name posted by an app. It
   should always find none; if it ever finds one, that's a top-priority system alarm (change 9), not a routine flag.
Email has the same exposure today (Grok's docs say a chat-requested email goes out once Auto Review allows it).
Decision 3 asks whether email gets the same treatment.

## Change 9: monitoring, with who started what

Today a failure surfaces only when he trips over it (the daily issue logs and Zendesk triage routines failed for days).
1. One list of everything that should run (handbook/expected-runs.json): each process, in plain words; who runs it
   (the Mac's schedule or a named Bot routine); when; how long it may take; what proves it worked; what to do if not.
   It covers the ten Mac schedules, every Grok routine (from the Bots' exports), webhook deliveries, connector checks
   (Sheets, Slack, GitHub sign-in), the Zoom copy, and the Mac itself (awake, plugged in, disk).
2. Heartbeats from Grok routines: every routine's last step is cos-run heartbeat <routine> ok|failed "<what>". A
   routine that fails, or never runs, leaves a missing or failed heartbeat, which the Mac sees.
3. Who started what: every run record carries who started it (a Mac schedule, a named Bot routine, Cassidy in a chat,
   or Claude Code), the run that started it, and where its result went (which Bot, delivered or not). The flight
   recorder page (cos-dash) shows each process's chain and history.
4. A watchdog every 15 minutes (cos-health, under the Mac's schedule) compares the list with what happened: missed,
   failed, stuck past its time, undelivered, or a failed heartbeat. A new problem goes out at once three ways: to the
   Chief (which must start a fix and tell him at the top of the chat, in the plain format), a Mac notification (works
   even if Grok is down), and a red line on the flight recorder. It stays open until a later run succeeds, then says
   "fixed". The watchdog has its own heartbeat; the morning brief says if monitoring itself is down.
5. Every brief opens with one health line: "All 31 runs since this morning worked" or the list of what didn't, each
   with what's being done. KEEPER's weekly check turns a repeat failure into a test.

## Change 10: once done, it stays done

Real case, Nov 19: Cassidy closed every open item with the Chief on the evening of Nov 18. The next morning the Chief
listed four "overdue" questions from David. GitHub shows he had answered three of them that evening: on #740
(Nov 18, 7:28 PM), #750 (Nov 18, 8:03 PM) and #630 (Nov 17, 7:10 PM). The Mac's own list had already closed the #750
and #630 items on Nov 17 and 18. Only #700 was really waiting, on David's Nov 6 question. The same message offered to
draft 23 replies he owes and check 41 owed to him, from a list nobody had re-checked.
Causes: the Bots keep their own lists and merge them; finishing something in a chat isn't recorded anywhere; and
"has he already answered?" is left to the Bot's judgment instead of checked against GitHub and Slack.
1. One list: the Mac's open-items list (cos-obligations) is the only place an owed item lives. Bots don't keep their
   own and don't merge lists.
2. Done in a chat is done everywhere: when he says something is finished, the Chief records it (cos-run done <item>),
   and it's closed on the list with who closed it and when.
3. Checked before shown: before any item reaches him, the Mac re-checks the source (who spoke last on the card, PR or
   Slack thread). If he spoke last, it's closed, not shown.
4. A closed item comes back only if something new happened after he closed it (a new comment from the other person),
   and then it says what's new.
5. Counts are never shown without the items: "23 replies you owe" becomes the list, or nothing.

## Change 8: the night shift (approved Nov 19: all kinds, with a budget)

How it runs:
1. A queue on the Mac. Items come from Cassidy ("tonight: …"), OPS (asks made of him that need a write-up), STEWARD
   (roadmap items at risk) and BUILDER's weekly opportunity hunt.
2. The evening brief proposes tonight's jobs, one line each with its size and cost estimate. He says yes, or swaps.
3. At 10 PM the Mac runs each job as one Claude job through the existing lanes (investigate, draft, build, lake, fix),
   not as a chain of chat lookups. The Nov 19 rubric took about 11 separate lookups at 2:49 AM; at least 5 were killed
   within seconds and nobody was told.
4. Each kind has a recipe: what to read, what done means, and the checker plus second opinion that already guard jobs.
5. Nothing leaves: private Docs, draft PRs, Slack drafts. The morning brief opens with "While you slept": three lines
   per item and one decision (share, revise, drop). "Share" stages the outward step for his yes.

The nine kinds, with a size each (estimates from last week's real jobs: median $1.58, 90th percentile $3.66, the
largest $12.76; the Mac's Claude jobs cost about $490 in the week of Nov 12 to 19):

| Kind | Size | Cap per job |
|---|---|---|
| Meeting prep for tomorrow (all meetings in one job) | small | $3, 20 min |
| Call follow-through (yesterday's calls to draft cards and replies) | small | $3, 20 min |
| Board and roadmap cleanup (one approval list) | small | $3, 20 min |
| PR review drafts (up to 5 PRs waiting on him) | medium | $8, 45 min |
| Data answers (aggregates only, through the lake lane) | medium | $5, 30 min |
| Write-ups for asks (like the rubric) | medium | $6, 45 min |
| Decision-doc drafts on his cards | medium | $6, 45 min |
| Fixes for the system's own failures (fix lane; landing still needs his yes) | medium | $6, 60 min |
| Prototypes (build lane, tests, draft PR) | large | $12, 2 h; at most two a week |

The budget (handbook/night-budget.json, his file; he changes the numbers, nothing else does):
- Per night: $25 and 3 hours of work. Per week: $100. Per job: the cap above.
- Enforced by the Mac, not by a Bot: a job is stopped at its time cap; the next job starts only if the night's money
  left covers its estimate; spend is read from each job's own cost line and ledgered.
- A job that hits its cap stops cleanly and says what it got done ("partial: 3 of 5 reviews").
- Every morning: "Last night: 3 jobs, $11.40, 1 h 35 min." The Friday brief has the week's total against $100.
- Effort stays proportionate: small kinds run every weeknight they have input; medium kinds fill what's left; one
  large job at most per night.

## Change 11: memory manager (approved Nov 19)

Memory today lives in at least six places that never reconcile: each Bot's remember block (the Chief's is about 19,000
characters), the playbooks, the corrections ledger, the handoff notes, Claude Code's memory, and Agent Atlas. Nothing
merges duplicates, retires old facts or catches contradictions, and stale memory caused the Nov 19 "overdue" message.
1. Four kinds, kept apart. Rules (how he wants things done; permanent until he changes them). Facts (people, systems,
   decisions; each with its source, date and a review-by date). Open items: never memorized, always read live from
   the Mac's one list (change 10). History: stays in the ledgers and Atlas, looked up, not carried.
2. One store on the Mac (in the kit, under git). Each Bot's remember block is generated from it, only what that Bot
   needs, under a size cap; the same store feeds Claude Code's memory and the cassidy-mode skill.
3. New memories are proposals: corrections keep going in through cos-run note; "remember this" from any chat is
   proposed, then added.
4. KEEPER's weekly cleanup: merges duplicates; retires facts past their review-by date; re-checks facts against their
   source (is that PR still open? is that person still the owner?); sends him contradictions to settle; turns a
   correction that recurs into a check (the rule ladder). One short note: kept, merged, retired. Git keeps the undo.
5. Measures in the Friday brief: memory size per Bot, contradictions found, stale facts retired.

## What stays hard (unchanged)

Sending or posting anything (Slack, email, GitHub comments) waits for his yes. Merges, approvals, closes, and anything
on other owners' cards beyond the blank-field rule wait for his yes. Canon stays on the Mac. Nicholas's live pipeline
is never touched. A Bot never pushes to someone else's branch.

## Rollout

1. Build 9 (monitoring) and 6 (Slack) first, then 2, 3, 5 and 7 on the Mac, with tests. Then the Grok pastes for 1, 4, 5, 6 and 8.
2. Week one: KEEPER compares every change in the ledger with a yes or a tier-0 rule; any gap is a stop.
3. Night shift starts with the small and medium kinds; prototypes join after a week of clean mornings, inside the budget.
4. The memory manager follows monitoring: build the store, generate the five remember blocks, then KEEPER's cleanup.

## Decisions for Cassidy

1. Switch Grok to "Always allow" with the Ask-first rules and the Mac backstops? (yes / keep tapping)
2. Tier 0 additions in change 7: all four, or which?
3. Email: same as Slack (Gmail disconnected from Grok, drafts saved by the Mac only), or keep Grok's Gmail with an
   Ask-first rule for sending?
Answered Nov 19: the night shift runs all nine kinds inside the budget; the memory manager is approved as proposed.
