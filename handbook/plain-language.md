# How the Bots describe things to Cassidy (sanctioned format, proposed 2026-11-19)

Write to Cassidy as a smart person who is new to all of this. He should never need to translate. Every Bot follows this
file, and so do the Mac's packets and previews. KEEPER checks a sample of messages against it every week.

## Every item has three parts

1. What happened (or what is proposed), in one plain sentence.
2. Why it matters to him.
3. What he needs to do: a decision, or "Nothing, this is just so you know."

## Naming things: the first mention in a message uses the full form; later mentions can use the short name alone

| Thing | Format | Example |
|---|---|---|
| A card (issue) | [#n · short name](link) — whose · where it fits | [#767 · Ingredient re-parse](https://github.com/wisecodeai/data-org/issues/767) — your card with Evgeny · November roadmap item, due Tue Nov 25 |
| A PR | [PR #n · short name](link) — whose · what it waits on | [PR #805 · Intake sweep fix](https://github.com/wisecodeai/data-org/pull/805) — your PR · waiting on David's approval |
| Another repo's card | [repo #n · short name](link) — whose · where it fits | [food-enrichment #220 · Denominator definition](https://github.com/wisecodeai/food-enrichment/issues/220) — Nicholas's card |
| A roadmap sheet cell | the Data Roadmap sheet, "row name" row, column name | the Data Roadmap sheet, "Label facts" row, Owner column |
| A Google Doc | ["title"](link) doc — who can see it | ["Available foods rubric"](https://docs.google.com/document/d/18etCW7-HY9kR3HcYZQL3tc6vaKIgKsEzCGzp54DDIRU) doc — a draft only you can see |
| A Slack conversation | whose · which conversation · when, linked | [Steve's direct message from Tuesday about the GitHub app](link) |
| A person | first name; add their role the first time if they're outside the data team | Steve (our GitHub owner) |
| A date or time | weekday, month, day; times in Mountain time | Tue Nov 25, 4:30 PM |

Short names: two to four plain words about what the work is, not the GitHub title's jargon. Use the same short name
every time (the Mac keeps one list of them, so every Bot uses the same one). Whose: "your card", "David's PR".
Where it fits: which roadmap goal and its date, or "not on the roadmap".

## Words that never reach Cassidy unless he asks

Commit or file hashes, job ids, cos-run lane names, file paths, row numbers, column letters, "tier 0/1/2", checker or
verdict jargon, and raw error text. Say instead:
- "done without asking (you can undo it)" for tier 0; "needs your yes" for tier 1; "needs your yes, one at a time" for
  tier 2.
- An acronym is spelled out the first time in a message: "DRD-0035, the decision doc on what 'available' means".
- A status color is said as a color and what it means: "red: blocked".
- A failure is said as what didn't happen and what's being done: "This morning's GitHub check didn't run. I've started
  a fix and will tell you when it's back."

## Decisions

Numbered, each with its options, so he can answer "1-yes 2-no 3-later". At most five per brief; the rest wait.

## Before and after

Bad: Will do. I'll add row 15's J column to the same change, plain "#767" in place of "#778", so both come to you on
one card.

Good: I'll fix one more thing in the same change. On the Data Roadmap sheet, the "Ingredient re-parse" row points to
the wrong card: it names [#778 · Test golden sets](https://github.com/wisecodeai/data-org/issues/778) — your card with
Melanie, when it should name [#767 · Ingredient re-parse](https://github.com/wisecodeai/data-org/issues/767) — your card
with Evgeny · November roadmap item, due Tue Nov 25. Both fixes will come to you as one approval.
What you need to do: nothing yet.
