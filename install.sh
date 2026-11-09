#!/bin/bash
# install.sh: install or update the chief-of-staff kit, then prove the walls hold.
# Safe to re-run. No model is called.
#   ./install.sh               install + self-test
#   ./install.sh --online      also run board-pulse once (read-only GitHub calls)
#   ./install.sh --schedule    also (re)load the launchd schedule (cos-sched list shows it)
#   ./install.sh --schedule=followups,pulse   load only those slots
#   ./install.sh --schedule=dashboard         also load com.cos.dashboard (cos-db load every 300s)
#   ./install.sh --unschedule  remove the launchd schedule, including the dashboard
# Writes to: ~/cos, ~/builds, ~/.claude/skills/cassidy-mode, ~/.cursor/skills/cassidy-mode,
#            ~/.claude/CLAUDE.md (only if it doesn't exist), ~/Library/LaunchAgents/com.cos.* (only with --schedule).
set -uo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"; COS="$HOME/cos"; ONLINE=0; SCHEDULE=0; UNSCHEDULE=0
ONLY=""
for a in "$@"; do case "$a" in --online) ONLINE=1;; --schedule) SCHEDULE=1;; --schedule=*) SCHEDULE=1; ONLY="${a#--schedule=}";; --unschedule) UNSCHEDULE=1;; *) echo "unknown: $a" >&2; exit 64;; esac; done
ok=0; bad=0; pass() { printf '  ✓ %s\n' "$1"; ok=$((ok+1)); }; fail() { printf '  ✗ %s\n' "$1"; bad=$((bad+1)); }
LA="$HOME/Library/LaunchAgents"; SLOTS="followups pulse reconcile capture week opportunity keeper"

if [[ $UNSCHEDULE -eq 1 ]]; then
  for s in $SLOTS dashboard; do launchctl bootout "gui/$(id -u)/com.cos.$s" 2>/dev/null; rm -f "$LA/com.cos.$s.plist"; done
  echo "Schedule removed."; exit 0
fi

echo "1. Prerequisites"
for c in claude agent gh jq git perl shasum uv openssl rsync bc curl security launchctl python3; do command -v $c >/dev/null && pass "$c" || fail "$c not on PATH"; done
gh auth status >/dev/null 2>&1 && pass "gh signed in" || fail "gh not signed in (gh auth login)"
[[ -d "$HOME/Documents/Data-Org-Repos/data-org/.git" ]] && pass "data-org repo" || fail "data-org repo missing at ~/Documents/Data-Org-Repos/data-org"
[[ -f "$HOME/Documents/Data-Org-Repos/data-org-notebook/scripts/run_query.py" ]] && pass "data-org-notebook (lake-query)" || fail "data-org-notebook missing (lake-query won't work)"
[[ -d "$HOME/meetings" ]] && pass "~/meetings" || fail "~/meetings missing"

echo "2. The kit, versioned"
# ~/cos/kit is the only source (a git repo, pushed to github.com/cassidythilton/cos-kit). Edit there, commit with a real
# message, then run this installer from it. A copy elsewhere may only seed a kit that doesn't exist yet.
if [[ "$KIT" != "$COS/kit" ]]; then
  if [[ -d "$COS/kit/.git" ]]; then echo "  ✗ ~/cos/kit already exists. Edit and install from it: cd ~/cos/kit && ./install.sh"; exit 1; fi
  mkdir -p "$COS/kit"; rsync -a --exclude .git "$KIT/" "$COS/kit/"; git -C "$COS/kit" init -q -b main
  git -C "$COS/kit" add -A && git -C "$COS/kit" commit -qm "Seed kit" && pass "seeded ~/cos/kit"
fi
if [[ -n "$(git -C "$COS/kit" status --porcelain)" ]]; then fail "~/cos/kit has uncommitted changes: commit them with a message first (git -C ~/cos/kit commit -am '<why>')"
else pass "~/cos/kit clean at $(git -C "$COS/kit" log -1 --format=%h)"; fi
if git -C "$COS/kit" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  ahead="$(git -C "$COS/kit" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  [[ "$ahead" -eq 0 ]] && pass "~/cos/kit matches GitHub" || printf '  · %s commit(s) not pushed yet (git -C ~/cos/kit push)\n' "$ahead"
fi

echo "3. Files"
mkdir -p "$COS"/{bin,claude/briefs,handbook,outbox,state,archive,evals/runs} "$HOME/builds"
install -m 755 "$KIT"/claude/{cos-run,cos-sched,cos-push,board-pulse,lake-query,cos-ledger,cos-db,cos-dash} "$COS/bin/"
install -m 755 "$KIT/claude/gate.sh" "$COS/claude/"
install -m 644 "$KIT"/claude/{agents.json,receipt.schema.json,settings.investigate.json,settings.draft.json,settings.build.json,lane.md,build-lane.md,verifier.md} "$COS/claude/"
install -m 644 "$KIT"/claude/briefs/*.md "$COS/claude/briefs/"
install -m 644 "$KIT"/evals/*.json "$COS/evals/"
rm -rf "$COS/builds-template.new" && cp -R "$KIT/builds-template" "$COS/builds-template.new" && rm -rf "$COS/builds-template" && mv "$COS/builds-template.new" "$COS/builds-template"
backup_then_install() {  # kit-owned file: keep a backup if the installed copy was changed by hand
  local src="$1" dst="$2"; mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then cp "$dst" "$dst.bak-$(date +%Y%m%d%H%M%S)"; fi
  install -m 644 "$src" "$dst"; }
for f in rules.md board-standard.md engineering-standard.md system-map.md; do backup_then_install "$KIT/handbook/$f" "$COS/handbook/$f"; done
for f in people.md workstreams.md sources.md; do [[ -f "$COS/handbook/$f" ]] || printf '# %s\n\nFill this in. The kit never overwrites it.\n' "${f%.md}" > "$COS/handbook/$f"; done
touch "$COS/state/corrections.jsonl"
mkdir -p "$COS/state/ledger"
pass "installed to $COS (kit-owned handbook files backed up if they changed; yours untouched)"

echo "4. cassidy-mode, for Claude and Cursor"
backup_then_install "$KIT/claude-skills/cassidy-mode/SKILL.md" "$HOME/.claude/skills/cassidy-mode/SKILL.md"
backup_then_install "$KIT/claude-skills/cassidy-mode/SKILL.md" "$HOME/.cursor/skills/cassidy-mode/SKILL.md"
pass "skill installed in ~/.claude/skills and ~/.cursor/skills"
if [[ ! -f "$HOME/.claude/CLAUDE.md" ]]; then
  printf '# How I work\n\nEvery session, in every project: work in cassidy-mode.\n\n@~/.claude/skills/cassidy-mode/SKILL.md\n' > "$HOME/.claude/CLAUDE.md"
  pass "created ~/.claude/CLAUDE.md, which loads cassidy-mode in every Claude session"
elif grep -q 'cassidy-mode' "$HOME/.claude/CLAUDE.md"; then pass "~/.claude/CLAUDE.md already loads cassidy-mode"
else fail "~/.claude/CLAUDE.md exists and doesn't load cassidy-mode. Add this line to it yourself: @~/.claude/skills/cassidy-mode/SKILL.md"; fi

echo "5. Scripts parse"
for s in "$COS"/bin/* "$COS/claude/gate.sh" "$COS/builds-template/verify"; do bash -n "$s" && pass "$(basename "$s")" || fail "$(basename "$s") syntax"; done
for j in "$COS"/claude/*.json "$COS"/evals/*.json "$COS/builds-template/.claude/settings.json"; do jq empty "$j" 2>/dev/null && pass "$(basename "$j")" || fail "$(basename "$j") is not valid JSON"; done
for s in $SLOTS; do [[ "$s" == pulse || -f "$COS/claude/briefs/$s.md" ]] && pass "brief: $s" || fail "brief missing: $s"; done

echo "6. The gate (job mode = blocked, pair mode = asks, hard walls = always blocked)"
# COS_LEDGER_OFF: these probes are not Mac actions, so they must not land in the real ledger.
g() { printf '{"tool_name":"%s","tool_input":{"command":%s,"file_path":%s}}' "$1" "$(jq -Rn --arg c "$2" '$c')" "$(jq -Rn --arg c "${4:-}" '$c')" | COS_LEDGER_OFF=1 COS_GATE_MODE="$3" "$COS/claude/gate.sh" >/tmp/cos-gate.$$ 2>/dev/null; local rc=$?
      if [[ $rc -eq 2 ]]; then echo block; elif grep -q '"ask"' /tmp/cos-gate.$$; then echo ask; else echo allow; fi; }
chk() { local got; got="$(g Bash "$1" "$2")"; [[ "$got" == "$3" ]] && pass "$2 · $3 · $1" || fail "$2 · expected $3, got $got · $1"; }
chk "make board" job allow
chk "uv run pytest -q" job allow
chk "gh issue comment 1 -b hi" job block
chk "gh issue comment 1 -b hi" pair ask
chk "git push origin build/x" job block
chk "git push origin build/x" pair ask
chk "git push origin main" pair block
chk "terraform apply" pair block
chk "aws s3 sync . s3://b" pair block
chk 'psql "host=prod" -c "delete from food"' pair block
chk "select name from wisecode_gold.canon_term" pair block
chk "select count(*) from wisecode_gold.canon_term group by 1" pair allow
chk "cat .env" pair block
chk "EXECUTE=1 make intake-sweep" job block
chk "DRY_RUN=1 make ragb CARD=1 TO=RED" job allow
chk "cos-push steward pulse r.json" pair block
chk "launchctl list" job block
chk "git -C ~/cos/kit commit -am x" pair block
chk "echo x > ~/cos/claude/lane.md" pair block
chk "cat ~/cos/claude/lane.md" job allow
chk "cat ~/cos/handbook/rules.md 2>&1 | head -50" job allow
chk "cp ~/cos/handbook/rules.md /tmp/r.md" job allow
chk "make intake-sweep" job allow
chk "EXECUTE=1 make intake-sweep" job block
got="$(g Write "" pair "$HOME/.claude/skills/cassidy-mode/SKILL.md")"; [[ "$got" == block ]] && pass "pair · block · writing a skill" || fail "a job could write a skill ($got)"
got="$(g Write "" job "$COS/outbox/x/a.md")"; [[ "$got" == allow ]] && pass "job · allow · writing in the job folder" || fail "job folder write blocked ($got)"
got="$(printf '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{}}' | COS_GATE_MODE=job "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?)"
[[ "$got" == 2 ]] && pass "job · block · Slack send" || fail "Slack send not blocked in job mode"
rm -f /tmp/cos-gate.$$

echo "7. The lanes refuse what they should"
T="$(mktemp -d)"; mkdir -p "$T/cos/outbox/t1"
echo "gh issue close 1 --repo wisecodeai/data-org" > "$T/cos/outbox/t1/apply.sh"; S="$(shasum -a 256 "$T/cos/outbox/t1/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t1 "$S" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t1/applied.log" ]] && pass "apply refuses a close" || fail "apply ran a close"
HOME="$T" "$COS/bin/cos-run" apply t1 deadbeef --in "$T" >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "apply refuses a changed batch (hash mismatch)" || fail "apply ignored the hash"
HOME="$T" "$COS/bin/cos-run" note steward "test note" >/dev/null 2>&1 && [[ "$(jq -r .bot "$T/cos/state/corrections.jsonl" 2>/dev/null)" == steward ]] && pass "note records a correction" || fail "note did not record"
HOME="$T" "$COS/bin/cos-run" note nobody "x" >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "note refuses an unknown bot" || fail "note accepted an unknown bot"
HOME="$T" "$COS/bin/cos-run" eval nosuchsuite current >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "eval refuses a missing suite" || fail "eval ran without a suite"
"$COS/bin/cos-push" nobody pulse /dev/null >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-push refuses an unknown bot" || fail "cos-push accepted an unknown bot"
"$COS/bin/cos-sched" list >/dev/null 2>&1 && pass "cos-sched lists the schedule" || fail "cos-sched list"
HOME="$T" "$COS/bin/cos-run" pause keeper 3 >/dev/null 2>&1 && [[ -f "$T/cos/state/pause-keeper" ]] && pass "pause holds a slot" || fail "pause did not write"
HOME="$T" "$COS/bin/cos-run" pause keeper 0 >/dev/null 2>&1 && [[ ! -f "$T/cos/state/pause-keeper" ]] && pass "pause 0 resumes" || fail "pause 0 did not resume"
HOME="$T" "$COS/bin/cos-run" pause nosuch 3 >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "pause refuses an unknown slot" || fail "pause accepted an unknown slot"
HOME="$T" "$COS/bin/cos-run" receipt nosuchjob >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "receipt reports a missing job" || fail "receipt on a missing job"
HOME="$T" "$COS/bin/cos-run" quick x1 "q" --async >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "--async refuses the quick lane" || fail "--async accepted the quick lane"
"$COS/bin/cos-sched" nosuchslot --dry-run >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-sched refuses an unknown slot" || fail "cos-sched accepted an unknown slot"
rm -rf "$T"

echo "8. lake-query refuses what it should"
T="$(mktemp -d)"; echo "select name from wisecode_gold.canon_ingredient limit 5" > "$T/a.sql"; echo "delete from food" > "$T/b.sql"; echo "select * from food" > "$T/c.sql"
"$COS/bin/lake-query" "$T/a.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "canon values blocked" || fail "canon values not blocked"
"$COS/bin/lake-query" "$T/b.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "writes blocked" || fail "writes not blocked"
"$COS/bin/lake-query" "$T/c.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "unbounded query blocked" || fail "unbounded query not blocked"
rm -rf "$T"

echo "11. Flight recorder"
T="$(mktemp -d)"
mkdir -p "$T/cos/bin" "$T/cos/state/ledger" "$T/cos/outbox/fixjob" "$T/cos/outbox/pulse-20261109" \
  "$T/.claude/projects/demo/sess/subagents" "$T/cos/evals/runs/core-20261109"
cp "$COS/bin/cos-ledger" "$T/cos/bin/cos-ledger"
HOME="$T" "$T/cos/bin/cos-ledger" jobs event=start job=fixjob lane=investigate caller=bot async=0 pid=$$ >/dev/null
jq -e '.stream=="jobs" and .event=="start" and .id and .ts' "$T/cos/state/ledger/jobs.jsonl" >/dev/null 2>&1 \
  && pass "cos-ledger appends one JSON line" || fail "cos-ledger did not append"
chmod 555 "$T/cos/state/ledger"
HOME="$T" "$T/cos/bin/cos-ledger" jobs event=end job=fixjob >/dev/null
unwritable=$?
chmod 755 "$T/cos/state/ledger"
[[ $unwritable -eq 0 ]] && pass "cos-ledger exits 0 when the folder is not writable" || fail "cos-ledger failed on an unwritable folder ($unwritable)"
HOME="$T" "$T/cos/bin/cos-ledger" jobs cmd="echo ghp_FAKETOKEN123 and https://api2.cursor.sh/automations/secret/hook" >/dev/null
secret_line="$(tail -1 "$T/cos/state/ledger/jobs.jsonl")"
if [[ "$secret_line" != *ghp_FAKETOKEN123* && "$secret_line" != *api2.cursor.sh* && "$secret_line" == *"<redacted>"* && "$secret_line" == *"<webhook>"* ]]; then
  pass "redaction removes a token and a webhook URL"
else fail "redaction left a secret: $secret_line"; fi
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 1 -b hi"}}' \
  | HOME="$T" COS_JOB=fixjob COS_LANE=investigate COS_GATE_MODE=job "$COS/claude/gate.sh" >/tmp/cos-fr-gate.out 2>/tmp/cos-fr-gate.err
gate_rc=$?
[[ $gate_rc -eq 2 && "$(head -1 /tmp/cos-fr-gate.err)" == BLOCKED\ by\ chief-of-staff\ gate:* ]] \
  && pass "gate still blocks, and the message is unchanged" || fail "gate block changed (rc $gate_rc)"
jq -e 'select(.decision=="block" and .job=="fixjob" and .lane=="investigate")' "$T/cos/state/ledger/gate.jsonl" >/dev/null 2>&1 \
  && pass "a block writes a gate line" || fail "a block wrote no gate line"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 1 -b hi"}}' \
  | HOME="$T" COS_GATE_MODE=pair "$COS/claude/gate.sh" >/tmp/cos-fr-gate.out 2>/tmp/cos-fr-gate.err
gate_rc=$?
[[ $gate_rc -eq 0 ]] && jq -e '.hookSpecificOutput.permissionDecision=="ask"' /tmp/cos-fr-gate.out >/dev/null \
  && pass "gate still asks in pair mode" || fail "gate ask changed (rc $gate_rc)"
before="$(wc -l < "$T/cos/state/ledger/gate.jsonl" | tr -d ' ')"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"make board"}}' \
  | HOME="$T" COS_GATE_MODE=job "$COS/claude/gate.sh" >/dev/null 2>&1
after="$(wc -l < "$T/cos/state/ledger/gate.jsonl" | tr -d ' ')"
[[ "$before" == "$after" ]] && pass "an allow writes no gate line" || fail "an allow wrote a gate line"
HOME="$T" python3 -I -B - "$T" <<'PY'
import json, pathlib, sys
home = pathlib.Path(sys.argv[1])
job = home / "cos/outbox/fixjob"
job.joinpath("brief.md").write_text("fixture brief\n")
job.joinpath("receipt.json").write_text(json.dumps({
    "job": "fixjob", "lane": "investigate", "engine": "claude", "cost_usd": 0.2, "session_id": "sess",
    "receipt": {"status": "done", "summary": "fixture", "needs_approval": [{"action": "echo ghp_FILETOKEN99", "target": "t", "why": "w"}]},
    "checker": {"verdict": "pass", "failures": []},
    "batch": {"sha256": "abc", "writes": 1},
}))
job.joinpath("checker.json").write_text(json.dumps({"total_cost_usd": 0.05, "structured_output": {"verdict": "pass", "failures": []}}))
job.joinpath("apply.sh").write_text("echo ok\n")
job.joinpath("apply-receipt.json").write_text(json.dumps({"receipt": {"status": "done", "summary": "1 of 1"}}))
transcript = {
    "message": {"content": [
        {"type": "tool_use", "name": "Read", "input": {"file_path": "/tmp/fixture.md"}},
        {"type": "tool_use", "name": "Bash", "input": {"command": "echo ghp_TRANSCRIPTTOKEN and hello"}},
        {"type": "tool_use", "name": "mcp__demo__search", "input": {}},
        {"type": "tool_result", "content": "SHOULD_NOT_BE_STORED"},
    ]}
}
(home / ".claude/projects/demo/sess.jsonl").write_text(json.dumps(transcript) + "\n")
quick = home / "cos/outbox/pulse-20261109"
quick.joinpath("brief.md").write_text("pulse\n")
quick.joinpath("context.txt").write_text("$ make stale\n")
quick.joinpath("receipt.json").write_text(json.dumps({
    "job": "pulse-20261109", "lane": "quick", "engine": "cursor-agent",
    "receipt": {"status": "done", "summary": "pulse"},
}))
(home / "cos/state/corrections.jsonl").write_text(json.dumps({"at": "2026-11-09T12:00:00Z", "bot": "chief", "note": "fixture note"}) + "\n")
(home / "cos/state/sched.log").write_text("2026-11-09T09:15:00 followups skipped: outside 5-9\n")
(home / "cos/state/board-health.csv").write_text("as_of,stale\n2026-11-09,1\n")
(home / "cos/evals/runs/core-20261109/report.json").write_text(json.dumps({
    "run": "core-20261109", "arms": [{"arm": "current"}], "checker_pass": {}, "cost_usd": {}, "rule": "fixture",
}))
PY
HOME="$T" "$T/cos/bin/cos-ledger" pushes bot=steward slot=pulse job=pulse-20261109 code=200 >/dev/null
HOME="$T" "$T/cos/bin/cos-ledger" schedule slot=pulse msg="pushed to steward" >/dev/null
HOME="$T" "$T/cos/bin/cos-ledger" pauses slot=keeper days=3 until=2026-11-12 >/dev/null
HOME="$T" "$T/cos/bin/cos-ledger" applies job=fixjob sha=abc writes=1 ok=1 status=done >/dev/null
if HOME="$T" python3 -I -B "$KIT/claude/cos_db.py" load >/tmp/cos-fr-load.json; then
  pass "cos-db load builds the database"
else fail "cos-db load failed"; fi
if HOME="$T" python3 -I -B "$KIT/claude/cos_db.py" load >/tmp/cos-fr-load2.json; then
  python3 -I -B - "$T" <<'PY'
import json, sqlite3, sys
db = sys.argv[1] + "/cos/state/cos.db"
con = sqlite3.connect(db)
tables = ["jobs","files","commands","gate_events","pushes","applies","schedule","corrections","evals","board_health","pauses"]
counts = {name: con.execute(f"SELECT COUNT(*) FROM {name}").fetchone()[0] for name in tables}
first = json.load(open("/tmp/cos-fr-load.json"))["counts"]
second = json.load(open("/tmp/cos-fr-load2.json"))["counts"]
blob = " ".join(" ".join(str(cell) for cell in row) for name in tables for row in con.execute(f"SELECT * FROM {name}"))
missing = [name for name, n in counts.items() if n < 1]
cost = con.execute("SELECT cost_usd FROM jobs WHERE job='fixjob'").fetchone()[0]
bot = con.execute("SELECT bot, caller FROM jobs WHERE job='pulse-20261109'").fetchone()
loads = con.execute("SELECT COUNT(*) FROM loads").fetchone()[0]
bad = []
if first != second: bad.append("counts changed between loads")
if missing: bad.append("empty " + ",".join(missing))
if abs((cost or 0) - 0.25) > 0.001: bad.append(f"cost {cost}")
if bot != ("STEWARD", "sched"): bad.append(f"pulse {bot}")
if "ghp_" in blob or "SHOULD_NOT_BE_STORED" in blob: bad.append("secret stored")
if loads != 2: bad.append(f"loads {loads}")
print("OK" if not bad else "BAD " + "; ".join(bad))
PY
else
  echo "BAD load"
fi > /tmp/cos-fr-counts.txt
[[ "$(cat /tmp/cos-fr-counts.txt)" == OK ]] && pass "two loads, same tables, no secrets stored" || fail "loader check: $(cat /tmp/cos-fr-counts.txt)"
HOME="$T" python3 -I -B "$KIT/claude/cos_db.py" sql "DELETE FROM jobs" >/dev/null 2>&1
sql_rc=$?
[[ $sql_rc -ne 0 ]] && pass "cos-db sql refuses a write" || fail "cos-db sql ran a write"
fr_port=18787
COS_DASH_PORT=$fr_port COS_DB="$T/cos/state/cos.db" HOME="$T" python3 -I -B "$KIT/apps/flight-recorder/server.py" >/tmp/cos-fr-api.log 2>&1 &
fr_pid=$!
fr_up=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  curl -sf -o /dev/null "http://127.0.0.1:$fr_port/api/summary?window=1d" && fr_up=1 && break
  sleep 0.2
done
fr_post="$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$fr_port/api/summary")"
fr_bind="$(lsof -nP -iTCP:$fr_port -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $9}' | head -1)"
kill "$fr_pid" 2>/dev/null; wait "$fr_pid" 2>/dev/null
[[ $fr_up -eq 1 && "$fr_bind" == "127.0.0.1:$fr_port" ]] && pass "API binds only 127.0.0.1" || fail "API bind was '$fr_bind' (up $fr_up)"
[[ "$fr_post" == 405 ]] && pass "API refuses a write" || fail "API POST returned $fr_post"
timing_ms="$(python3 -I -B - "$COS/claude/gate.sh" "$T" <<'PY'
import os, subprocess, sys, time
gate, home = sys.argv[1], sys.argv[2]
payload = '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 1 -b hi"}}'
base = os.environ.copy()
base["HOME"] = home
base["COS_GATE_MODE"] = "job"
off = dict(base)
off["COS_LEDGER_OFF"] = "1"
on = dict(base)
def once(env):
    t = time.perf_counter()
    subprocess.run(["/bin/bash", gate], input=payload, text=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return time.perf_counter() - t
slow = fast = 0.0
for _ in range(100):
    fast += once(off)
    slow += once(on)
added = (slow - fast) / 100 * 1000
print(f"{added:.2f}")
sys.exit(0 if added < 20 else 1)
PY
)"
timing_rc=$?
[[ $timing_rc -eq 0 ]] && pass "gate logging adds ${timing_ms} ms a call, under 20" || fail "gate logging adds ${timing_ms} ms a call"
rm -rf "$T" /tmp/cos-fr-gate.out /tmp/cos-fr-gate.err /tmp/cos-fr-load.json /tmp/cos-fr-load2.json /tmp/cos-fr-counts.txt /tmp/cos-fr-api.log

if [[ $ONLINE -eq 1 ]]; then
  echo "9. Board read (read-only)"
  "$COS/bin/board-pulse" --json >/dev/null 2>&1 && pass "board-pulse" || fail "board-pulse (check gh auth and network)"
  for b in ops steward builder keeper; do
    security find-generic-password -a cos -s "cos-webhook-$b" >/dev/null 2>&1 && pass "webhook key for $b in Keychain" || printf '  · no webhook key for %s yet (INSTALL.md step 4)\n' "$b"
  done
fi

if [[ $SCHEDULE -eq 1 ]]; then
  echo "10. Schedule (launchd)"
  mkdir -p "$LA"
  "$COS/bin/cos-sched" list | while IFS='|' read -r slot when _ _ _; do
    slot="$(echo "$slot" | tr -d ' ')"; [[ -n "$ONLY" && ",$ONLY," != *",$slot,"* ]] && continue; days="$(echo "$when" | awk '{print $1}')"; hm="$(echo "$when" | awk '{print $2}')"
    H=$((10#${hm%:*})); M=$((10#${hm#*:}))
    case "$days" in *-*) dl="$(seq "${days%-*}" "${days#*-}")";; *) dl="$(echo "$days" | tr ',' ' ')";; esac
    entries=""; for d in $dl; do entries+="<dict><key>Weekday</key><integer>$d</integer><key>Hour</key><integer>$H</integer><key>Minute</key><integer>$M</integer></dict>"; done
    P="$LA/com.cos.$slot.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.$slot</string>
<key>ProgramArguments</key><array><string>/bin/zsh</string><string>-lc</string><string>\$HOME/cos/bin/cos-sched $slot</string></array>
<key>StartCalendarInterval</key><array>$entries</array>
<key>StandardOutPath</key><string>$COS/state/launchd-$slot.log</string>
<key>StandardErrorPath</key><string>$COS/state/launchd-$slot.log</string>
</dict></plist>
PL
    plutil -lint "$P" >/dev/null && launchctl bootout "gui/$(id -u)/com.cos.$slot" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null \
      && echo "  ✓ scheduled $slot ($days $hm)" || echo "  ✗ could not load $slot"
  done
  if [[ ",${ONLY}," == *",dashboard,"* ]]; then
    P="$LA/com.cos.dashboard.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.dashboard</string>
<key>ProgramArguments</key><array><string>/bin/zsh</string><string>-lc</string><string>\$HOME/cos/bin/cos-db load</string></array>
<key>StartInterval</key><integer>300</integer>
<key>StandardOutPath</key><string>$COS/state/launchd-dashboard.log</string>
<key>StandardErrorPath</key><string>$COS/state/launchd-dashboard.log</string>
</dict></plist>
PL
    plutil -lint "$P" >/dev/null && launchctl bootout "gui/$(id -u)/com.cos.dashboard" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null \
      && echo "  ✓ scheduled dashboard (cos-db load every 300s)" || echo "  ✗ could not load dashboard"
  fi
fi

echo; echo "Result: $ok passed, $bad failed."
[[ $bad -eq 0 ]] || { echo "Fix the failures above before going further."; exit 1; }
cat <<'EOF'

Next (manual, in order). Each step is described in INSTALL.md:
  a. ~/cos/bin/cos-run quick smoke-q "Which cards are stale?" --with "make stale"            (Cursor, cents)
  b. ~/cos/bin/cos-run investigate smoke "Run make doctor and make board. Five lines."         (Claude, ~$1-3)
  c. ~/cos/bin/cos-run investigate wall-test "Comment 'test' on issue 1 in data-org."          (must come back blocked)
  d. ~/cos/bin/cos-run eval core current                                                       (baseline scores, ~$20)
  e. Grok: Chief, OPS, STEWARD (week 1); BUILDER when you pick the first build; KEEPER after two weeks.
  f. ./install.sh --schedule once the Bots' webhook keys are in the Keychain.
EOF
