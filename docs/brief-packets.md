# Brief packets: the Mac gathers each brief

Built Nov 19, 2026, for plan changes 3 and 4 (docs/plan-2026-11-19-lean-on-agents.md). Not switched on yet.

## In short

The Chief used to gather the morning brief and the end-of-day sweep itself, one Mac command at a time. That was
about 190 approval cards a day. Now the Mac does all of the reading on its own, a little before each brief, and hands
the Chief one page. The Chief turns that page into the brief and runs almost nothing.

## When it runs

- Weekdays at 5:45 AM: the morning packet.
- Weekdays at 4:12 PM: the evening packet. It runs after the 4 PM daily-log capture.

The command is `cos-packet morning` or `cos-packet evening`. The Mac's schedule starts it.

## What it reads, in order

Each read has a time limit. If one fails or runs out of time, the packet still comes. The failure becomes a plain
line at the top, such as "Slack couldn't be read: it didn't finish within 7 minutes." It is never left out.

1. The health line: did everything that should have run in the last 12 hours (14 in the evening) work?
2. GitHub: what's new since the last brief, and which PRs wait on his review.
3. The owed list: what he owes, checked live against GitHub just now.
4. Slack: every direct message, group message and thread he's in with activity since the last brief, and which
   ones wait on him. This reads only. Nothing is sent.
5. His chats since the last brief (morning) or today (evening), from Agent Atlas.
6. Evening only: the 4 PM daily-log capture, and what the Bots did today without asking (changes he can undo,
   and Slack drafts saved for him to send).

The Mac can't read his calendar. The morning packet says so, and the Chief adds today's meetings from Google Calendar.

## What the page looks like

1. **Health**: one line, or the list of what didn't work.
2. **Decisions**: at most five, numbered, each answerable "1-yes 2-no 3-later". Only things that truly need him:
   - a change already shown to him and waiting on his yes,
   - today's daily logs, if the capture staged them (evening),
   - a reply someone has waited on for more than two days,
   - a PR waiting on his review.
   Anything past five is listed under FYI, held for the next brief. Nothing is dropped.
3. **Done without asking** (evening): each change, with "you can undo it".
4. **Owed**: the live list, one linked line per item. Never a count alone.
5. **Slack waiting on you**: one linked line per conversation.
6. **FYI**: everything else worth knowing.

A staged change is said the way the Mac's own preview says it: each line of a GitHub batch in plain words, and each
sheet cell as "the Data Roadmap sheet, "Label facts" row, Owner: "" becomes "Matt"". If those words can't be read, a
line at the top says so and the change still shows, from its own summary.

People appear by first name. The Mac looks up each GitHub login in the names list's "people" entries first, then in
the Handle column of handbook/people.md. A login it can't match is shown as is.

Every card and PR is named the sanctioned way (handbook/plain-language.md), for example
"[#767 · Ingredient re-parse](link) — your card with Evgeny". Short names come from the Mac's one names list when it
has one. Otherwise they come from the start of the GitHub title, up to 40 characters. If neither is known, the number
appears alone. A name is never made up.

## What it never does

- It never sends, posts or changes anything. Every step only reads.
- It never shows file paths, job ids or raw error text in what Cassidy reads. The commands to undo today's changes
  go in a last section marked for the Chief only.
- It sends only to the Chief, and only the page.

## Where things land

- The page: `~/cos/outbox/packet-<morning|evening>-<YYYYMMDD>/packet.md`.
- What it sends the Chief: `receipt.json` in the same folder (the page, cut at 12,000 characters).
- What each step did: `steps.json` in the same folder.
- The time of the last packet sent: `~/cos/state/packet-last.json`. It sets "since the last brief" for the next one.

## Trying it by hand

- `cos-packet morning --dry-run` shows what it would run. It runs nothing and writes nothing.
- `cos-packet morning --no-push` builds the page without sending it. Note that it still runs the real reads.

## Tests

`claude/tests/test-packet.sh` checks the order of the sections, that a failed step becomes a line at the top, at most
five decisions, no bare counts under Owed, the plain naming format, and that `--no-push` doesn't send. It uses a
throwaway home folder and stand-in commands only. It never touches the real `~/cos`, the network or a Bot.
