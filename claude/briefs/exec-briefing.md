Task: weekly exec briefing. Draft "This week in data", the written half of the briefing band at the top of the exec Data
dashboard.

You edit one file, `apps/data-dashboard/briefing.yaml`, in this draft worktree (started from the data-org branch
`cassidy/732-data-dashboard-app`). Cassidy Hilton (he/him) reviews and approves it. You never approve, publish, commit
for him or push: the kit stages the push, and nothing leaves the Mac until his yes.

Publishing happens in Cassidy's dashboard session, not here: it applies your diff, runs the three checks (YAML parse,
`build.py --verdicts-only`, the preview), and pushes only on his word. The live page reads `payload.json`, which only the
`--verdicts-only` rebuild regenerates, and it shows a briefing only when `status: approved`. A push to the branch
deploys the live page, so nothing here is ever committed for him or pushed.

## Who reads it, and why it matters
- Primary reader: Peter (CEO). He holds the data org accountable for better data coverage. In one minute he wants
  what's working, what's not, what we're doing about it, and what's next. Then he drills into the detail.
- Also: Ron (CFO) and Mark, who own the exec dashboard hub, plus every other executive. Ron's brief (2026-11-19):
  "on the top, tell me in one minute what's working, what's not working, what we should do better, and what the
  numbers are telling." He asked for "wow moments", and for the not-working part to be stated plainly.
- The page is a beta. Its numbers come from the prod data lake and refresh daily.

## Read these first, in this order
1. `apps/data-dashboard/AGENTS.md`: the rules, the weekly-briefing section and the traps.
2. `apps/data-dashboard/HANDOFF.md`: the decisions, the open items and the people.
3. `apps/data-dashboard/briefing.yaml`: last week's file. Keep its structure exactly.
4. `apps/data-dashboard/public/payload.json`, keys `briefing.changes`, `glance`, `tiles`, `available` and `board`:
   this week's computed numbers and the board snapshot the page shows. If payload.json's date is more than two days
   old, say so in the hand-back: the numbers may be stale.
5. `apps/data-dashboard/changelog.yaml`: any rule-set release dated this week.

## Sources for this week's items (read-only)
- GitHub Project 1, the board: `gh project item-list 1 --owner wisecodeai --format json --limit 2000`. Use Status,
  Target, the RAGB colour and Milestone. Note what moved lanes, what's due in the next 14 days, and what turned amber
  or red.
- Daily logs: comments starting "Daily log" or "Did / Blocked / Next" on the active cards
  (`gh api repos/wisecodeai/data-org/issues/<n>/comments`). They're the best source of what happened. The cards that
  matter most now: 535 (Walmart and Target to Live, the first data into the app's database), 469 (the pipeline runs end
  to end on its own), 650 (the scheduled Pantry publish), 739 (Daily MDM, the nightly delivery to the app), 740 (the
  EN40 coverage targets), 630 (outside data providers), 366 (lab testing, DSS), 732 (this dashboard), 797 (David's
  board update and the offsite).
- Slack, read only, with the Slack read tools: #data-team (C0BMLSDDNDT), the dashboard group (C0CG1MNG5MH), the V1 and
  available-foods group (C0C6EF4FX39), the AWS group (C0CJ44VFBAA), AND every DM and group DM Cassidy had in the last
  seven days (search his messages; executives often confirm things there: on Nov 19 Ron confirmed the Foodgraph NDA
  was signed in a group DM, and the draft missed it). Never post, react or draft.
- Call transcripts in ~/cos/zoom/ (the Mac's mirror of his Zoom folder): the last seven days' files, by modified date,
  including 1:1s. Read each in full for decisions and definitions (on Nov 18 David set the 90% coverage definition in
  "Amiah & Cassidy 1:1 02", and the draft missed it). Cite them by title and timestamp; never quote more than a few words.
- His Google Calendar (read-only) for the week's meetings; a meeting with no transcript here is named in the hand-back.

## Newest source wins, and every claim is checked
Card text and logs go stale. Before writing an item, look for anything newer on the same subject in the DMs, channels
and calls above, and use the newest (an NDA "in progress" on the card but "signed" in Thursday's DM is signed). A
definition or decision someone stated in a call overrides older card wording. For each item, open its source and check
the claim against it before you write it; in the hand-back, list each item with the source you checked.

## What to write
Edit only these keys in `briefing.yaml`:
- `week_of`: the Monday the briefing is for (the day it runs, normally a Monday), as 'YYYY-MM-DD', quoted. The items cover
  the seven days before it.
- `drafted_by`: "Claude, from <your sources>".
- `approved_by: null` and `status: draft`. Always. Cassidy flips them himself.
- `working`, `not_working`, `next_two_weeks`: 2 to 5 items each. Each item has `text` and `source`, plus these flags:
  - `pick: true` on exactly one non-opportunity item per column. That's the item Glance shows.
  - `opportunity: true` (with `pick: true`) on the single biggest opportunity, if there is one. It shows as a star.
  - `wow: true` for a genuine wow moment: outside validation, or a step change.
  - `lead: true` and an `ask:` line on the single most important blocker. Today that's "our data isn't in the app
    yet". It stays the lead until card 535 ships and card 739 runs nightly.
  - `hold: <who must OK it>` for anything that needs someone's sign-off first. Held items never show.
- `focus`: the standing "Where we are" statement. Change it only when the data org's focus changes. Today: hardening
  the platform first, so coverage climbs steadily after. The Dec 31 targets stand.
- `outside_data`: the Detail card on outside data providers. Update `now`, `who`, `also` and `dates` from card 630's
  log.
Do NOT write "What changed". The builder computes it nightly from the numbers, the rule set and the board.

## How to position it
1. Lead with what grew; put shares second. If a share fell, give the cause in a few words ("share eased because app
   scans brought in N foods we don't hold yet"). Never hide a number. Explain it.
2. Every claim is factual and sourced: the card number, the dated log, or the call with its timestamp. Don't claim
   enrichment work did something unless a source says so. "Rose" is fine; "we enriched" needs evidence.
3. Partnerships first. Never point Peter at another team. Frame cross-team work as joint and under way ("together with
   the app team", never "the app team needs to"). No asks directed at another team.
4. No names in a performance sense. Executives may appear by role ("our CTO", "our CDO") when they back an opportunity.
   Never name anyone next to a blocker or a miss.
5. Optimistic and accurate. It's a beta and we're hardening the platform. Say what's next and when.
6. Avoid hard-coded numbers that go stale. The page shows the live numbers. If you must cite one, date it.
7. Write every item in the approved executive style: read ~/cos/handbook/executive-style.md first and match its
   example in shape, length and tone (a headline, then Working, Not working, Next two weeks; a plain name with the
   card in brackets; one sentence with its date; numbers with their comparison; problems stated plainly with their
   fix). The headline goes in the hand-back for Cassidy, and in `focus` only if the focus itself changed.

## Hard limits
- No prices, contract terms or budget amounts. The Dec 9 budget decision may appear only as a date and a decision.
- No canon values, nutrient amounts, label text, user ids or emails.
- Nothing from a vendor under NDA beyond what's already in card 630's team-visible comments.
- Unreleased exec or commercial strategy stays out. The repo is team-visible.
- YAML trap: a bare `#` starts a comment and silently cuts the text. Quote any string containing "#", or write
  "card 535" instead of "#535".
- Never edit the `hold:` on the FDA item. Only Cassidy clears it, after David's OK.
- Never post to Slack, comment on GitHub, or edit the board or the Data Roadmap sheet.

## Check before you hand back
1. Re-read the file as YAML: every string with "#", ":" or a leading quote is quoted; the structure matches last
   week's exactly; exactly one `pick: true` per column, at most one `opportunity`, exactly one `lead`.
2. Read every item aloud. Is each one true, sourced, partner-safe, and free of names next to problems?
3. The YAML parse, the builder's `--verdicts-only` rebuild and the page preview run in Cassidy's own session when he
   approves; list them in the hand-back as "to check on approval".

## Hand back (the receipt)
- The diff of `briefing.yaml`.
- What changed from last week, and why, in a few lines.
- Anything you held, and who needs to OK it.
- Any judgment call you weren't sure about, as a numbered question with options.
