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
4. A chat marked [lake chat] (canon_risk set) touched the lake or canon. Report its id, title, dates and counts only,
   with no summary, and say "lake chat: details stay on the Mac" (canon charter decision 14). The receipt goes to a
   Grok bot, which is a non-Claude model.
5. To send him back to a chat, give its where line from show: the app (Cursor or Claude Code), the folder, the chat
   title, and the resume command for Claude Code.

Done means: receipt.json with the match or the candidates. Write nothing else outside the job folder.
