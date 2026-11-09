#!/bin/bash
# install.sh: install or update the chief-of-staff kit, then prove the walls hold.
# Safe to re-run. No model is called.
#   ./install.sh               install + self-test
#   ./install.sh --online      also run board-pulse once (read-only GitHub calls)
#   ./install.sh --schedule    also (re)load the launchd schedule (cos-sched list shows it)
#   ./install.sh --schedule=followups,pulse   load only those slots
#   ./install.sh --unschedule  remove the launchd schedule
# Writes to: ~/cos, ~/builds, ~/.claude/skills/cassidy-mode, ~/.cursor/skills/cassidy-mode,
#            ~/.claude/CLAUDE.md (only if it doesn't exist), ~/Library/LaunchAgents/com.cos.* (only with --schedule).
set -uo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"; COS="$HOME/cos"; ONLINE=0; SCHEDULE=0; UNSCHEDULE=0
ONLY=""
for a in "$@"; do case "$a" in --online) ONLINE=1;; --schedule) SCHEDULE=1;; --schedule=*) SCHEDULE=1; ONLY="${a#--schedule=}";; --unschedule) UNSCHEDULE=1;; *) echo "unknown: $a" >&2; exit 64;; esac; done
ok=0; bad=0; pass() { printf '  ✓ %s\n' "$1"; ok=$((ok+1)); }; fail() { printf '  ✗ %s\n' "$1"; bad=$((bad+1)); }
LA="$HOME/Library/LaunchAgents"; SLOTS="followups pulse reconcile capture week opportunity keeper"

if [[ $UNSCHEDULE -eq 1 ]]; then
  for s in $SLOTS; do launchctl bootout "gui/$(id -u)/com.cos.$s" 2>/dev/null; rm -f "$LA/com.cos.$s.plist"; done
  echo "Schedule removed."; exit 0
fi

echo "1. Prerequisites"
for c in claude agent gh jq git perl shasum uv openssl rsync bc curl security launchctl; do command -v $c >/dev/null && pass "$c" || fail "$c not on PATH"; done
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
install -m 755 "$KIT"/claude/{cos-run,cos-sched,cos-push,board-pulse,lake-query} "$COS/bin/"
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
g() { printf '{"tool_name":"%s","tool_input":{"command":%s,"file_path":%s}}' "$1" "$(jq -Rn --arg c "$2" '$c')" "$(jq -Rn --arg c "${4:-}" '$c')" | COS_GATE_MODE="$3" "$COS/claude/gate.sh" >/tmp/cos-gate.$$ 2>/dev/null; local rc=$?
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
"$COS/bin/cos-sched" nosuchslot --dry-run >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-sched refuses an unknown slot" || fail "cos-sched accepted an unknown slot"
rm -rf "$T"

echo "8. lake-query refuses what it should"
T="$(mktemp -d)"; echo "select name from wisecode_gold.canon_ingredient limit 5" > "$T/a.sql"; echo "delete from food" > "$T/b.sql"; echo "select * from food" > "$T/c.sql"
"$COS/bin/lake-query" "$T/a.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "canon values blocked" || fail "canon values not blocked"
"$COS/bin/lake-query" "$T/b.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "writes blocked" || fail "writes not blocked"
"$COS/bin/lake-query" "$T/c.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "unbounded query blocked" || fail "unbounded query not blocked"
rm -rf "$T"

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
