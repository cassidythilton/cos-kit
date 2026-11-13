#!/usr/bin/env python3
"""Read-only flight recorder API and UI. Binds 127.0.0.1 only.

Starts `cos-db load` when the last load is older than 60 seconds, in the background.
The request is answered from the database already on disk.
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
import sys
import threading
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

KIT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(KIT / "claude"))
import cos_db  # noqa: E402

HOST = "127.0.0.1"
PORT = int(os.environ.get("COS_DASH_PORT", "8787"))
DIST = KIT / "apps" / "flight-recorder" / "dist"
HOME = Path(os.environ.get("HOME", "")).expanduser()
DB = Path(os.environ.get("COS_DB", HOME / "cos" / "state" / "cos.db"))
LOAD_LOCK = threading.Lock()
WINDOWS = {"1d": 1, "7d": 7, "30d": 30}
SLOTS = ["followups", "pulse", "capture", "reconcile", "week", "opportunity", "keeper"]
JOB_OK = __import__("re").compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$")


def connect() -> sqlite3.Connection | None:
    if not DB.is_file():
        return None
    conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=5)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def rows(conn, sql, params=()):
    return [dict(row) for row in conn.execute(sql, params).fetchall()]


def one(conn, sql, params=()):
    found = conn.execute(sql, params).fetchone()
    return dict(found) if found else None


def utc_stamp(day: datetime) -> str:
    return day.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_stamp(stamp: str) -> datetime | None:
    if not stamp:
        return None
    try:
        if stamp.endswith("Z"):
            return datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        return datetime.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S").astimezone()
    except ValueError:
        return None


def local_day(stamp: str) -> datetime | None:
    parsed = parse_stamp(stamp)
    if not parsed:
        return None
    return parsed.astimezone().date()


def day_span(start_day, end_day) -> tuple[str, str]:
    tz = datetime.now().astimezone().tzinfo
    start = datetime(start_day.year, start_day.month, start_day.day, tzinfo=tz)
    end = datetime(end_day.year, end_day.month, end_day.day, tzinfo=tz) + timedelta(days=1)
    return utc_stamp(start), utc_stamp(end)


def newest_day(conn) -> object:
    found = one(conn, """
        SELECT MAX(ts) AS ts FROM (
          SELECT started AS ts FROM jobs WHERE started IS NOT NULL
          UNION ALL SELECT ts FROM gate_events
          UNION ALL SELECT ts FROM schedule
          UNION ALL SELECT ts FROM corrections
        )
    """)
    day = local_day(found["ts"]) if found and found.get("ts") else None
    return day or datetime.now().astimezone().date()


def window_of(conn, name: str):
    days = WINDOWS.get(name, 7)
    end_day = newest_day(conn)
    start_day = end_day - timedelta(days=days - 1)
    start, end = day_span(start_day, end_day)
    prior_end_day = start_day - timedelta(days=1)
    prior_start_day = prior_end_day - timedelta(days=days - 1)
    prior_start, prior_end = day_span(prior_start_day, prior_end_day)
    partial = end_day == datetime.now().astimezone().date()
    return {
        "name": name if name in WINDOWS else "7d",
        "start": start, "end": end,
        "prior_start": prior_start, "prior_end": prior_end,
        "start_day": start_day.isoformat(), "end_day": end_day.isoformat(),
        "partial": partial, "days": days,
    }


def data_through(conn) -> str | None:
    newest = ""
    ledger = HOME / "cos" / "state" / "ledger"
    if ledger.is_dir():
        for path in ledger.glob("*.jsonl"):
            last = ""
            try:
                for line in path.read_text(errors="replace").splitlines():
                    if line.strip():
                        last = line
            except OSError:
                continue
            if not last:
                continue
            try:
                stamp = json.loads(last).get("ts") or ""
            except json.JSONDecodeError:
                continue
            if stamp > newest:
                newest = stamp
    if newest:
        return newest
    found = one(conn, "SELECT MAX(started) AS ts FROM jobs")
    return found["ts"] if found else None


def last_load_age() -> float | None:
    conn = connect()
    if conn is None:
        return None
    try:
        found = one(conn, "SELECT ended FROM loads WHERE ended IS NOT NULL ORDER BY id DESC LIMIT 1")
    except sqlite3.Error:
        return None
    finally:
        conn.close()
    if not found or not found.get("ended"):
        return None
    parsed = parse_stamp(found["ended"])
    if not parsed:
        return None
    return (datetime.now(timezone.utc) - parsed).total_seconds()


def maybe_load() -> None:
    age = last_load_age()
    if age is not None and age < 60:
        return
    if not LOAD_LOCK.acquire(blocking=False):
        return

    def work():
        try:
            binary = HOME / "cos" / "bin" / "cos-db"
            if not binary.is_file():
                binary = KIT / "claude" / "cos-db"
            subprocess.run([str(binary), "load"], timeout=180, check=False)
        finally:
            LOAD_LOCK.release()

    threading.Thread(target=work, daemon=True).start()


def miss(msg: str) -> bool:
    text = (msg or "").lower()
    return text.startswith("skipped") or "failed" in text or "missed" in text


def count_between(conn, sql, start, end) -> int:
    found = one(conn, sql, (start, end))
    return int(found["n"] or 0) if found else 0


def summary(conn, window) -> dict:
    start, end = window["start"], window["end"]
    prior_start, prior_end = window["prior_start"], window["prior_end"]
    job_sql = "SELECT COUNT(*) AS n FROM jobs WHERE COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ?"
    spend_sql = """SELECT COALESCE(SUM(cost_usd), 0) AS n FROM jobs
                   WHERE engine = 'claude' AND COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ?"""
    checker_sql = """SELECT
                       SUM(CASE WHEN checker = 'pass' THEN 1 ELSE 0 END) AS pass,
                       SUM(CASE WHEN checker = 'fail' THEN 1 ELSE 0 END) AS fail
                     FROM jobs WHERE COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ?"""
    gate_sql = "SELECT decision, COUNT(*) AS n FROM gate_events WHERE ts >= ? AND ts < ? GROUP BY decision"
    miss_sql = "SELECT msg FROM schedule WHERE ts >= ? AND ts < ?"
    corr_sql = "SELECT COUNT(*) AS n FROM corrections WHERE ts >= ? AND ts < ?"
    engines_sql = """SELECT engine, COUNT(*) AS n, SUM(CASE WHEN has_codex = 1 THEN 1 ELSE 0 END) AS codex
                     FROM jobs WHERE COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ? GROUP BY engine"""

    def block(span_start, span_end):
        checker = one(conn, checker_sql, (span_start, span_end)) or {"pass": 0, "fail": 0}
        passed = int(checker["pass"] or 0)
        failed = int(checker["fail"] or 0)
        decisions = {row["decision"]: row["n"] for row in rows(conn, gate_sql, (span_start, span_end))}
        missed = sum(1 for row in rows(conn, miss_sql, (span_start, span_end)) if miss(row["msg"]))
        engines = rows(conn, engines_sql, (span_start, span_end))
        return {
            "jobs": count_between(conn, job_sql, span_start, span_end),
            "claude_spend": round(float(one(conn, spend_sql, (span_start, span_end))["n"] or 0), 4),
            "checker_pass": passed,
            "checker_fail": failed,
            "checker_rate": (passed / (passed + failed)) if (passed + failed) else None,
            "gate_blocks": int(decisions.get("block") or 0),
            "gate_asks": int(decisions.get("ask") or 0),
            "missed_or_failed": missed,
            "open_corrections": count_between(conn, corr_sql, span_start, span_end),
            "cursor_runs": sum(row["n"] for row in engines if row["engine"] == "cursor-agent"),
            "codex_runs": sum(int(row["codex"] or 0) for row in engines),
        }

    levels = rows(conn, """
        SELECT verifier_level AS level, COUNT(*) AS n FROM jobs
        WHERE verifier_level IS NOT NULL AND verifier_level != ''
          AND COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ?
        GROUP BY verifier_level
    """, (start, end))
    current = block(start, end)
    current["verifier_levels"] = {row["level"]: row["n"] for row in levels}
    current["prior"] = block(prior_start, prior_end)
    current["partial"] = window["partial"]
    current["start_day"] = window["start_day"]
    current["end_day"] = window["end_day"]
    return current


def spend(conn, days: int) -> dict:
    end_day = newest_day(conn)
    start_day = end_day - timedelta(days=days - 1)
    start, end = day_span(start_day, end_day)
    found = rows(conn, """
        SELECT COALESCE(started, ended) AS ts, lane, engine, cost_usd, has_codex
        FROM jobs WHERE COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ?
    """, (start, end))
    by_day = {}
    cursor = start_day
    today = datetime.now().astimezone().date()
    while cursor <= end_day:
        by_day[cursor.isoformat()] = {
            "day": cursor.isoformat(), "partial": cursor == today and cursor == end_day,
            "dollars": {}, "runs": {}, "codex": 0,
        }
        cursor += timedelta(days=1)
    for row in found:
        day = local_day(row["ts"])
        if not day:
            continue
        bucket = by_day.get(day.isoformat())
        if bucket is None:
            continue
        lane = row["lane"] or "other"
        engine = row["engine"] or "none"
        if row["cost_usd"] is not None:
            bucket["dollars"][lane] = round(bucket["dollars"].get(lane, 0) + float(row["cost_usd"]), 4)
        bucket["runs"][engine] = bucket["runs"].get(engine, 0) + 1
        bucket["codex"] += int(row["has_codex"] or 0)
    return {"days": list(by_day.values())}


def job_list(conn, query) -> list[dict]:
    clauses = ["1=1"]
    params: list = []
    window_name = query.get("window", ["7d"])[0]
    if window_name in WINDOWS:
        window = window_of(conn, window_name)
        clauses.append("COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ?")
        params.extend([window["start"], window["end"]])
    for key, column in (("bot", "bot"), ("lane", "lane"), ("status", "status")):
        value = query.get(key, [""])[0]
        if value:
            clauses.append(f"{column} = ?")
            params.append(value)
    text = query.get("q", [""])[0].replace("%", "").replace("_", "")
    if text:
        like = f"%{text}%"
        clauses.append("(job LIKE ? OR IFNULL(summary,'') LIKE ? OR IFNULL(lane,'') LIKE ?)")
        params.extend([like, like, like])
    try:
        limit = min(500, max(1, int(query.get("limit", ["200"])[0])))
    except ValueError:
        limit = 200
    params.append(limit)
    return rows(conn, f"""
        SELECT job, lane, bot, caller, started, ended, secs, exit_code AS exit, status, checker,
               verifier_level, cost_usd, engine, needs_approval, has_codex
        FROM jobs WHERE {' AND '.join(clauses)}
        ORDER BY COALESCE(started, ended) DESC LIMIT ?
    """, params)


def job_detail(conn, job: str) -> dict | None:
    if not JOB_OK.match(job):
        return None
    found = one(conn, "SELECT * FROM jobs WHERE job = ?", (job,))
    if not found:
        return None
    found["exit"] = found.pop("exit_code", None)
    brief = ""
    folder = found.get("folder") or ""
    allowed = (str(HOME / "cos" / "outbox"), str(HOME / "cos" / "archive"))
    if folder.startswith(allowed) and (Path(folder) / "brief.md").is_file():
        lines = (Path(folder) / "brief.md").read_text(errors="replace").splitlines()[:20]
        brief = cos_db.redact("\n".join(lines))[:4000]
    return {
        "job": found,
        "brief": brief,
        "files": rows(conn, "SELECT path, op FROM files WHERE job = ? ORDER BY op, path", (job,)),
        "commands": rows(conn, "SELECT seq, command, tool FROM commands WHERE job = ? ORDER BY seq", (job,)),
        "gate": rows(conn, "SELECT * FROM gate_events WHERE job = ? ORDER BY ts", (job,)),
        "pushes": rows(conn, "SELECT * FROM pushes WHERE job = ? ORDER BY ts", (job,)),
        "applies": rows(conn, "SELECT * FROM applies WHERE job = ? ORDER BY ts", (job,)),
    }


def classify(msg: str) -> str:
    text = (msg or "").lower()
    if "fail" in text:
        return "failed"
    if text.startswith("skipped") or "missed" in text:
        return "missed"
    if "paused" in text:
        return "paused"
    if "no change" in text:
        return "no change"
    if "pushed" in text:
        return "pushed"
    if text.startswith("start"):
        return "start"
    return "other"


def schedule(conn, days: int) -> dict:
    end_day = newest_day(conn)
    start_day = end_day - timedelta(days=days - 1)
    start, end = day_span(start_day, end_day)
    found = rows(conn, "SELECT ts, slot, msg FROM schedule WHERE ts >= ? AND ts < ? ORDER BY ts", (start, end))
    rank = {"failed": 6, "missed": 5, "paused": 4, "skipped": 3, "no change": 2, "pushed": 1, "start": 0, "other": 0}
    cells: dict[str, dict] = {}
    for row in found:
        day = local_day(row["ts"])
        if not day or row["slot"] not in SLOTS:
            continue
        outcome = classify(row["msg"])
        key = f"{row['slot']}|{day.isoformat()}"
        current = cells.get(key)
        if current is None or rank[outcome] >= rank[current["outcome"]]:
            parsed = parse_stamp(row["ts"])
            clock = parsed.astimezone().strftime("%H:%M") if parsed else ""
            cells[key] = {"outcome": outcome, "time": clock, "msg": row["msg"]}
    day_list = []
    cursor = start_day
    while cursor <= end_day:
        day_list.append(cursor.isoformat())
        cursor += timedelta(days=1)
    return {"slots": SLOTS, "days": day_list, "cells": cells}


def approvals(conn) -> list[dict]:
    applied = rows(conn, "SELECT ts, job, sha, writes, ok, status FROM applies ORDER BY ts DESC")
    for row in applied:
        row["kind"] = "applied"
    seen = {row["job"] for row in applied}
    staged = rows(conn, """
        SELECT started AS ts, job, batch_sha AS sha, batch_writes AS writes, status
        FROM jobs WHERE batch_sha IS NOT NULL AND batch_sha != ''
        ORDER BY started DESC
    """)
    for row in staged:
        if row["job"] in seen:
            continue
        row["kind"] = "staged"
        row["ok"] = None
        row["status"] = "staged"
        applied.append(row)
    return applied


def clip(text: str, limit: int = 220) -> str:
    words = " ".join((text or "").split())
    if len(words) <= limit:
        return words
    return words[: limit - 1] + "…"


def runner_name(engine: str | None) -> str:
    if engine == "claude":
        return "Claude"
    if engine == "cursor-agent":
        return "Cursor"
    return "Grok"


def first_sentence(text: str, limit: int = 120) -> str:
    clean = re.sub(r"[*`_]", "", text or "")
    clean = re.sub(r"^#+\s*", "", clean)
    clean = " ".join(clean.split())
    clean = re.sub(r"^(done|escalate|needs cassidy)\s*:\s*", "", clean, flags=re.IGNORECASE)
    clean = re.sub(r"^I\s+", "", clean)
    if not clean:
        return ""
    cut = re.search(r"(?<=[a-z0-9])[.!?](?:\s|$)", clean, flags=re.IGNORECASE)
    sentence = clean[:cut.end()].strip() if cut and cut.end() <= 180 else clean
    if sentence:
        sentence = sentence[0].upper() + sentence[1:]
    if len(sentence) > limit:
        return sentence[: limit - 1].rstrip() + "…"
    return sentence


def describe_command(command: str) -> str:
    raw = (command or "").strip()
    low = raw.lower()
    if not raw:
        return "Ran a command"
    if low.startswith("mcp:"):
        name = raw.split("__")[-1].replace("_", " ").strip()
        return f"Called {name}" if name else "Called a connected app"
    tokens = raw.split()
    head = tokens[0]
    if head == "gh":
        if "issue comment" in low:
            return "Commented on a GitHub issue"
        if "issue view" in low:
            return "Read a GitHub issue"
        if "issue list" in low:
            return "Listed GitHub issues"
        if "pr diff" in low:
            return "Read a pull request diff"
        if "pr view" in low:
            return "Read a pull request"
        if "pr list" in low or "search prs" in low:
            return "Listed pull requests"
        if "project item-list" in low:
            return "Listed project cards"
        if low.startswith("gh api"):
            return "Called the GitHub API"
        return "Used GitHub"
    if head == "make":
        target = next((tok for tok in tokens[1:] if not tok.startswith(("-", "/", "=")) and "=" not in tok), "")
        return {
            "lint-writing": "Checked the writing",
            "stale": "Looked for stale cards",
            "board": "Read the board",
            "roadmap-check": "Checked the roadmap",
            "field": "Read a card field",
        }.get(target, f"Ran {target}" if target else "Ran a project command")
    if head in {"ls", "find"}:
        return "Listed files"
    if head in {"grep", "rg"} or (head == "git" and "grep" in tokens):
        return "Searched the files"
    if head == "git":
        if "status" in tokens:
            return "Checked git status"
        if "log" in tokens:
            return "Read the git history"
        if "show" in tokens:
            return "Read a git commit"
        if "diff" in tokens:
            return "Read a git diff"
        if "fetch" in tokens:
            return "Fetched from git"
        return "Ran a git command"
    if head in {"cat", "sed", "head", "tail", "stat"}:
        return "Read a file"
    return "Ran a command"


def describe_block(decision: str, rule: str) -> str:
    text = rule or ""
    if "Slack" in text:
        what = "a Slack send"
    elif "issue" in text.lower():
        what = "a GitHub issue write"
    elif "GitHub" in text or "gh " in text:
        what = "a GitHub write"
    elif text:
        what = text.split("(")[0].strip().rstrip(".").lower() or "an action"
    else:
        what = "an action"
    return f"Asked before {what}" if decision == "ask" else f"Blocked {what}"


SLOT_NAME = {
    "followups": "follow-ups",
    "pulse": "the pulse",
    "capture": "the capture",
    "reconcile": "the reconcile",
    "week": "the week",
    "opportunity": "the opportunity pass",
    "keeper": "keeper",
    "obligations": "obligations",
}


def slot_name(slot: str) -> str:
    return SLOT_NAME.get(slot or "", (slot or "the slot").replace("-", " "))


def describe_schedule(slot: str, msg: str) -> str:
    name = slot_name(slot)
    text = (msg or "").lower()
    if text.startswith("pushed to"):
        who = text.replace("pushed to", "", 1).strip()
        return f"Sent {name} to {who.upper()}" if who else f"Sent {name}"
    if text.startswith("start"):
        return f"Started {name}"
    if "no change" in text:
        return f"{name.capitalize()} had nothing new"
    if "fail" in text:
        return f"{name.capitalize()} failed"
    if text.startswith("skipped") or "missed" in text:
        return f"Missed {name}"
    if "paused" in text:
        return f"Paused {name}"
    return f"{name.capitalize()}"


def describe_push(bot: str, slot: str) -> str:
    who = (bot or "a bot").upper()
    if slot == "result":
        return f"Sent the result to {who}"
    if slot:
        return f"Sent {slot_name(slot)} to {who}"
    return f"Sent a handoff to {who}"


def action_log(conn, window) -> list[dict]:
    """Every recorded Mac action in the window, newest first."""
    start, end = window["start"], window["end"]
    found: list[dict] = []
    for row in rows(conn, """
        SELECT job, lane, bot, status, summary, secs, engine, COALESCE(started, ended) AS ts
        FROM jobs
        WHERE COALESCE(started, ended) >= ? AND COALESCE(started, ended) < ?
    """, (start, end)):
        found.append({
            "id": f"run:{row['job']}", "ts": row["ts"], "bot": row["bot"] or "",
            "kind": "run", "job": row["job"], "seq": -1,
            "runner": runner_name(row["engine"]),
            "text": first_sentence(row["summary"] or "") or "No write-up yet.",
            "detail": " · ".join(part for part in [row["job"], row["lane"] or "", row["status"] or "", f"{row['secs']}s" if row["secs"] is not None else ""] if part),
        })
    for row in rows(conn, """
        SELECT c.job, c.seq, c.command, j.bot, j.engine, COALESCE(j.started, j.ended) AS ts
        FROM commands c JOIN jobs j ON j.job = c.job
        WHERE COALESCE(j.started, j.ended) >= ? AND COALESCE(j.started, j.ended) < ?
    """, (start, end)):
        found.append({
            "id": f"cmd:{row['job']}:{row['seq']}", "ts": row["ts"], "bot": row["bot"] or "",
            "kind": "command", "job": row["job"], "seq": row["seq"] or 0,
            "runner": runner_name(row["engine"]),
            "text": describe_command(row["command"] or ""),
            "detail": clip(row["command"] or ""),
        })
    for row in rows(conn, """
        SELECT g.*, j.bot AS owner, j.engine
        FROM gate_events g LEFT JOIN jobs j ON j.job = g.job
        WHERE g.ts >= ? AND g.ts < ?
    """, (start, end)):
        found.append({
            "id": f"gate:{row['id']}", "ts": row["ts"], "bot": row["owner"] or "",
            "kind": "ask" if row["decision"] == "ask" else "block",
            "job": row["job"] or "", "seq": 0,
            "runner": runner_name(row["engine"]) if row["job"] else "Grok",
            "text": describe_block(row["decision"] or "", row["rule"] or ""),
            "detail": clip(row["cmd"] or row["rule"] or ""),
        })
    for row in rows(conn, "SELECT * FROM pushes WHERE ts >= ? AND ts < ?", (start, end)):
        found.append({
            "id": f"push:{row['id']}", "ts": row["ts"], "bot": (row["bot"] or "").upper(),
            "kind": "push", "job": row["job"] or "", "seq": 0,
            "runner": "Grok",
            "text": describe_push(row["bot"] or "", row["slot"] or ""),
            "detail": " · ".join(part for part in [row["slot"], row["job"], f"code {row['code']}" if row["code"] else ""] if part),
        })
    for row in rows(conn, "SELECT * FROM schedule WHERE ts >= ? AND ts < ?", (start, end)):
        found.append({
            "id": f"sched:{row['id']}", "ts": row["ts"], "bot": "",
            "kind": "schedule", "job": "", "seq": 0,
            "runner": "Grok",
            "text": describe_schedule(row["slot"] or "", row["msg"] or ""),
            "detail": " · ".join(part for part in [row["slot"], clip(row["msg"] or "", 180)] if part),
        })
    for row in rows(conn, "SELECT * FROM corrections WHERE ts >= ? AND ts < ?", (start, end)):
        found.append({
            "id": f"note:{row['id']}", "ts": row["ts"], "bot": (row["bot"] or "").upper(),
            "kind": "correction", "job": "", "seq": 0,
            "runner": "Grok",
            "text": first_sentence(row["note"] or "") or "Recorded a correction.",
            "detail": clip(row["note"] or ""),
        })
    found.sort(key=lambda item: (item["ts"] or "", 1 if item["kind"] != "command" else 0, -(item.get("seq") or 0)), reverse=True)
    for item in found:
        item.pop("seq", None)
    return found


def envelope(conn, tables: list[str], sql: str, data):
    return {"source": {"tables": tables, "sql": sql}, "data_through": data_through(conn), "data": data}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        return

    def do_POST(self): self._refuse()
    def do_PUT(self): self._refuse()
    def do_DELETE(self): self._refuse()
    def do_PATCH(self): self._refuse()

    def _refuse(self):
        body = b'{"error":"read-only"}'
        self.send_response(405)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Allow", "GET")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        maybe_load()
        parsed = urlparse(self.path)
        if parsed.path.startswith("/api/"):
            self._api(parsed)
        else:
            self._static(parsed.path)

    def _api(self, parsed):
        query = parse_qs(parsed.query)
        conn = connect()
        if conn is None:
            self._json(200, {"source": {"tables": [], "sql": ""}, "data_through": None, "data": None, "empty": True})
            return
        try:
            path = parsed.path
            if path == "/api/summary":
                window = window_of(conn, query.get("window", ["7d"])[0])
                payload = envelope(conn, ["jobs", "gate_events", "schedule", "corrections"],
                    "COUNT jobs; SUM cost_usd WHERE engine=claude; checker pass/fail; gate decision counts; schedule msgs skipped|failed|missed; COUNT corrections",
                    summary(conn, window))
            elif path == "/api/spend":
                try:
                    days = min(90, max(1, int(query.get("days", ["30"])[0])))
                except ValueError:
                    days = 30
                payload = envelope(conn, ["jobs"],
                    "SUM cost_usd BY local day, lane; COUNT runs BY engine; COUNT has_codex",
                    spend(conn, days))
            elif path == "/api/log":
                window = window_of(conn, query.get("window", ["7d"])[0])
                payload = envelope(conn, ["jobs", "commands", "gate_events", "pushes", "schedule", "corrections"],
                    "runs, commands, gate blocks and asks, pushes, schedule lines, corrections in the window, newest first",
                    action_log(conn, window))
            elif path == "/api/jobs":
                payload = envelope(conn, ["jobs"],
                    "SELECT jobs filtered by bot, lane, status, window, q ORDER BY started DESC",
                    job_list(conn, query))
            elif path.startswith("/api/jobs/"):
                detail = job_detail(conn, unquote(path[len("/api/jobs/"):]))
                if detail is None:
                    self._json(404, {"error": "not found"})
                    return
                payload = envelope(conn, ["jobs", "files", "commands", "gate_events", "pushes", "applies"],
                    "one job, its files, commands, gate events, pushes and applies; brief.md first 20 lines",
                    detail)
            elif path == "/api/gate":
                window = window_of(conn, query.get("window", ["7d"])[0])
                found = rows(conn, "SELECT * FROM gate_events WHERE ts >= ? AND ts < ? ORDER BY ts", (window["start"], window["end"]))
                payload = envelope(conn, ["gate_events"], "SELECT gate_events in the window ORDER BY ts", found)
            elif path == "/api/schedule":
                try:
                    days = min(60, max(1, int(query.get("days", ["14"])[0])))
                except ValueError:
                    days = 14
                payload = envelope(conn, ["schedule"],
                    "slot x local day, outcome from msg (pushed, no change, skipped, paused, missed, failed)",
                    schedule(conn, days))
            elif path == "/api/approvals":
                payload = envelope(conn, ["applies", "jobs"],
                    "applies, plus jobs.batch_sha with no apply row as staged",
                    approvals(conn))
            elif path == "/api/corrections":
                window = window_of(conn, query.get("window", ["30d"])[0])
                found = rows(conn, "SELECT * FROM corrections WHERE ts >= ? AND ts < ? ORDER BY ts DESC", (window["start"], window["end"]))
                payload = envelope(conn, ["corrections"],
                    "corrections in the window; the file has no closed flag, so every row is open",
                    found)
            elif path == "/api/evals":
                payload = envelope(conn, ["evals"], "SELECT evals ORDER BY ts DESC", rows(conn, "SELECT * FROM evals ORDER BY ts DESC"))
            elif path == "/api/board-health":
                payload = envelope(conn, ["board_health"], "SELECT board_health ORDER BY as_of", rows(conn, "SELECT * FROM board_health ORDER BY as_of"))
            else:
                self._json(404, {"error": "not found"})
                return
        finally:
            conn.close()
        self._json(200, payload)

    def _json(self, status: int, payload) -> None:
        body = json.dumps(payload, default=str).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _static(self, path: str) -> None:
        rel = unquote(path).lstrip("/") or "index.html"
        root = DIST.resolve()
        target = (root / rel).resolve()
        if root not in target.parents and target != root:
            self.send_error(404)
            return
        if not target.is_file():
            target = root / "index.html"
        if not target.is_file():
            body = b"<!doctype html><title>Flight recorder</title><p>The UI is not built yet. Run cos-dash.</p>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        kind = {
            ".html": "text/html", ".js": "text/javascript", ".css": "text/css",
            ".svg": "image/svg+xml", ".woff2": "font/woff2", ".woff": "font/woff",
            ".png": "image/png",
        }.get(target.suffix, "application/octet-stream")
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    if HOST != "127.0.0.1":
        raise SystemExit("refusing to bind anything but 127.0.0.1")
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"flight recorder http://{HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
