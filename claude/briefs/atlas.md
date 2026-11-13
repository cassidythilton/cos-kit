Task: Agent Atlas lookup. Cassidy named a past chat, agent or project. Find it and report on it, read-only.

Use cos-atlas, his read-only CLI over the Agent Atlas index (~/Documents/Cursor Projects/agent-atlas/, refreshed every
10 minutes while the app runs). It's the same tool his Claude Code and Cursor agents use (~/.claude/skills/agent-atlas).
  ~/cos/bin/cos-atlas find <words> [--days N]      chats by name, project or branch; falls back to full history
  ~/cos/bin/cos-atlas show <id|words>              where, when, stats, commits, overview, resume command, transcript
  ~/cos/bin/cos-atlas search <words> [--days N]    full-history search with snippets
  ~/cos/bin/cos-atlas messages <id> --role user    his prompts in that chat (also --last N, --grep WORD)
  ~/cos/bin/cos-atlas recent --days 7              what he's worked on lately
Only if the CLI can't answer: sqlite3 -readonly on atlas.db (sessions, names, fts, stats, session_commits) or summ.db.
Never write to anything in that folder, and don't call the local server.

Rules
1. Resolve first, with find. If more than one chat matches, return the top few (title, source, repo, branch, last
   date, id) as open_questions and let Cassidy pick. Don't merge them.
2. Read the overview from show before anything else. A local model wrote it, so check any detail that matters with
   messages. Go deeper only on the chat he named. Read a transcript file only for that chat, at the path show prints.
   Never glob across projects.
3. What goes back to the bot (the receipt's summary): title, id, source, repo, branch, dates, counts, commits and a
   short summary in your own words. Never transcript text, file contents or raw rows.
   Say where each part came from: "per the Atlas overview" for the overview, "per message #N" for anything you checked,
   "inferred" for anything matched by branch or date. Owners, open items and status are as of the chat's last date,
   not today: say so, and don't check them against GitHub unless Cassidy asked about now.
4. A chat marked [lake chat] (canon_risk set) touched the lake or canon. Report only its id, title, repo, branch,
   dates, counts and the card numbers it touched. That full list is allowed, and nothing more: no summary. Say
   "lake chat: details stay on the Mac" (canon charter decision 14). The receipt goes to a Grok bot, which is a
   non-Claude model.
5. To send him back to a chat, give its where line from show: the app (Cursor or Claude Code), the folder, the chat
   title, and the resume command for Claude Code.

Recent-work mode (the Chief's sweeps). When the request is a time window instead of a name ("today", "since
16:30 yesterday", "since the last sweep"), don't resolve or ask. Run recent --days 1 (or 2 if the window crosses
midnight) and keep only chats whose last date falls in the window. For each one, one block:
  - title, id, source, repo and branch, last activity time (MT).
  - did: one or two lines in your own words from the overview, checked with messages --role user --last 10.
  - blocked and next: only if the chat says so; otherwise "none stated".
  - cards: the data-org issue or PR numbers it touched (from branch names, commits, or #N in his prompts). Numbers only.
A [lake chat] gets title, id, repo, branch, last time and card numbers only: no did, blocked or next, and the line
"lake chat: details stay on the Mac". Cards it touched still go in, so the Chief can check their daily logs.
Never draft a Did/Blocked/Next log yourself; the Chief and STEWARD do that from this list. Skip headless and job runs
(cos:* rows) unless they changed a card.

Done means: receipt.json with the match or the candidates. Write nothing else outside the job folder.
