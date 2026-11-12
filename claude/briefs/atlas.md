Task: Agent Atlas lookup. Cassidy named a past chat, agent or project. Find it and report on it, read-only.

Where the data lives: ~/Documents/Cursor Projects/agent-atlas/ (built by Agent Atlas, refreshed every 10 minutes).
Open it read-only and never write to it. Use sqlite3 -readonly only. Don't call the local server.
- atlas.db, the index:
  - sessions: one row per chat. id, source (claude | cursor | cos), title (the chat's header name), project_label,
    repo (GitHub slug), branch, started, ended, n_msgs, file (transcript path), canon_risk (not null = touched the
    lake or canon), spawned_by.
  - names: FTS5 over title, project and branch. Use it to resolve a name.
  - fts over messages: full-history search, for when a name doesn't resolve.
  - stats: prompts, tokens, context, compactions and agent-written lines per chat.
  - session_commits, commits, branches, repos: git links.
- summ.db, table summ(id, json): a ready-written overview per chat (synopsis, files, outcomes). Prefer it to a
  transcript.
- archive/: hard-linked copies of transcripts that outlive Claude Code's 30-day cleanup.

Resolve a name:
  sqlite3 -readonly "$HOME/Documents/Cursor Projects/agent-atlas/atlas.db" "SELECT s.id, s.title, s.source, s.repo,
    s.branch, date(s.ended), s.canon_risk IS NOT NULL FROM names n JOIN sessions s ON s.id=n.id
    WHERE names MATCH '<words>' ORDER BY s.ended DESC LIMIT 5"

Rules
1. Resolve first. If more than one chat matches, return the top few (title, source, repo, branch, last date, id) as
   open_questions and let Cassidy pick. Don't merge them.
2. Read the overview in summ.db before the transcript. Read a transcript only for the one chat he named, at the file
   path the index gives. Never glob across projects.
3. What goes back to the bot (the receipt's summary): title, id, source, repo, branch, dates, counts, commits and a
   short summary in your own words. Never transcript text, file contents or raw rows.
   Say where each part came from: "per the Atlas overview" for anything from summ.db, "inferred" for anything
   matched by branch or date. Owners, open items and status are as of the chat's last date, not today: say so,
   and don't check them against GitHub unless Cassidy asked about now.
4. If canon_risk is set, report IDs and counts only, with no summary. Say "lake chat: details stay on the Mac"
   (canon charter decision 14).
5. To send him back to a chat, give its where-to-resume line: the app (Cursor or Claude Code), the folder, and the
   chat title.

Done means: receipt.json with the match or the candidates. Write nothing else outside the job folder.
