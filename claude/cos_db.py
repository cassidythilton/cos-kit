#!/usr/bin/env python3
"""Build ~/cos/state/cos.db from the append-only ledger and the files already on disk.

Writers never open this file. `load` is safe to re-run: each data table is replaced
inside one transaction from the current files, so two loads leave the same counts.
`loads` itself gains one row per run.
"""
from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

DATA_TABLES = [
    "jobs", "files", "commands", "gate_events", "pushes", "applies",
    "schedule", "corrections", "evals", "board_health", "pauses",
]

REDACTIONS = [
    (re.compile(r"https?://api2\.cursor\.sh/automations/\S+", re.I), "<webhook>"),
    (re.compile(r"api2\.cursor\.sh/automations/\S+", re.I), "<webhook>"),
    (re.compile(r"ghp_[A-Za-z0-9]+"), "<redacted>"),
    (re.compile(r"github_pat_[A-Za-z0-9_]+"), "<redacted>"),
    (re.compile(r"gho_[A-Za-z0-9]+"), "<redacted>"),
    (re.compile(r"xox[bpas]-[A-Za-z0-9-]+"), "<redacted>"),
    (re.compile(r"sk-[A-Za-z0-9_\-]{20,}"), "<redacted>"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "<redacted>"),
    (re.compile(r"(?i)bearer\s+\S+"), "Bearer <redacted>"),
    (re.compile(r"(?i)authorization:\s*\S+"), "Authorization: <redacted>"),
]
FILE_OP = {
    "Read": "read", "Write": "write", "Edit": "edit", "MultiEdit": "edit",
    "NotebookEdit": "edit", "Grep": "search", "Glob": "search",
}
SCHED_SLOTS = ("followups", "pulse", "reconcile", "capture", "week", "opportunity", "keeper")


def redact(value: str) -> str:
    if not value:
        return ""
    text = value.replace("\n", " ").replace("\r", " ")
    if "security" in text and "-w" in text:
        text = re.sub(r"-w.*", "-w <redacted>", text, count=1)
    for pattern, repl in REDACTIONS:
        text = pattern.sub(repl, text)
    return text


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def iso_epoch(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def to_int(value) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return None


def to_float(value) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def sha1(*parts: str) -> str:
    return hashlib.sha1("".join(parts).encode()).hexdigest()


def load_json(path: Path):
    try:
        return json.loads(path.read_text(errors="replace"))
    except (OSError, json.JSONDecodeError):
        return None


def read_jsonl(path: Path, errors: list[str]) -> list[dict]:
    if not path.is_file():
        return []
    rows = []
    for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"{path.name}:{n}: {exc}")
            continue
        if isinstance(item, dict):
            rows.append(item)
    return rows


def birth(path: Path) -> str | None:
    try:
        st = path.stat()
    except OSError:
        return None
    return iso_epoch(getattr(st, "st_birthtime", st.st_mtime))


def mtime(path: Path) -> str | None:
    try:
        return iso_epoch(path.stat().st_mtime)
    except OSError:
        return None


def pid_alive(pid: str) -> bool:
    try:
        os.kill(int(pid), 0)
    except (OSError, ValueError):
        return False
    return True


def bot_of(job: str) -> str:
    if job.startswith("followups-"):
        return "OPS"
    if job.startswith(("pulse-", "capture-", "reconcile-", "week-")):
        return "STEWARD"
    if job.startswith("opportunity-"):
        return "BUILDER"
    if job.startswith("keeper-"):
        return "KEEPER"
    if re.fullmatch(r"w[0-9a-f]{8}", job) or job.startswith("eval-"):
        return "EVAL"
    if job in {"smoke", "smoke-q", "wall-test", "access-check", "async-test"} or job.startswith("push-test-"):
        return "SYSTEM"
    return "CHIEF"


def caller_of(job: str) -> str:
    for slot in SCHED_SLOTS:
        if re.fullmatch(rf"{slot}-\d{{8}}", job):
            return "sched"
    return "bot"


def local_to_utc(stamp: str) -> str:
    if stamp.endswith("Z") or "+" in stamp[10:]:
        return stamp
    naive = datetime.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S")
    tz = datetime.now().astimezone().tzinfo
    return naive.replace(tzinfo=tz).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def seconds_between(a: str, b: str) -> float:
    left = datetime.strptime(a[:19], "%Y-%m-%dT%H:%M:%S")
    right = datetime.strptime(b[:19], "%Y-%m-%dT%H:%M:%S")
    return abs((left - right).total_seconds())


def walk_tools(node, found: list) -> None:
    if isinstance(node, dict):
        if node.get("type") == "tool_result":
            return
        if node.get("type") == "tool_use" and node.get("name"):
            found.append(node)
        for value in node.values():
            walk_tools(value, found)
    elif isinstance(node, list):
        for value in node:
            walk_tools(value, found)


def tool_path(name: str, payload: dict) -> str:
    for key in ("file_path", "path", "notebook_path"):
        if payload.get(key):
            return str(payload[key])
    if name == "Glob" and payload.get("pattern"):
        return str(payload["pattern"])
    return ""


def transcript_files(home: Path, session_id: str) -> list[Path]:
    if not session_id:
        return []
    root = home / ".claude" / "projects"
    if not root.is_dir():
        return []
    main = sorted(root.glob(f"*/{session_id}.jsonl"))
    subs = sorted(root.glob(f"*/{session_id}/subagents/*.jsonl"))
    return main + subs


def collect_activity(home: Path, job: dict) -> tuple[list[tuple], list[tuple]]:
    """Return (files, commands) for one job. Never reads tool results."""
    files: list[tuple] = []
    commands: list[tuple] = []
    seen: set[tuple] = set()
    folder = Path(job["folder"]) if job.get("folder") else None
    session = job.get("session_id") or ""
    for path in transcript_files(home, session):
        try:
            lines = path.read_text(errors="replace").splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            tools: list = []
            walk_tools(obj, tools)
            for tool in tools:
                name = str(tool.get("name") or "")
                payload = tool.get("input") if isinstance(tool.get("input"), dict) else {}
                op = FILE_OP.get(name)
                if op:
                    target = redact(tool_path(name, payload))[:800]
                    if target and (job["job"], target, op) not in seen:
                        seen.add((job["job"], target, op))
                        files.append((job["job"], target, op))
                elif name == "Bash":
                    command = redact(str(payload.get("command") or ""))[:300]
                    if command:
                        commands.append((job["job"], command, "Bash"))
                elif name.startswith("mcp__"):
                    commands.append((job["job"], f"mcp: {name}"[:300], name[:120]))
    context = folder / "context.txt" if folder else None
    if context and context.is_file() and (job.get("engine") == "cursor-agent" or not session):
        try:
            for line in context.read_text(errors="replace").splitlines():
                if line.startswith("$ "):
                    command = redact(line[2:].strip())[:300]
                    if command:
                        commands.append((job["job"], command, "quick"))
        except OSError:
            pass
    return files, commands


def blank_job(job: str, folder: str = "") -> dict:
    return {
        "job": job, "lane": "", "bot": bot_of(job), "caller": caller_of(job),
        "started": None, "ended": None, "secs": None, "exit_code": None,
        "status": None, "checker": None, "checker_failures": "[]",
        "verifier_level": None, "baseline_reading": None, "cost_usd": None,
        "engine": None, "summary": "", "needs_approval": 0, "needs_approval_json": "[]",
        "artifacts": 0, "batch_sha": None, "batch_writes": None, "async": "0",
        "folder": folder, "verifier_json": None, "has_codex": 0, "session_id": "",
    }


def job_from_folder(name: str, folder: Path, errors: list[str]) -> dict:
    row = blank_job(name, str(folder))
    receipt_path = folder / "receipt.json"
    rec = load_json(receipt_path) if receipt_path.is_file() else None
    if receipt_path.is_file() and rec is None:
        errors.append(f"{name}: receipt.json did not parse")
        rec = {}
    rec = rec or {}
    body = rec.get("receipt") if isinstance(rec.get("receipt"), dict) else {}
    checker = rec.get("checker") if isinstance(rec.get("checker"), dict) else {}
    checker_cost = None
    checker_path = folder / "checker.json"
    if checker_path.is_file():
        raw = load_json(checker_path) or {}
        checker_cost = raw.get("total_cost_usd")
        if not checker and isinstance(raw.get("structured_output"), dict):
            checker = raw["structured_output"]
    running = folder / ".running"
    status = body.get("status")
    summary = str(body.get("summary") or "")
    if running.is_file():
        pid = running.read_text(errors="replace").strip()
        row["async"] = "child"
        if pid_alive(pid):
            status = "running"
        elif not receipt_path.is_file():
            status = "failed"
            log = folder / "async.log"
            if log.is_file():
                tail = log.read_text(errors="replace")[-1500:]
                summary = redact(tail)
    cost = to_float(rec.get("cost_usd"))
    extra = to_float(checker_cost)
    if extra:
        cost = (cost or 0) + extra
    needs = body.get("needs_approval") if isinstance(body.get("needs_approval"), list) else []
    clean_needs = []
    for item in needs:
        if not isinstance(item, dict):
            continue
        clean_needs.append({
            "action": redact(str(item.get("action") or ""))[:300],
            "target": redact(str(item.get("target") or ""))[:300],
            "why": redact(str(item.get("why") or ""))[:300],
        })
    build = rec.get("build") if isinstance(rec.get("build"), dict) else {}
    verifier = build.get("verifier") if isinstance(build.get("verifier"), dict) else {}
    if not verifier and (folder / "verifier.json").is_file():
        raw = load_json(folder / "verifier.json") or {}
        if isinstance(raw.get("structured_output"), dict):
            verifier = raw["structured_output"]
    opinion = folder / "second-opinion.json"
    if opinion.is_file():
        head = opinion.read_text(errors="replace")[:240].lower()
        if "skipped" not in head:
            row["has_codex"] = 1
    brief = folder / "brief.md"
    row.update({
        "lane": rec.get("lane") or "",
        "started": birth(brief if brief.is_file() else folder),
        "ended": mtime(receipt_path) if receipt_path.is_file() else None,
        "status": status,
        "checker": checker.get("verdict"),
        "checker_failures": json.dumps(checker.get("failures") or []),
        "verifier_level": verifier.get("level"),
        "baseline_reading": ((build.get("baseline") or {}) if isinstance(build.get("baseline"), dict) else {}).get("reading"),
        "cost_usd": cost,
        "engine": rec.get("engine"),
        "summary": redact(summary)[:2000],
        "needs_approval": len(clean_needs),
        "needs_approval_json": json.dumps(clean_needs),
        "artifacts": len(body.get("artifacts") or []) if isinstance(body.get("artifacts"), list) else 0,
        "batch_sha": (rec.get("batch") or {}).get("sha256") if isinstance(rec.get("batch"), dict) else None,
        "batch_writes": to_int((rec.get("batch") or {}).get("writes")) if isinstance(rec.get("batch"), dict) else None,
        "verifier_json": json.dumps(verifier)[:20000] if verifier else None,
        "session_id": str(rec.get("session_id") or ""),
    })
    if row["started"] and row["ended"]:
        row["secs"] = max(0, int(seconds_between(row["started"], row["ended"])))
    return row


def apply_ledger_events(row: dict, events: list[dict]) -> None:
    def rank(event: dict) -> int:
        return {"child": 0, "0": 1, "1": 2}.get(str(event.get("async") or "0"), 1)

    if not events:
        return
    best = min(rank(event) for event in events)
    # A parent that only launched the child must not look like the finished job.
    if row.get("status") == "running":
        child = [event for event in events if str(event.get("async")) == "child"]
        use = child or [event for event in events if event.get("event") == "start"]
    else:
        use = [event for event in events if rank(event) == best]
    starts = [event for event in use if event.get("event") == "start"]
    ends = [event for event in use if event.get("event") == "end"]
    if starts:
        row["started"] = starts[0].get("ts") or row["started"]
        row["caller"] = starts[0].get("caller") or row["caller"]
        row["async"] = str(starts[0].get("async") or row["async"])
        if not row.get("lane"):
            row["lane"] = starts[0].get("lane") or ""
    if ends and row.get("status") != "running":
        end = ends[-1]
        row["ended"] = end.get("ts") or row["ended"]
        row["exit_code"] = to_int(end.get("exit"))
        row["secs"] = to_int(end.get("secs"))
        row["async"] = str(end.get("async") or row["async"])


def scan_jobs(home: Path, errors: list[str]) -> tuple[list[dict], list[tuple], list[tuple]]:
    jobs: dict[str, dict] = {}
    cos = home / "cos"
    for root in (cos / "outbox", cos / "archive"):
        if not root.is_dir():
            continue
        for name in sorted(os.listdir(root)):
            folder = root / name
            if folder.is_dir():
                jobs[name] = job_from_folder(name, folder, errors)
    events: dict[str, list[dict]] = {}
    for event in read_jsonl(cos / "state" / "ledger" / "jobs.jsonl", errors):
        job = str(event.get("job") or "")
        if job:
            events.setdefault(job, []).append(event)
    for job, group in events.items():
        row = jobs.get(job)
        if row is None:
            row = blank_job(job)
            lane = next((event.get("lane") for event in group if event.get("lane")), "")
            row["lane"] = lane or ""
            jobs[job] = row
        apply_ledger_events(row, group)
    files: list[tuple] = []
    commands: list[tuple] = []
    for row in jobs.values():
        if not row.get("folder"):
            continue
        found_files, found_commands = collect_activity(home, row)
        files.extend(found_files)
        seq = 0
        for job, command, tool in found_commands:
            seq += 1
            commands.append((job, seq, command, tool))
    return list(jobs.values()), files, commands


def scan_applies(home: Path, ledger_rows: list[dict], errors: list[str]) -> list[dict]:
    rows = []
    seen = set()
    for event in ledger_rows:
        sha = str(event.get("sha") or "")
        job = str(event.get("job") or "")
        key = (job, sha)
        if key in seen:
            continue
        seen.add(key)
        rows.append({
            "id": event.get("id") or sha1(event.get("ts", ""), job, sha),
            "ts": event.get("ts"), "job": job, "sha": sha,
            "writes": to_int(event.get("writes")), "ok": to_int(event.get("ok")),
            "status": event.get("status"),
        })
    cos = home / "cos"
    for root in (cos / "outbox", cos / "archive"):
        if not root.is_dir():
            continue
        for name in os.listdir(root):
            folder = root / name
            receipt = folder / "apply-receipt.json"
            if not receipt.is_file():
                continue
            data = load_json(receipt) or {}
            body = data.get("receipt") if isinstance(data.get("receipt"), dict) else {}
            script = folder / "apply.sh"
            sha = ""
            if script.is_file():
                sha = hashlib.sha256(script.read_bytes()).hexdigest()
            if (name, sha) in seen:
                continue
            match = re.search(r"(\d+) of (\d+)", str(body.get("summary") or ""))
            ok = int(match.group(1)) if match else None
            writes = int(match.group(2)) if match else None
            seen.add((name, sha))
            rows.append({
                "id": "file:" + sha1(str(receipt)),
                "ts": mtime(receipt), "job": name, "sha": sha,
                "writes": writes, "ok": ok, "status": body.get("status"),
            })
    return rows


def scan_schedule(home: Path, errors: list[str]) -> list[dict]:
    rows = []
    for event in read_jsonl(home / "cos" / "state" / "ledger" / "schedule.jsonl", errors):
        rows.append({
            "id": event.get("id") or sha1(str(event.get("ts")), str(event.get("slot")), str(event.get("msg"))),
            "ts": event.get("ts"), "slot": event.get("slot"), "msg": event.get("msg") or "",
        })
    log = home / "cos" / "state" / "sched.log"
    if log.is_file():
        for line in log.read_text(errors="replace").splitlines():
            parts = line.split(" ", 2)
            if len(parts) < 3:
                continue
            ts = local_to_utc(parts[0])
            slot, msg = parts[1], parts[2]
            if any(row["slot"] == slot and row["msg"] == msg and row["ts"] and seconds_between(row["ts"], ts) <= 2 for row in rows):
                continue
            rows.append({"id": "log:" + sha1(line), "ts": ts, "slot": slot, "msg": msg})
    return rows


def scan_corrections(home: Path, errors: list[str]) -> list[dict]:
    rows = []
    seen = set()
    path = home / "cos" / "state" / "corrections.jsonl"
    for event in read_jsonl(path, errors):
        ts = event.get("at") or event.get("ts")
        bot = event.get("bot") or ""
        note = redact(str(event.get("note") or ""))[:800]
        key = (ts, bot, note)
        if key in seen:
            continue
        seen.add(key)
        rows.append({"id": sha1(str(ts), bot, note), "ts": ts, "bot": bot, "note": note})
    for event in read_jsonl(home / "cos" / "state" / "ledger" / "corrections.jsonl", errors):
        ts, bot = event.get("ts"), event.get("bot") or ""
        note = redact(str(event.get("note") or ""))[:800]
        if any(row["bot"] == bot and row["note"] == note and row["ts"] and ts and seconds_between(row["ts"], ts) <= 2 for row in rows):
            continue
        rows.append({"id": event.get("id") or sha1(str(ts), bot, note), "ts": ts, "bot": bot, "note": note})
    return rows


def scan_evals(home: Path, errors: list[str]) -> list[dict]:
    rows = []
    root = home / "cos" / "evals" / "runs"
    if not root.is_dir():
        return rows
    for report in sorted(root.glob("*/report.json")):
        data = load_json(report)
        if not isinstance(data, dict):
            errors.append(f"{report}: did not parse")
            continue
        run = report.parent.name
        suite = run.split("-", 1)[0]
        rows.append({
            "run": run,
            "ts": mtime(report),
            "suite": suite,
            "arms": json.dumps(data.get("arms") or []),
            "checker_pass": json.dumps(data.get("checker_pass") or {}),
            "cost": json.dumps(data.get("cost_usd") or data.get("cost") or {}),
            "rule": data.get("rule") or "",
        })
    return rows


def scan_board(home: Path) -> tuple[list[str], list[dict]]:
    path = home / "cos" / "state" / "board-health.csv"
    if not path.is_file():
        return [], []
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = [name.strip() for name in (reader.fieldnames or []) if name]
        rows = [dict(row) for row in reader]
    return fieldnames, rows


def ledger_events(home: Path, name: str, errors: list[str]) -> list[dict]:
    return read_jsonl(home / "cos" / "state" / "ledger" / f"{name}.jsonl", errors)


def schema(conn: sqlite3.Connection, board_cols: list[str]) -> None:
    conn.executescript("""
    CREATE TABLE IF NOT EXISTS jobs (
      job TEXT PRIMARY KEY, lane TEXT, bot TEXT, caller TEXT, started TEXT, ended TEXT,
      secs INTEGER, exit_code INTEGER, status TEXT, checker TEXT, checker_failures TEXT,
      verifier_level TEXT, baseline_reading TEXT, cost_usd REAL, engine TEXT, summary TEXT,
      needs_approval INTEGER, needs_approval_json TEXT, artifacts INTEGER, batch_sha TEXT,
      batch_writes INTEGER, async TEXT, folder TEXT, verifier_json TEXT, has_codex INTEGER
    );
    CREATE TABLE IF NOT EXISTS files (
      job TEXT, path TEXT, op TEXT, PRIMARY KEY (job, path, op)
    );
    CREATE TABLE IF NOT EXISTS commands (
      job TEXT, seq INTEGER, command TEXT, tool TEXT, PRIMARY KEY (job, seq)
    );
    CREATE TABLE IF NOT EXISTS gate_events (
      id TEXT PRIMARY KEY, ts TEXT, decision TEXT, rule TEXT, tool TEXT,
      job TEXT, lane TEXT, mode TEXT, cmd TEXT, path TEXT
    );
    CREATE TABLE IF NOT EXISTS pushes (
      id TEXT PRIMARY KEY, ts TEXT, bot TEXT, slot TEXT, job TEXT, code TEXT
    );
    CREATE TABLE IF NOT EXISTS applies (
      id TEXT PRIMARY KEY, ts TEXT, job TEXT, sha TEXT, writes INTEGER, ok INTEGER, status TEXT
    );
    CREATE TABLE IF NOT EXISTS schedule (
      id TEXT PRIMARY KEY, ts TEXT, slot TEXT, msg TEXT
    );
    CREATE TABLE IF NOT EXISTS corrections (
      id TEXT PRIMARY KEY, ts TEXT, bot TEXT, note TEXT
    );
    CREATE TABLE IF NOT EXISTS evals (
      run TEXT PRIMARY KEY, ts TEXT, suite TEXT, arms TEXT, checker_pass TEXT, cost TEXT, rule TEXT
    );
    CREATE TABLE IF NOT EXISTS pauses (
      id TEXT PRIMARY KEY, ts TEXT, slot TEXT, days INTEGER, until TEXT
    );
    CREATE TABLE IF NOT EXISTS loads (
      id INTEGER PRIMARY KEY AUTOINCREMENT, started TEXT, ended TEXT, counts TEXT, errors TEXT
    );
    CREATE INDEX IF NOT EXISTS jobs_started ON jobs(started);
    CREATE INDEX IF NOT EXISTS gate_ts ON gate_events(ts);
    CREATE INDEX IF NOT EXISTS schedule_slot ON schedule(slot, ts);
    """)
    cols = board_cols or ["as_of"]
    existing = {row[1] for row in conn.execute("PRAGMA table_info(board_health)")}
    if not existing:
        definitions = ", ".join(
            f'"{col}" TEXT' + (" PRIMARY KEY" if col == "as_of" else "") for col in cols
        )
        if "as_of" not in cols:
            definitions = '"as_of" TEXT PRIMARY KEY, ' + definitions
        conn.execute(f"CREATE TABLE board_health ({definitions})")
    else:
        for col in cols:
            if col not in existing:
                conn.execute(f'ALTER TABLE board_health ADD COLUMN "{col}" TEXT')


def replace_all(conn: sqlite3.Connection, jobs, files, commands, gates, pushes, applies, schedule, corrections, evals, pauses, board_cols, board_rows) -> None:
    for table in DATA_TABLES:
        conn.execute(f"DELETE FROM {table}")
    conn.executemany(
        """INSERT INTO jobs (job, lane, bot, caller, started, ended, secs, exit_code, status, checker,
           checker_failures, verifier_level, baseline_reading, cost_usd, engine, summary, needs_approval,
           needs_approval_json, artifacts, batch_sha, batch_writes, async, folder, verifier_json, has_codex)
           VALUES (:job,:lane,:bot,:caller,:started,:ended,:secs,:exit_code,:status,:checker,
           :checker_failures,:verifier_level,:baseline_reading,:cost_usd,:engine,:summary,:needs_approval,
           :needs_approval_json,:artifacts,:batch_sha,:batch_writes,:async,:folder,:verifier_json,:has_codex)""",
        jobs,
    )
    conn.executemany("INSERT OR REPLACE INTO files (job, path, op) VALUES (?,?,?)", files)
    conn.executemany("INSERT OR REPLACE INTO commands (job, seq, command, tool) VALUES (?,?,?,?)", commands)
    conn.executemany(
        """INSERT INTO gate_events (id, ts, decision, rule, tool, job, lane, mode, cmd, path)
           VALUES (:id,:ts,:decision,:rule,:tool,:job,:lane,:mode,:cmd,:path)""",
        gates,
    )
    conn.executemany(
        "INSERT INTO pushes (id, ts, bot, slot, job, code) VALUES (:id,:ts,:bot,:slot,:job,:code)",
        pushes,
    )
    conn.executemany(
        "INSERT INTO applies (id, ts, job, sha, writes, ok, status) VALUES (:id,:ts,:job,:sha,:writes,:ok,:status)",
        applies,
    )
    conn.executemany("INSERT INTO schedule (id, ts, slot, msg) VALUES (:id,:ts,:slot,:msg)", schedule)
    conn.executemany("INSERT INTO corrections (id, ts, bot, note) VALUES (:id,:ts,:bot,:note)", corrections)
    conn.executemany(
        "INSERT INTO evals (run, ts, suite, arms, checker_pass, cost, rule) VALUES (:run,:ts,:suite,:arms,:checker_pass,:cost,:rule)",
        evals,
    )
    conn.executemany(
        "INSERT INTO pauses (id, ts, slot, days, until) VALUES (:id,:ts,:slot,:days,:until)",
        pauses,
    )
    if board_rows:
        cols = [col for col in board_cols if col]
        if "as_of" not in cols:
            cols = ["as_of"] + cols
        quoted = ", ".join(f'"{col}"' for col in cols)
        marks = ", ".join("?" for _ in cols)
        conn.executemany(
            f"INSERT INTO board_health ({quoted}) VALUES ({marks})",
            [[row.get(col) for col in cols] for row in board_rows],
        )


def build(home: Path) -> dict:
    errors: list[str] = []
    jobs, files, commands = scan_jobs(home, errors)
    gates = []
    for event in ledger_events(home, "gate", errors):
        gates.append({
            "id": event.get("id") or sha1(str(event.get("ts")), str(event.get("rule")), str(event.get("cmd"))),
            "ts": event.get("ts"), "decision": event.get("decision"), "rule": event.get("rule"),
            "tool": event.get("tool"), "job": event.get("job"), "lane": event.get("lane"),
            "mode": event.get("mode"),
            "cmd": redact(str(event.get("cmd") or ""))[:300],
            "path": redact(str(event.get("path") or ""))[:800],
        })
    pushes = []
    for event in ledger_events(home, "pushes", errors):
        pushes.append({
            "id": event.get("id") or sha1(str(event.get("ts")), str(event.get("bot")), str(event.get("job"))),
            "ts": event.get("ts"), "bot": event.get("bot"), "slot": event.get("slot"),
            "job": event.get("job"), "code": event.get("code"),
        })
    applies = scan_applies(home, ledger_events(home, "applies", errors), errors)
    schedule = scan_schedule(home, errors)
    corrections = scan_corrections(home, errors)
    evals = scan_evals(home, errors)
    pauses = []
    for event in ledger_events(home, "pauses", errors):
        pauses.append({
            "id": event.get("id") or sha1(str(event.get("ts")), str(event.get("slot"))),
            "ts": event.get("ts"), "slot": event.get("slot"),
            "days": to_int(event.get("days")), "until": event.get("until"),
        })
    board_cols, board_rows = scan_board(home)
    # Drop the session id before insert. It is a join key, not a column we keep.
    for row in jobs:
        row.pop("session_id", None)
    return {
        "jobs": jobs, "files": files, "commands": commands, "gates": gates, "pushes": pushes,
        "applies": applies, "schedule": schedule, "corrections": corrections, "evals": evals,
        "pauses": pauses, "board_cols": board_cols, "board_rows": board_rows, "errors": errors,
    }


def connect(db: Path) -> sqlite3.Connection:
    db.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db, timeout=5)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def run_load(home: Path, db: Path) -> int:
    started = utc_now()
    payload = build(home)
    conn = connect(db)
    try:
        schema(conn, payload["board_cols"])
        conn.execute(
            "INSERT INTO loads (started, ended, counts, errors) VALUES (?, ?, ?, ?)",
            (started, None, "{}", ""),
        )
        load_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
        conn.commit()
        with conn:
            replace_all(
                conn, payload["jobs"], payload["files"], payload["commands"], payload["gates"],
                payload["pushes"], payload["applies"], payload["schedule"], payload["corrections"],
                payload["evals"], payload["pauses"], payload["board_cols"], payload["board_rows"],
            )
        counts = {table: conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] for table in DATA_TABLES}
        ended = utc_now()
        conn.execute(
            "UPDATE loads SET ended = ?, counts = ?, errors = ? WHERE id = ?",
            (ended, json.dumps(counts), "\n".join(payload["errors"]), load_id),
        )
        conn.commit()
    finally:
        conn.close()
    print(json.dumps({"counts": counts, "errors": payload["errors"]}, indent=2))
    return 0


def run_sql(db: Path, query: str) -> int:
    stripped = query.strip().rstrip(";")
    if not re.match(r"(?is)select\b", stripped) or ";" in stripped:
        print("read-only: one SELECT", file=sys.stderr)
        return 2
    if not db.is_file():
        print("no database yet (cos-db load)", file=sys.stderr)
        return 1
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=5)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    conn.execute("PRAGMA busy_timeout=5000")
    try:
        rows = conn.execute(stripped).fetchall()
    finally:
        conn.close()
    print(json.dumps([dict(row) for row in rows], default=str))
    return 0


def main(argv: list[str]) -> int:
    home = Path(os.environ.get("HOME", "")).expanduser()
    db = Path(os.environ.get("COS_DB", home / "cos" / "state" / "cos.db"))
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "rebuild":
        for suffix in ("", "-wal", "-shm"):
            path = Path(str(db) + suffix) if suffix else db
            if path.is_file():
                path.unlink()
        return run_load(home, db)
    if cmd == "load":
        return run_load(home, db)
    if cmd == "sql":
        if len(argv) < 3:
            print("cos-db sql \"select ...\"", file=sys.stderr)
            return 2
        return run_sql(db, argv[2])
    print("usage: cos-db load | rebuild | sql \"select ...\"", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
