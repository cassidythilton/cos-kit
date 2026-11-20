Task: the provider desk. Every weekday, push data-org #630 (the search for label facts) forward until every candidate
provider has a go or no-go decision from Cassidy. Full court press: nobody goes quiet without a follow-up, and nothing
waits on us.

## The tracker (the one source of truth)
Read ~/cos/state/providers.json (yesterday's tracker). If it doesn't exist, build it: every candidate named on #630,
its sub-cards (#668 to #684, #464, #598), the README it links, and anyone Cassidy has emailed, met or messaged about
label facts, nutrition data or a data partnership (Foodgraph, Syndigo, 1WorldSync, Nutritionix, NielsenIQ / Label
Insight / Brandbank, GS1, Trustwell / ESHA, SPINS, Datasembly, Salsify, the shared grocery catalog (GDSN), Open Food
Facts, Kroger's API, Field Agent, Eurofins, and any others you find).
Write today's tracker to providers.json in this job folder (the Mac copies it into place). One entry per provider:
{"name", "card": "data-org#N", "what_it_fills": "<the hole, or unknown>", "app_use": "yes|no|unknown",
 "gov_use": "yes|no|unknown", "contacts": [{"name", "email or Slack id", "role"}], "status":
 "researching|contacted|waiting on them|waiting on us|sample or trial|pricing|decision ready|decided",
 "decision": "pending|go|no-go", "decided_on", "decided_why", "last_us": "<date and what we sent>",
 "last_them": "<date and what they said>", "next": "<one action>", "owner": "Cassidy or the desk", "due": "<date>",
 "nudges": <count since their last reply>, "evidence": ["<links: email, Slack, card comment, call and timestamp>"]}
A decision is Cassidy's alone, and it's "decided" only when he said go or no-go (in a call, email, Slack or the brief).

## Every run
1. For each provider not decided, look for anything new since its last entry: his Gmail (sent and received; read
   only), Slack (DMs, group DMs and channels; read only), his calendar (calls held or booked), ~/cos/zoom transcripts
   from the last day, and the comments on its card and on #630. The newest source wins over card text.
2. Update the entry: last touch on each side, what they said, what's now owed and by whom, and the three answers
   (what hole it fills, app use, government use) whenever a source settles one.
3. Follow-up cadence (full court press):
   - We owe them something (an answer, a list, a sample file, an NDA): draft it today.
   - They owe us and it's been 3 business days since our last message: draft a short, friendly nudge.
   - Second nudge with no reply: draft one to a second contact or suggest a 15-minute call, and say so.
   - Third nudge with no reply: stop drafting and propose "no-go: unresponsive" for Cassidy's decision.
   - A call is due (after a sample, a demo or pricing): draft the invite note with two proposed times from his free
     calendar slots (read his calendar; never create the event).
   Every draft goes in drafts/<n>.json (the follow-ups format: {"kind": "email"|"slack", ...}). The Mac saves them into
   his Gmail or Slack Drafts; nothing is ever sent. Write in his voice, short. Never promise money, volumes or terms.
4. Decision ready: when a provider has all three answers and a sample or price, write a one-paragraph go/no-go
   recommendation with the evidence, as a question for Cassidy ("Foodgraph: go to a paid pilot? 1-yes 2-no 3-later").
5. Write log-630.md: today's daily log for #630, Did / Blocked / Next, only what changed today, each line with its
   source. If nothing changed, write no file.

## Hand back (receipt)
summary, in plain language and in this order:
- One line: "N of M providers decided" and who moved today.
- Decisions for Cassidy (at most 3), numbered, answerable 1-yes 2-no 3-later, each with its evidence link.
- Drafts saved today (who, what, why), each one line.
- Waiting on them, with days waiting, and the next nudge date.
Never quote contract terms, prices or NDA content into the summary (it leaves the Mac): say "pricing received" and
link the email. If nothing changed and nothing is due, set summary to exactly: NO CHANGE
