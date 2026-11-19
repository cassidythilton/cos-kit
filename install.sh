#!/bin/bash
# install.sh: install or update the chief-of-staff kit, then prove the walls hold.
# Safe to re-run. No model is called.
#   ./install.sh               install + self-test
#   ./install.sh --online      also run board-pulse once (read-only GitHub calls)
#   ./install.sh --schedule    also (re)load the launchd schedule (cos-sched list shows it)
#   ./install.sh --schedule=followups,pulse   load only those slots
#   ./install.sh --schedule=dashboard         also load com.cos.dashboard (cos-db load every 300s)
#   ./install.sh --schedule=zoommirror        also load com.cos.zoommirror (copy ~/Documents/Zoom transcripts to ~/cos/zoom)
#   ./install.sh --unschedule  remove the launchd schedule, including the dashboard
#   HOME=<empty temp dir> ./install.sh --sandbox   install into that throwaway home and run every test there.
#              Touches nothing of Cassidy's: no repos, no clones, no kit checks, no apps, no schedule. Used by cos-run fix.
# Writes to: ~/cos, ~/builds, ~/.claude/skills/cassidy-mode, ~/.cursor/skills/cassidy-mode,
#            ~/.claude/CLAUDE.md (only if it doesn't exist), ~/Library/LaunchAgents/com.cos.* (only with --schedule).
set -uo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"; COS="$HOME/cos"; ONLINE=0; SCHEDULE=0; UNSCHEDULE=0; SANDBOX=0
ONLY=""
for a in "$@"; do case "$a" in --online) ONLINE=1;; --schedule) SCHEDULE=1;; --schedule=*) SCHEDULE=1; ONLY="${a#--schedule=}";; --unschedule) UNSCHEDULE=1;; --sandbox) SANDBOX=1;; *) echo "unknown: $a" >&2; exit 64;; esac; done
ok=0; bad=0; pass() { printf '  ✓ %s\n' "$1"; ok=$((ok+1)); }; fail() { printf '  ✗ %s\n' "$1"; bad=$((bad+1)); }
if [[ $SANDBOX -eq 1 ]]; then
  realhome="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  [[ -n "$realhome" && "$HOME" != "$realhome" && "$HOME" != "$realhome/" ]] || { echo "--sandbox needs HOME set to a throwaway folder, not your real home" >&2; exit 64; }
  [[ $SCHEDULE -eq 0 && $UNSCHEDULE -eq 0 && $ONLINE -eq 0 ]] || { echo "--sandbox can't schedule, unschedule or go online" >&2; exit 64; }
fi
LA="$HOME/Library/LaunchAgents"; SLOTS="followups pulse reconcile capture week opportunity keeper obligations"

if [[ $UNSCHEDULE -eq 1 ]]; then
  for s in $SLOTS dashboard zoommirror tcccheck; do launchctl bootout "gui/$(id -u)/com.cos.$s" 2>/dev/null; rm -f "$LA/com.cos.$s.plist"; done
  echo "Schedule removed."; exit 0
fi

echo "1. Prerequisites"
for c in claude agent gh jq git perl shasum shlock lsof uv openssl rsync bc curl security launchctl python3 caffeinate nc; do command -v $c >/dev/null && pass "$c" || fail "$c not on PATH"; done
# cos-run's preflight checks gh with --active (only the account gh uses). Say which this gh does; neither is a failure.
gh auth status --help 2>&1 | grep -q -- '--active' && pass "gh has auth status --active (preflight checks the active account)" \
  || pass "gh has no auth status --active: preflight falls back to gh auth status, which a stale second account fails"
if [[ $SANDBOX -eq 0 ]]; then
gh auth status >/dev/null 2>&1 && pass "gh signed in" || fail "gh not signed in (gh auth login)"
[[ -d "$HOME/Documents/Data-Org-Repos/data-org/.git" ]] && pass "data-org repo" || fail "data-org repo missing at ~/Documents/Data-Org-Repos/data-org"
[[ -f "$HOME/Documents/Data-Org-Repos/data-org-notebook/scripts/run_query.py" ]] && pass "data-org-notebook (lake-query)" || fail "data-org-notebook missing (lake-query won't work)"
[[ -d "$HOME/meetings" ]] && pass "~/meetings" || fail "~/meetings missing"
# Scheduled jobs run under launchd, which macOS keeps out of ~/Documents (TCC). Jobs get their own clones in ~/cos/repos.
mkdir -p "$COS/repos"
for r in data-org data-org-notebook; do
  [[ -d "$COS/repos/$r/.git" ]] || git clone -q "https://github.com/wisecodeai/$r.git" "$COS/repos/$r" 2>/dev/null
  [[ -d "$COS/repos/$r/.git" ]] && pass "job clone ~/cos/repos/$r" || fail "could not clone wisecodeai/$r into ~/cos/repos"
done
for w in data-org-main notebook-main; do
  if [[ -f "$COS/$w/.git" ]] && grep -q "/Documents/" "$COS/$w/.git"; then fail "~/cos/$w is linked into ~/Documents; scheduled jobs can't read it (remove it; the next job rebuilds it)"; else pass "~/cos/$w is outside ~/Documents"; fi
done
mkdir -p "$COS/zoom"
# ~/Documents/Zoom is the primary (Zoom saves transcripts there). ZoomMirror copies them to ~/cos/zoom for the jobs.
if [[ -d "$HOME/Documents/Zoom" ]]; then
  newest="$(ls -t "$HOME/Documents/Zoom"/*.txt 2>/dev/null | head -1)"
  if [[ -z "$newest" || -f "$COS/zoom/$(basename "$newest")" ]]; then pass "~/cos/zoom has the newest Zoom transcript"; else fail "~/cos/zoom is missing $(basename "$newest"): run  open ~/cos/bin/ZoomMirror.app  (and Allow), then ./install.sh --schedule=zoommirror"; fi
fi
# The BOARD agent's handoff (written in ~/Documents) is STEWARD's method and state; ZoomMirror copies it.
HO="$HOME/Documents/Data-Org-Repos/data-org-agent-handoff.md"
if [[ -f "$HO" ]]; then cmp -s "$HO" "$COS/handbook/board-handoff.md" && pass "board handoff mirrored to ~/cos/handbook" || fail "~/cos/handbook/board-handoff.md is missing or stale: run  open ~/cos/bin/ZoomMirror.app"; fi

fi

echo "2. The kit, versioned"
if [[ $SANDBOX -eq 1 ]]; then echo "  · sandbox: kit checks skipped"; else
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

fi

echo "3. Files"
mkdir -p "$COS"/{bin,claude/briefs,claude/lake,claude/codex,handbook,outbox,state,archive,evals/runs} "$HOME/builds"
install -m 755 "$KIT"/claude/{cos-run,cos-gh,cos-sched,cos-push,cos-push-draft,cos-obligations,cos-link,cos-pr,cos-sandbox-test,cos-tcc-check,cos-gh-scan,cos-flow,cos-atlas,cos-diligence,cos-share,board-pulse,lake-query,cos-ledger,cos-db,cos-dash} "$COS/bin/"
# Old hand-made copies (cos-run.bak-20261110*) go to the archive, never deleted (plan 2026-11-14, item 6: subtract).
for b in "$COS"/bin/*.bak*; do [[ -e "$b" ]] || continue; mkdir -p "$COS/archive/bin-bak"; mv -f "$b" "$COS/archive/bin-bak/"; done
bash -n "$KIT/claude/gate.sh" || { echo "install.sh: claude/gate.sh has a syntax error; the live gate was left as it was." >&2; exit 1; }
install -m 755 "$KIT/claude/gate.sh" "$COS/claude/"
bash -n "$KIT/claude/cursor-lake-hook" && install -m 755 "$KIT/claude/cursor-lake-hook" "$COS/claude/" || fail "claude/cursor-lake-hook has a syntax error; the installed hook was left as it was"
install -m 644 "$KIT/claude/lake/cli.json" "$COS/claude/lake/"
bash -n "$KIT/claude/cursor-codex-hook" && install -m 755 "$KIT/claude/cursor-codex-hook" "$COS/claude/" || fail "claude/cursor-codex-hook has a syntax error; the installed hook was left as it was"
install -m 644 "$KIT/claude/codex/cli.json" "$COS/claude/codex/"
# Retired (Nov 15): the one-shot Codex kill review, replaced by cos-diligence. Archived, never deleted.
[[ -e "$COS/bin/cos-killreview" ]] && { mkdir -p "$COS/archive/bin-retired"; mv -f "$COS/bin/cos-killreview" "$COS/archive/bin-retired/"; }
# cos-launch: the one program launchd starts for every job, so one Full Disk Access grant covers them all (see
# claude/cos-launch.c). Rebuilt only when its source changes, because macOS ties the grant to the build.
if [[ ! -x "$COS/bin/cos-launch" ]] || ! cmp -s "$KIT/claude/cos-launch.c" "$COS/claude/cos-launch.c"; then
  if cc -O2 -Wall -o "$COS/bin/cos-launch.new" "$KIT/claude/cos-launch.c" 2>"$COS/state/cos-launch-build.err" \
     && codesign -f -s - -i com.cos.launch "$COS/bin/cos-launch.new" 2>>"$COS/state/cos-launch-build.err"; then
    mv -f "$COS/bin/cos-launch.new" "$COS/bin/cos-launch"; install -m 644 "$KIT/claude/cos-launch.c" "$COS/claude/cos-launch.c"
    [[ $SANDBOX -eq 0 ]] && echo "  ! cos-launch was (re)built: give it Full Disk Access (INSTALL.md), then ./install.sh --schedule"
  else fail "cos-launch did not build (see ~/cos/state/cos-launch-build.err)"; fi
fi
# ZoomMirror.app: the one reader of ~/Documents/Zoom (see claude/zoom-mirror.applescript). Rebuilt only when the
# source changes, because macOS ties the Documents grant to the app's signature.
ZM="$COS/bin/ZoomMirror.app"
if [[ $SANDBOX -eq 0 ]] && { [[ ! -d "$ZM" ]] || ! cmp -s "$KIT/claude/zoom-mirror.applescript" "$ZM/Contents/Resources/zoom-mirror.applescript"; }; then
  rm -rf "$ZM" && osacompile -o "$ZM" "$KIT/claude/zoom-mirror.applescript" \
    && /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$ZM/Contents/Info.plist" \
    && /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.cos.zoommirror" "$ZM/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.cos.zoommirror" "$ZM/Contents/Info.plist"
  cp "$KIT/claude/zoom-mirror.applescript" "$ZM/Contents/Resources/" && codesign -f -s - "$ZM" 2>/dev/null
  echo "  ! ZoomMirror.app was (re)built: run  open ~/cos/bin/ZoomMirror.app  once and click Allow for Documents"
fi
install -m 644 "$KIT"/claude/{agents.json,receipt.schema.json,settings.investigate.json,settings.draft.json,settings.build.json,settings.sheet.json,settings.fix.json,lane.md,build-lane.md,verifier.md} "$COS/claude/"
install -m 644 "$KIT"/claude/briefs/*.md "$COS/claude/briefs/"
install -m 644 "$KIT"/evals/*.json "$COS/evals/"
rm -rf "$COS/builds-template.new" && cp -R "$KIT/builds-template" "$COS/builds-template.new" && rm -rf "$COS/builds-template" && mv "$COS/builds-template.new" "$COS/builds-template"
backup_then_install() {  # kit-owned file: keep a backup if the installed copy was changed by hand
  local src="$1" dst="$2"; mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then cp "$dst" "$dst.bak-$(date +%Y%m%d%H%M%S)"; fi
  install -m 644 "$src" "$dst"; }
for f in rules.md board-standard.md engineering-standard.md system-map.md; do backup_then_install "$KIT/handbook/$f" "$COS/handbook/$f"; done
[[ -f "$COS/handbook/standing-approvals.json" ]] || install -m 644 "$KIT/handbook/standing-approvals.json" "$COS/handbook/"   # yours once installed: the kit never overwrites it
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
[[ -z "$(ls "$COS"/bin/*.bak* 2>/dev/null)" ]] && pass "no backup copies in ~/cos/bin (archived in ~/cos/archive/bin-bak)" || fail "backup copies still in ~/cos/bin"
for s in "$COS"/bin/* "$COS/claude/gate.sh" "$COS/claude/cursor-lake-hook" "$COS/claude/cursor-codex-hook" "$COS/builds-template/verify"; do
  [[ -d "$s" || "$(basename "$s")" == cos-launch ]] && continue; if head -1 "$s" | grep -q python; then python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$s" && pass "$(basename "$s")" || fail "$(basename "$s") syntax"
  else bash -n "$s" && pass "$(basename "$s")" || fail "$(basename "$s") syntax"; fi; done
for j in "$COS"/claude/*.json "$COS/claude/lake/cli.json" "$COS/claude/codex/cli.json" "$COS"/evals/*.json "$COS/builds-template/.claude/settings.json"; do jq empty "$j" 2>/dev/null && pass "$(basename "$j")" || fail "$(basename "$j") is not valid JSON"; done
for s in $SLOTS; do [[ "$s" == pulse || "$s" == obligations || -f "$COS/claude/briefs/$s.md" ]] && pass "brief: $s" || fail "brief missing: $s"; done

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
chk "~/cos/bin/cos-atlas find agent atlas dashboard" job allow
chk "gh search prs cursor agent --owner wisecodeai" job allow
chk "agent -p hi" job block
chk "cd /tmp && agent -p hi" job block
chk "env agent -p hi" job block
chk 'echo $(cursor-agent -p hi)' job block
chk "/usr/local/bin/cursor-agent -p hi" job block
chk 'python3 "/Users/x/Documents/Cursor Projects/agent-atlas/atlas_cli.py" show y' job allow
chk "cos-share j1 0000000000000000000000000000000000000000000000000000000000000000" job block
chk "aws s3 sync . s3://b" pair block
chk 'psql "host=prod" -c "delete from food"' pair block
chk "select name from wisecode_gold.canon_term" pair block
chk "select count(*) from wisecode_gold.canon_term group by 1" pair allow
chk "cat .env" pair block
chk "EXECUTE=1 make intake-sweep" job block
chk "DRY_RUN=1 make ragb CARD=1 TO=RED" job allow
chk "cos-push steward pulse r.json" pair block
chk "cos-link sub wisecodeai/data-org#1 wisecodeai/data-org#2" job block
chk "cos-pr close wisecodeai/data-org#1 0123456789abcdef0123456789abcdef01234567 /tmp/why.md" job block
chk "gh pr close 453 --repo wisecodeai/data-org" job block
chk "gh pr ready 3 --repo wisecodeai/data-org-notebook --undo" job block
chk "gh api repos/wisecodeai/data-org/issues/721/comments --jq .[]" job allow
chk "gh api graphql -f query=query{viewer{login}}" job allow
chk "gh api graphql -f query=mutation{addStar(input:{starrableId:1}){clientMutationId}}" job block
chk "gh api repos/wisecodeai/data-org/issues/1/comments -f body=hi" job block
chk "gh pr list --search created:>=2026-11-09" job block
chk "git -C ~/cos/data-org-main grep -n Window origin/main" job allow
chk "launchctl list" job block
chk "cos-obligations --act" job block
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
# Sheet mode: only the approved cell and value pass.
SBT="$(mktemp)"; echo '{"spreadsheet":"1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM","writes":[{"tab":"Data Roadmap","row":7,"row_name":"x","col":"D","old":"2026-11-25","new":"2026-11-30"}]}' > "$SBT"
sg() { printf '{"tool_name":"mcp__claude_ai_Google_Sheets__update_values","tool_input":{"spreadsheetId":"1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM","range":"%s","values":%s}}' "$1" "$2" | COS_LEDGER_OFF=1 COS_GATE_MODE=sheet COS_SHEET_BATCH="$SBT" "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?; }
[[ "$(sg "'Data Roadmap'!D7" '[["2026-11-30"]]')" == 0 ]] && pass "sheet · allow · the approved cell and value" || fail "sheet mode blocked the approved cell"
[[ "$(sg "'Data Roadmap'!D8" '[["2026-11-30"]]')" == 2 ]] && pass "sheet · block · another row" || fail "sheet mode allowed another row"
[[ "$(sg "'Data Roadmap'!D7" '[["2026-12-31"]]')" == 2 ]] && pass "sheet · block · another value" || fail "sheet mode allowed another value"
[[ "$(sg "'Data Roadmap'!D7:E7" '[["2026-11-30","x"]]')" == 2 ]] && pass "sheet · block · a wider range" || fail "sheet mode allowed a wider range"
rm -f "$SBT"
# Fix mode: Claude writes only in its own kit copy; the controls, the copy's .git, the installer and landing stay walled.
FXD="$(mktemp -d)"; FXD="$(cd "$FXD" && pwd -P)"; mkdir -p "$FXD/claude" "$FXD/.git"
fw() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$1" | COS_LEDGER_OFF=1 COS_GATE_MODE=fix COS_FIX_DIR="$FXD" COS_FIX_OUT=/nonexistent "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?; }
[[ "$(fw "$FXD/claude/gate.sh")" == 0 ]] && pass "fix · allow · writing its own kit copy" || fail "fix mode blocked its own copy"
[[ "$(fw "$COS/bin/cos-run")" == 2 ]] && pass "fix · block · writing an installed control" || fail "fix mode allowed ~/cos/bin"
[[ "$(fw "$FXD/../$(basename "$FXD")/.git/config")" == 2 ]] && pass "fix · block · writing the copy's .git" || fail "fix mode allowed .git"
[[ "$(fw "$FXD/../outside.txt")" == 2 ]] && pass "fix · block · a path that climbs out of the copy" || fail "fix mode allowed ../"
fb() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | COS_LEDGER_OFF=1 COS_GATE_MODE="$2" COS_FIX_DIR="$FXD" "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?; }
[[ "$(fb "$FXD/install.sh" fix)" == 2 ]] && pass "fix · block · running the copy's installer directly" || fail "fix mode ran install.sh"
[[ "$(fb "git -C $FXD commit -am x" fix)" == 2 ]] && pass "fix · block · committing (cos-run does)" || fail "fix mode allowed a commit"
[[ "$(fb "cos-run land j1 abc" pair)" == 2 ]] && pass "pair · block · cos-run land" || fail "an agent could land a fix"
[[ "$(fb "cos-run apply-sheet j1 abc" job)" == 2 ]] && pass "job · block · cos-run apply-sheet" || fail "an agent could apply a sheet batch"
rm -rf "$FXD"

echo "7. The lanes refuse what they should"
T="$(mktemp -d)"; mkdir -p "$T/cos/outbox/t1"
echo "gh issue close 1 --repo wisecodeai/data-org" > "$T/cos/outbox/t1/apply.sh"; S="$(shasum -a 256 "$T/cos/outbox/t1/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t1 "$S" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t1/applied.log" ]] && pass "apply refuses a close" || fail "apply ran a close"
HOME="$T" "$COS/bin/cos-run" apply t1 deadbeef --in "$T" >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "apply refuses a changed batch (hash mismatch)" || fail "apply ignored the hash"
# New cards and links: stubs stand in for gh, make and cos-link, so nothing reaches GitHub.
mkdir -p "$T/cos/bin" "$T/cos/outbox/t2" "$T/cos/outbox/t3"
printf '#!/bin/bash\n[[ "$1 $2" == "issue create" ]] && echo https://github.com/wisecodeai/data-org/issues/999\nexit 0\n' > "$T/cos/bin/gh"
printf '#!/bin/bash\necho "stub $*"\n' > "$T/cos/bin/make"; cp "$T/cos/bin/make" "$T/cos/bin/cos-link"; chmod +x "$T/cos/bin/"{gh,make,cos-link}
echo "x" > "$T/cos/outbox/t2/body.md"
cat > "$T/cos/outbox/t2/apply.sh" <<AP
gh issue create --repo wisecodeai/data-org --title "Test card" --body-file $T/cos/outbox/t2/body.md --assignee cassidythilton --milestone "Dec 31 · Next slice and foundations" --label init/test
make board-add URL=@1
make field CARD=@1 FIELD=Target TO=2026-12-31
cos-link sub wisecodeai/data-org#654 @1
cos-link blocked-by @1 wisecodeai/food-enrichment#220
AP
S2="$(shasum -a 256 "$T/cos/outbox/t2/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t2 "$S2" --in "$T" >/dev/null 2>&1
L2="$T/cos/outbox/t2/applied.log"
grep -q 'URL=https://github.com/wisecodeai/data-org/issues/999' "$L2" 2>/dev/null && grep -q 'CARD=999 FIELD' "$L2" && grep -q 'stub sub wisecodeai/data-org#654 wisecodeai/data-org#999' "$L2" && grep -q 'stub blocked-by wisecodeai/data-org#999 wisecodeai/food-enrichment#220' "$L2" \
  && pass "apply creates a card, then boards, sets and links it as @1" || fail "apply create/link batch (see $L2)"
echo 'gh issue create --repo someone/else --title "x" --body-file /tmp/x.md' > "$T/cos/outbox/t3/apply.sh"; S3="$(shasum -a 256 "$T/cos/outbox/t3/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t3 "$S3" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t3/applied.log" ]] && pass "apply refuses a card outside wisecodeai or a body outside the job folder" || fail "apply created a card it shouldn't"
# PR work on approval: a comment-only review, an approval, a merge and an issue label, each from the job folder.
mkdir -p "$T/cos/outbox/t5"; echo "x" > "$T/cos/outbox/t5/review.md"
cat > "$T/cos/outbox/t5/apply.sh" <<AP
gh pr review 746 --repo wisecodeai/data-org --comment --body-file $T/cos/outbox/t5/review.md
gh pr review 720 --repo wisecodeai/data-org --approve --body-file $T/cos/outbox/t5/review.md
gh pr comment 722 --repo wisecodeai/data-org --body-file $T/cos/outbox/t5/review.md
gh pr merge 720 --repo wisecodeai/data-org --squash --delete-branch
gh issue edit 652 --repo wisecodeai/data-org --add-label type/discovery --milestone "Nov 25 · November slice to Live"
gh pr edit 720 --repo wisecodeai/data-org --add-reviewer someone-else
gh issue edit 767 --repo wisecodeai/data-org --title "Re-parse ingredient lists from a flat-file export" --body-file $T/cos/outbox/t5/review.md
cos-link unblock wisecodeai/data-org#767 wisecodeai/data-org#728
AP
S5="$(shasum -a 256 "$T/cos/outbox/t5/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t5 "$S5" --in "$T" >/dev/null 2>&1; [[ "$(grep -c '^\$ \(gh\|cos-link\)' "$T/cos/outbox/t5/applied.log" 2>/dev/null)" == 8 ]] \
  && pass "apply runs approved PR reviews, comments, a merge, issue edits (labels, title, body), a link removal and a review request" || fail "apply refused an approved PR write"
mkdir -p "$T/cos/outbox/t8"; echo 'gh issue edit 767 --repo wisecodeai/data-org --body-file /tmp/x.md' > "$T/cos/outbox/t8/apply.sh"; S8="$(shasum -a 256 "$T/cos/outbox/t8/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t8 "$S8" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t8/applied.log" ]] && pass "apply refuses a new issue body from outside the job folder" || fail "apply took a body from outside the job folder"
mkdir -p "$T/cos/outbox/t7"; echo 'gh pr edit 720 --repo wisecodeai/data-org --add-reviewer x;rm' > "$T/cos/outbox/t7/apply.sh"; S7="$(shasum -a 256 "$T/cos/outbox/t7/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t7 "$S7" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/t7/applied.log" ]] && pass "apply refuses a review request with anything after the logins" || fail "apply ran a bad review request"
# PR close and draft (Nov 18): only through cos-pr, only his own PRs, only at the head he saw, branch kept.
H40=0123456789abcdef0123456789abcdef01234567
printf '#!/bin/bash\necho "stub $*"\n' > "$T/cos/bin/cos-pr"; chmod +x "$T/cos/bin/cos-pr"
mkdir -p "$T/cos/outbox/t9"; echo "Superseded by #594; its issue is closed." > "$T/cos/outbox/t9/why.md"
printf 'cos-pr close wisecodeai/data-org#453 %s %s\ncos-pr draft wisecodeai/data-org-notebook#3 %s\ncos-pr reopen wisecodeai/data-org#453\n' "$H40" "$T/cos/outbox/t9/why.md" "$H40" > "$T/cos/outbox/t9/apply.sh"
S9="$(shasum -a 256 "$T/cos/outbox/t9/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t9 "$S9" --in "$T" >/dev/null 2>&1; [[ "$(grep -c '^stub \(close\|draft\|reopen\)' "$T/cos/outbox/t9/applied.log" 2>/dev/null)" == 3 ]] \
  && pass "apply runs an approved cos-pr close, draft and reopen" || fail "apply refused an approved cos-pr line"
for badline in "gh pr close 453 --repo wisecodeai/data-org" "gh pr close 453 --repo wisecodeai/data-org --delete-branch" \
  "cos-pr close wisecodeai/data-org#453 $H40 /tmp/why.md" "cos-pr close wisecodeai/data-org#453 $H40 $T/cos/outbox/t9/why.md --delete-branch" \
  "cos-pr close wisecodeai/data-org#453 abc123 $T/cos/outbox/t9/why.md" "cos-pr draft someone/else#3 $H40" "gh pr ready 3 --repo wisecodeai/data-org --undo"; do
  rm -rf "$T/cos/outbox/t10"; mkdir -p "$T/cos/outbox/t10"; echo "$badline" > "$T/cos/outbox/t10/apply.sh"; S10="$(shasum -a 256 "$T/cos/outbox/t10/apply.sh" | cut -d' ' -f1)"
  HOME="$T" "$COS/bin/cos-run" apply t10 "$S10" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/t10/applied.log" ]] && pass "apply refuses: ${badline:0:60}" || fail "apply ran: $badline"
done
rm -rf "$T/cos/outbox/t11"; mkdir -p "$T/cos/outbox/t11"
for i in $(seq 1 11); do echo "cos-pr close wisecodeai/data-org#$i $H40 $T/cos/outbox/t9/why.md"; done > "$T/cos/outbox/t11/apply.sh"
S11="$(shasum -a 256 "$T/cos/outbox/t11/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t11 "$S11" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/t11/applied.log" ]] && pass "apply refuses more than 10 PR closes in one batch" || fail "apply ran 11 closes"
# An interrupted call doesn't stop the job (Nov 18): stop the caller's whole process group mid-batch; the batch finishes.
mkdir -p "$T/cos/outbox/t12i"; printf '#!/bin/bash\nsleep 2; echo "stub $*" >> "%s/linked"\n' "$T" > "$T/cos/bin/cos-link"; chmod +x "$T/cos/bin/cos-link"
printf 'cos-link sub wisecodeai/data-org#1 wisecodeai/data-org#2\ncos-link sub wisecodeai/data-org#1 wisecodeai/data-org#3\n' > "$T/cos/outbox/t12i/apply.sh"
S12="$(shasum -a 256 "$T/cos/outbox/t12i/apply.sh" | cut -d' ' -f1)"
HOME="$T" perl -e 'use POSIX qw(setsid); setsid(); exec @ARGV' "$COS/bin/cos-run" apply t12i "$S12" --in "$T" >/dev/null 2>"$T/t12.err" &
w=$!; sleep 1; kill -TERM -- -"$w" 2>/dev/null; wait "$w" 2>/dev/null
for i in $(seq 1 30); do HOME="$T" "$COS/bin/cos-run" receipt t12i 2>/dev/null | grep -q '"running"' || break; sleep 0.5; done
[[ "$(grep -c '^stub sub' "$T/linked" 2>/dev/null)" == 2 && -s "$T/cos/outbox/t12i/apply-receipt.json" ]] && pass "an interrupted apply call still finishes its whole batch" || fail "an interrupted apply stopped part way (see $T/linked)"
R12="$(HOME="$T" "$COS/bin/cos-run" receipt t12i 2>&1)"; [[ "$R12" == *'"finished after an interrupted call"'* ]] && pass "cos-run receipt shows what an interrupted call finished" || fail "receipt didn't show the interrupted call's result: ${R12:0:300} | $(ls "$T/cos/state/runs" | tr '\n' ' ')"
printf '#!/bin/bash\necho "stub $*"\n' > "$T/cos/bin/cos-link"
# cos-pr itself, against a fake gh that answers pr view from PRV and records every call.
P="$(mktemp -d)"; mkdir -p "$P/bin" "$P/cos/outbox/j" "$P/cos/bin"; echo "why" > "$P/cos/outbox/j/why.md"
cat > "$P/bin/gh" <<'GH'
#!/bin/bash
echo "$*" >> "$PRLOG"
if [[ "$1 $2" == "pr view" ]]; then
  if [[ "$*" == *"-q .state"* ]]; then [[ -f "$PRLOG.closed" ]] && echo CLOSED || echo OPEN
  elif [[ "$*" == *"-q .isDraft"* ]]; then echo true
  else cat "$PRV"; fi
fi
[[ "$1 $2" == "pr close" ]] && touch "$PRLOG.closed"
exit 0
GH
chmod +x "$P/bin/gh"
prv() { jq -nc --arg a "$1" --arg s "$2" --arg h "$3" --arg c "$4" '{state:$s,isDraft:false,author:{login:$a},headRefOid:$h,headRefName:"cassidy/x",title:"t",url:"u",commits:[{authors:[{login:$c}]}]}' > "$P/prv.json"; rm -f "$P/log" "$P/log.closed"; }
cp "$KIT/claude/cos-pr" "$P/cos/bin/cos-pr"
cpr() { HOME="$P" PATH="$P/bin:$PATH" PRV="$P/prv.json" PRLOG="$P/log" "$P/cos/bin/cos-pr" "$@" >/dev/null 2>&1; }
prv someone-else OPEN "$H40" someone-else; cpr close wisecodeai/data-org#9 "$H40" "$P/cos/outbox/j/why.md"; [[ $? -eq 65 ]] && ! grep -q "pr close" "$P/log" && pass "cos-pr refuses to close another owner's PR" || fail "cos-pr closed another owner's PR"
prv cassidythilton OPEN "$H40" david; cpr close wisecodeai/data-org#9 "$H40" "$P/cos/outbox/j/why.md"; [[ $? -eq 65 ]] && ! grep -q "pr close" "$P/log" && pass "cos-pr refuses a PR with someone else's commits" || fail "cos-pr closed a PR with others' commits"
prv cassidythilton OPEN ffffffffffffffffffffffffffffffffffffffff cassidythilton; cpr close wisecodeai/data-org#9 "$H40" "$P/cos/outbox/j/why.md"; [[ $? -eq 67 ]] && ! grep -q "pr close" "$P/log" && pass "cos-pr refuses when the PR moved since he looked" || fail "cos-pr closed a PR that moved"
prv cassidythilton MERGED "$H40" cassidythilton; cpr close wisecodeai/data-org#9 "$H40" "$P/cos/outbox/j/why.md"; [[ $? -eq 65 ]] && pass "cos-pr refuses a merged PR" || fail "cos-pr acted on a merged PR"
prv cassidythilton OPEN "$H40" cassidythilton; cpr close wisecodeai/data-org#9 "$H40" /tmp/why.md; [[ $? -eq 64 ]] && pass "cos-pr refuses a reason file outside the job folder" || fail "cos-pr took a reason from outside the job folder"
prv cassidythilton OPEN "$H40" cassidythilton; cpr close wisecodeai/data-org#9 "$H40" "$P/cos/outbox/j/why.md"
[[ $? -eq 0 ]] && [[ "$(grep -n 'pr comment 9' "$P/log" | cut -d: -f1)" -lt "$(grep -n 'pr close 9' "$P/log" | cut -d: -f1)" ]] && ! grep -q -- "--delete-branch\|-d " "$P/log" \
  && pass "cos-pr closes his own PR: reason first, branch kept" || fail "cos-pr close (see $P/log)"
prv cassidythilton CLOSED "$H40" cassidythilton; cpr close wisecodeai/data-org#9 "$H40" "$P/cos/outbox/j/why.md"; [[ $? -eq 0 ]] && ! grep -q "pr close" "$P/log" && pass "cos-pr skips a PR that's already closed" || fail "cos-pr closed a closed PR again"
prv cassidythilton OPEN "$H40" cassidythilton; cpr draft wisecodeai/data-org-notebook#3 "$H40"; [[ $? -eq 0 ]] && grep -q "pr ready 3 --repo wisecodeai/data-org-notebook --undo" "$P/log" && pass "cos-pr turns his own PR back into a draft" || fail "cos-pr draft (see $P/log)"
rm -rf "$P"
mkdir -p "$T/cos/outbox/t6"; echo 'gh pr review 746 --repo wisecodeai/data-org --approve --body "looks good"' > "$T/cos/outbox/t6/apply.sh"; S6="$(shasum -a 256 "$T/cos/outbox/t6/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t6 "$S6" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t6/applied.log" ]] && pass "apply refuses a review body that isn't a file in the job folder" || fail "apply ran an inline review body"
# Replacing a comment's text (Nov 17, #774): only Cassidy's own, old text saved in the job folder and ledgered as the undo.
cat > "$T/cos/bin/gh" <<'STUB'
#!/bin/bash
[[ "$1 $2" == "issue create" ]] && echo https://github.com/wisecodeai/data-org/issues/999
[[ "$1 $2" == "api -X" ]] && { echo "$*" >> "$HOME/patch.log"; cat "${6#body=@}" > "$HOME/cbody"; }
if [[ "$1" == api && "$2" == repos/* ]]; then [[ "$2" == */111 ]] && w=cassidythilton || w=someone-else
  jq -n --arg w "$w" --arg b "$(cat "$HOME/cbody" 2>/dev/null || echo old text)" '{user:{login:$w},body:$b}'; fi
exit 0
STUB
cp "$COS/bin/cos-ledger" "$T/cos/bin/"
mkdir -p "$T/cos/outbox/t12" "$T/cos/outbox/t13" "$T/cos/outbox/t14"; echo "new text" > "$T/cos/outbox/t12/c.md"; echo "new text" > "$T/cos/outbox/t13/c.md"
echo "newer text" > "$T/cos/outbox/t12/c2.md"; U12="gh api -X PATCH repos/wisecodeai/data-org/issues/comments/111 -F body=@$T/cos/outbox/t12/comment-111"
printf '%s\n' "gh api -X PATCH repos/wisecodeai/data-org/issues/comments/111 -F body=@$T/cos/outbox/t12/c.md" "gh api -X PATCH repos/wisecodeai/data-org/issues/comments/111 -F body=@$T/cos/outbox/t12/c2.md" > "$T/cos/outbox/t12/apply.sh"; S12="$(shasum -a 256 "$T/cos/outbox/t12/apply.sh" | cut -d' ' -f1)"
HOME="$T" COS_LEDGER_DIR="$T/led" "$COS/bin/cos-run" apply t12 "$S12" --in "$T" >/dev/null 2>&1
[[ "$(cat "$T/cos/outbox/t12/comment-111.before.md" 2>/dev/null)" == "old text" && "$(cat "$T/cos/outbox/t12/comment-111.before-2.md" 2>/dev/null)" == "new text" ]] && grep -q "comments/111 -F body=@$T/cos/outbox/t12/c2.md" "$T/patch.log" 2>/dev/null \
  && jq -se --arg a "$U12.before.md" --arg b "$U12.before-2.md" 'map(select(.kind == "comment-edit") | .undo) == [$a, $b]' "$T/led/applies.jsonl" >/dev/null 2>&1 \
  && pass "apply replaces Cassidy's own comment, saves the old text and ledgers the undo (twice in one batch)" || fail "apply comment replace (see $T/cos/outbox/t12/applied.log)"
echo "gh api -X PATCH repos/wisecodeai/data-org/issues/comments/222 -F body=@$T/cos/outbox/t13/c.md" > "$T/cos/outbox/t13/apply.sh"; S13="$(shasum -a 256 "$T/cos/outbox/t13/apply.sh" | cut -d' ' -f1)"
HOME="$T" COS_LEDGER_DIR="$T/led" "$COS/bin/cos-run" apply t13 "$S13" --in "$T" >/dev/null 2>&1
! grep -q "comments/222" "$T/patch.log" 2>/dev/null && grep -q "^FAILED: the comment must be cassidythilton's" "$T/cos/outbox/t13/applied.log" 2>/dev/null \
  && pass "apply refuses to replace someone else's comment" || fail "apply replaced a comment that isn't Cassidy's"
echo "gh api -X PATCH repos/wisecodeai/data-org/issues/comments/111 -F body=@/tmp/x.md" > "$T/cos/outbox/t14/apply.sh"; S14="$(shasum -a 256 "$T/cos/outbox/t14/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t14 "$S14" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/t14/applied.log" ]] && pass "apply refuses a comment's new text from outside the job folder" || fail "apply took a comment's text from outside the job folder"
"$COS/bin/cos-gh" t12 plain "$T/cos/outbox/t12/apply.sh" 2>/dev/null | jq -e '.highest_tier == 1 and (.items[0].says | test("your own comment 111"))' >/dev/null 2>&1 \
  && pass "plain: a comment replace reads as tier 1" || fail "plain: comment replace tier"
rm -f "$T/cos/bin/cos-ledger"
mkdir -p "$T/cos/outbox/t4"; echo '{"spreadsheet":"1OkdCrSUr3Q9dZHkDA0bq2NTr7I6jpiE8fyWEStnMrXM","writes":[{"tab":"Data Roadmap","row":7,"row_name":"x","col":"K","old":"","new":"1 Relevance"}]}' > "$T/cos/outbox/t4/sheet.json"
S4="$(shasum -a 256 "$T/cos/outbox/t4/sheet.json" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply-sheet t4 "$S4" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/t4/sheet-applied.json" ]] && pass "apply-sheet refuses column K (a formula)" || fail "apply-sheet accepted a column K write"
printf '#!/bin/bash\nprintf "%%s|" "$@"; exit 3\n' > "$T/cos/bin/argcheck"; chmod +x "$T/cos/bin/argcheck"
lo="$(HOME="$T" "$COS/bin/cos-launch" argcheck "a b" c 2>/dev/null)"; lrc=$?
[[ $lrc -eq 3 && "$lo" == "a b|c|" ]] && pass "cos-launch runs a ~/cos/bin program with its arguments and exit code" || fail "cos-launch returned $lrc '$lo'"
HOME="$T" "$COS/bin/cos-launch" /bin/ls >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-launch refuses a path (only ~/cos/bin programs)" || fail "cos-launch ran a path"
HOME="$T" "$COS/bin/cos-launch" ../x >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-launch refuses ../" || fail "cos-launch accepted ../"
# The quick lane never returns a blank receipt; gh-scan says "failed", never "empty".
mkdir -p "$T/cos/bin"; printf '#!/bin/bash\necho "Killed: 9" >&2; exit 137\n' > "$T/cos/bin/agent"; chmod +x "$T/cos/bin/agent"
HOME="$T" "$COS/bin/cos-run" quick qk1 "List my issues" --with "git log -1 --oneline" --in "$T" >/dev/null 2>&1
jq -e '.receipt.status == "failed" and (.receipt.summary | test("not an empty result"))' "$T/cos/outbox/qk1/receipt.json" >/dev/null 2>&1 \
  && pass "quick lane: a killed model gives a failed receipt with the data, never a blank one" || fail "quick lane left a blank or unclear receipt"
rm -f "$T/cos/bin/agent"; mv "$T/cos/bin/gh" "$T/cos/bin/gh.stub" 2>/dev/null
printf '#!/bin/bash\necho "Post \\"https://api.github.com/graphql\\": dial tcp 1.2.3.4:443: i/o timeout" >&2; exit 1\n' > "$T/cos/bin/gh"; chmod +x "$T/cos/bin/gh"
HOME="$T" COS_GH_WAITS=0,0,0 PATH="$T/cos/bin:$PATH" "$COS/bin/cos-gh-scan" "$T/cos/outbox/gs1" >/dev/null 2>&1
jq -e '.receipt.status == "failed" and (.receipt.summary | startswith("GitHub read failed"))' "$T/cos/outbox/gs1/receipt.json" >/dev/null 2>&1 \
  && pass "gh-scan: GitHub down reads 'GitHub read failed', never empty" || fail "gh-scan didn't report the failure plainly"
rm -f "$T/cos/bin/gh"; mv "$T/cos/bin/gh.stub" "$T/cos/bin/gh" 2>/dev/null
# Quick lane: reads in, writes out, judged the way the shell will run them.
for qc in 'gh pr list --repo wisecodeai/data-org --search created:>=2026-11-09' "gh api graphql -f query='mutation{x}'" 'gh api repos/wisecodeai/data-org/issues/1/comments -f body=hi' 'gh issue list --search "$(rm -rf ~)"'; do
  HOME="$T" "$COS/bin/cos-run" quick qr1 "x" --with "$qc" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 ]] && pass "quick refuses: $qc" || fail "quick ran: $qc"
done
# Zendesk intake reads (system map row): bare make intake-holders and make intake-sweep run, always as the dry run. An EXECUTE
# in the caller's environment or MAKEFLAGS never reaches them; any argument, EXECUTE=1 or another intake target is refused.
mv "$T/cos/bin/make" "$T/cos/bin/make.stub" 2>/dev/null
printf '#!/bin/bash\necho "make $* EXECUTE=${EXECUTE:-} MAKEFLAGS=${MAKEFLAGS:-}"\n' > "$T/cos/bin/make"
printf '#!/bin/bash\necho %s\n' "'{\"result\":\"stub\"}'" > "$T/cos/bin/agent"; chmod +x "$T/cos/bin/make" "$T/cos/bin/agent"
for qc in "make intake-holders" "make intake-sweep"; do
  rm -rf "$T/cos/outbox/qi1"; HOME="$T" EXECUTE=1 MAKEFLAGS=EXECUTE=1 "$COS/bin/cos-run" quick qi1 "x" --with "$qc" --in "$T" >/dev/null 2>&1; qrc=$?
  [[ $qrc -eq 0 ]] && grep -qx "$qc EXECUTE= MAKEFLAGS=" "$T/cos/outbox/qi1/context.txt" 2>/dev/null \
    && pass "quick reads Zendesk intake as a dry run: $qc" || fail "quick refused $qc, or passed EXECUTE through (rc $qrc: $(tail -c 200 "$T/cos/outbox/qi1/context.txt" 2>/dev/null))"
done
for qc in "make intake-sweep EXECUTE=1" "EXECUTE=1 make intake-sweep" "make intake-holders EXECUTE=1" "make intake-sweep --no-unboard" "make intake-sweep -e" "make board-intake" "make classify ISSUE=1" "make intake TITLE=x"; do
  HOME="$T" "$COS/bin/cos-run" quick qr2 "x" --with "$qc" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 ]] && pass "quick refuses: $qc" || fail "quick ran: $qc"
done
rm -f "$T/cos/bin/agent" "$T/cos/bin/make"; mv "$T/cos/bin/make.stub" "$T/cos/bin/make" 2>/dev/null
HOME="$T" "$COS/bin/cos-run" atlas at1 "the dashboard chat" --in "$T" >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "atlas refuses when it can't read Agent Atlas" || fail "atlas ran without Agent Atlas"
HOME="$T" "$COS/bin/cos-atlas" find x >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "cos-atlas refuses when Agent Atlas isn't there" || fail "cos-atlas ran without Agent Atlas"
"$COS/bin/cos-atlas" sql 'x' >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-atlas takes only find|show|search|messages|recent" || fail "cos-atlas took another command"
# BUILDER two-model diligence (Nov 15, decisions 1b 2c 3a): Claude's pass, Codex's blind pass, a comparison, one round of
# cross-examination each way, a verdict by script, a $30 cap. Codex and Claude are stubs here; the walls are tested live
# in the README's proof and by the hook tests below.
grep -q "PASS 2: DILIGENCE" "$COS/claude/briefs/opportunity.md" && grep -q "Only CHECKED candidates can be ranked" "$COS/claude/briefs/opportunity.md" && ! grep -q "~/meetings" "$COS/claude/briefs/opportunity.md" \
  && grep -q "slack-digest.md" "$COS/claude/briefs/opportunity.md" && grep -q '"kind": "code|pr|issue|board|receipt|slack|doc|transcript"' "$COS/claude/briefs/opportunity.md" \
  && pass "opportunity brief: premise, owner overlap and user checked; writes slack-digest.md and diligence.json with call evidence tagged" || fail "opportunity brief lacks the diligence pass, the digest or diligence.json"
grep -q "except Cassidy's own words" "$COS/bin/cos-run" && grep -q "waiver.json" "$COS/claude/lane.md" && pass "a comment Cassidy approved word for word, with a recorded lint waiver, isn't blocked by lint" || fail "no path for Cassidy's own words past the lint"
grep -q "build-opportunity pass" "$COS/bin/cos-run" && grep -q '"$COS/bin/cos-diligence" "$OUT"' "$COS/bin/cos-run" && ! grep -q "cos-killreview" "$COS/bin/cos-run" && [[ ! -e "$COS/bin/cos-killreview" ]] \
  && pass "opportunity passes get the checker's premise rule and two-model diligence (the one-shot kill review is retired)" || fail "two-model diligence not wired"
grep -q "diligence.json is missing" "$COS/bin/cos-run" && pass "checker: diligence.json must match opportunities.md; slack-digest.md canon-free with links" || fail "checker lacks the diligence.json and digest rules"
DG="$(mktemp -d)"; DG="$(cd "$DG" && pwd -P)"; H="$DG/home"; mkdir -p "$H/cos/claude/codex" "$H/cos/outbox" "$H/cos/data-org-main/drd" "$DG/bin" "$DG/stub"
cp "$COS/claude/codex/cli.json" "$H/cos/claude/codex/"; cp "$COS/claude/gate.sh" "$H/cos/claude/"
# Stubs: each answers by the step marker in its prompt, from $DG/stub/<step>.txt (Codex: prose around the JSON) or
# .json (Claude: structured output), and keeps the prompt it got so the test can read what crossed.
cat > "$DG/bin/agent" <<'S'
#!/bin/bash
p="${@: -1}"; m="$(grep -oE '\[cos-diligence:[a-z-]+\]' <<<"$p" | head -1 | tr -d '[]' | cut -d: -f2)"
printf '%s' "$p" > "$STUB/$m.prompt"; touch "$STUB/agent.ran"
jq -n --rawfile r "$STUB/$m.txt" '{result: $r, session_id: "s1", usage: {inputTokens: 100000, outputTokens: 10000, cacheReadTokens: 0}}'
S
cat > "$DG/bin/claude" <<'S'
#!/bin/bash
m="$(grep -oE '\[cos-diligence:[a-z-]+\]' <<<"$2" | head -1 | tr -d '[]' | cut -d: -f2)"
printf '%s' "$2" > "$STUB/$m.prompt"
jq -n --slurpfile o "$STUB/$m.json" '{structured_output: $o[0], total_cost_usd: 0.5}'
S
chmod +x "$DG/bin/agent" "$DG/bin/claude"
# Five candidates: A both CHECKED; B both DEAD; C Claude CHECKED (one line from a call), Codex DEAD; D Codex CHECKED,
# Claude OFFER; E no card.
mkjob() { mkdir -p "$H/cos/outbox/$1"; echo "{\"checker\":{\"verdict\":\"${3:-pass}\"},\"cost_usd\":${2:-2},\"receipt\":{\"summary\":\"pass 1\"}}" > "$H/cos/outbox/$1/receipt.json"
  cat > "$H/cos/outbox/$1/diligence.json" <<'J'
{"window":"2026-11-07 to 2026-11-14","candidates":[
 {"id":"651","card":"wisecodeai/data-org#651","idea":"flag low-confidence results","status":"CHECKED","rank":1,"score_line":"A-claude","reason":"premise in code",
  "evidence":[{"field":"premise","claim":"score emitted","cite":"src/x.py:3","kind":"code"}]},
 {"id":"374","card":"wisecodeai/data-org#374","idea":"turn on triage","status":"DEAD","reason":"already live"},
 {"id":"778","card":"wisecodeai/data-org#778","idea":"golden set harness","status":"CHECKED","rank":2,"score_line":"C-claude","reason":"owner asked",
  "evidence":[{"field":"owner","claim":"David says Matt, you're on that","cite":"Team check-in.txt 12:13:40","kind":"transcript"},
              {"field":"premise","claim":"golden v0 exists","cite":"docs/g.md:282","kind":"doc"}]},
 {"id":"650","card":"wisecodeai/data-org#650","idea":"pantry publish","status":"OFFER","reason":"Nicholas planned it"},
 {"id":"kit-x","card":null,"idea":"a kit idea","status":"NOT CHECKED YET","reason":"needs a card first"}]}
J
  printf -- '- #data-team 2026-11-12: ask for a golden-set runner (https://wisecode.slack.com/archives/C0BMLSDDNDT/p1)\n' > "$H/cos/outbox/$1/slack-digest.md"; }
printf 'Here is my assessment of each candidate.\n```json\n{"candidates":[{"id":"651","status":"CHECKED","rank":2,"score_line":"A-codex","reason":"ok","evidence":[]},{"id":"374","status":"DEAD","reason":"live"},{"id":"778","status":"DEAD","reason":"no golden set"},{"id":"650","status":"CHECKED","rank":1,"score_line":"D-codex","reason":"publish job exists"}]}\n```\nDone.' > "$DG/stub/codex-pass.txt"
printf 'Checked.\n{"attacks":[{"id":"651","verdict":"stands","reason":"line holds","cite":"src/x.py:3"},{"id":"778","verdict":"refuted","proposed_status":"DEAD","reason":"gating checklist says not released","cite":"docs/g.md:282"}]}' > "$DG/stub/codex-attack.txt"
printf '{"responses":[{"id":"650","response":"concede","reason":"PR 407 is his","cite":"food-enrichment#407"}]}' > "$DG/stub/codex-respond.txt"
echo '{"attacks":[{"id":"651","verdict":"stands","reason":"agree","cite":"src/x.py:3"},{"id":"650","verdict":"refuted","proposed_status":"OFFER","reason":"owner has PR 407 open","cite":"food-enrichment#407"}]}' > "$DG/stub/claude-attack.json"
echo '{"responses":[{"id":"778","response":"defend","reason":"v0 is the set the harness runs","cite":"docs/g.md:280"}]}' > "$DG/stub/claude-respond.json"
dil() { HOME="$H" STUB="$DG/stub" PATH="$DG/bin:$PATH" "$@" "$COS/bin/cos-diligence" "$H/cos/outbox/$J" >/dev/null 2>&1; }
J=opp1; mkjob opp1; dil env
V="$H/cos/outbox/opp1/diligence-verdict.json"; C="$H/cos/outbox/opp1/compare.json"
jq -e '[.rows[] | {(.id): .category}] | add | .["651"]=="agree CHECKED" and .["374"]=="agree DEAD" and .["778"]=="disagree" and .["650"]=="disagree" and .["kit-x"]=="agree out"' "$C" >/dev/null 2>&1 \
  && pass "diligence compare: agree CHECKED, agree DEAD, disagree, card by card" || fail "diligence compare ($(jq -c '.rows' "$C" 2>/dev/null))"
jq -e '[.records[] | {(.id): .outcome}] | add | .["651"]=="survives" and .["778"]=="contested" and .["650"]=="out" and .["374"]=="out" and .["kit-x"]=="out"' "$V" >/dev/null 2>&1 \
  && jq -e '.records[] | select(.id=="650") | .why | test("conceded: PR 407 is his")' "$V" >/dev/null 2>&1 \
  && pass "diligence verdict: both CHECKED and unrefuted survives; a defended refutation is contested; a conceded one is out, with the concession as its reason" || fail "diligence verdict ($(jq -c '[.records[]|{id,outcome}]' "$V" 2>/dev/null))"
jq -e '.consensus_order == ["651","778"] and (.records[] | select(.id=="778") | .disputes[0].attacker=="codex" and (.disputes[0].defense|test("v0 is the set")))' "$V" >/dev/null 2>&1 \
  && grep -q '\[CONTESTED\]' "$H/cos/outbox/opp1/builder.md" && grep -q "Claude's score: A-claude" "$H/cos/outbox/opp1/builder.md" && grep -q "Codex's score: A-codex" "$H/cos/outbox/opp1/builder.md" \
  && jq -e '(.receipt.summary|startswith("Two-model diligence")) and (.diligence.outcomes["651"]=="survives") and (.receipt.summary|test("pass 1"))' "$H/cos/outbox/opp1/receipt.json" >/dev/null \
  && jq -e '.receipt.summary | test("Claude.s single pass, before cross-examination \\(superseded by the verdict above") and (index("superseded") < index("pass 1"))' "$H/cos/outbox/opp1/receipt.json" >/dev/null \
  && pass "diligence receipt: labeled survivors and contested ideas, both score lines, consensus order as advice; Claude's own pass labeled superseded" || fail "diligence receipt for BUILDER"
jq -e '.records[] | select(.id=="651") | .cross_exam | length == 2' "$V" >/dev/null 2>&1 && jq -e '.steps["codex-pass"].status=="ran"' "$V" >/dev/null 2>&1 \
  && pass "diligence: reads Codex replies with prose and a code fence around the JSON" || fail "diligence lost a Codex reply wrapped in prose"
! grep -q "you're on that" "$DG/stub/codex-attack.prompt" && grep -q "held on the Mac" "$DG/stub/codex-attack.prompt" && grep -q "docs/g.md:282" "$DG/stub/codex-attack.prompt" \
  && ! grep -qE "CHECKED|DEAD|OFFER|premise in code" <(grep -A40 '^Candidates:' "$DG/stub/codex-pass.prompt" | sed '/^For each candidate/,$d') \
  && pass "diligence: Codex's pass is blind (card and idea only), and call evidence is held before Codex sees Claude's case" || fail "diligence sent Codex a transcript line or Claude's statuses"
[[ -f "$H/cos/outbox/opp1/codex/ws/slack-digest.md" && -f "$H/cos/outbox/opp1/codex/ws/.cursor/cli.json" && -f "$H/cos/outbox/opp1/codex/ws/.cursor/hooks.json" ]] \
  && pass "diligence: Codex's workspace has the screened digest, the permission file and the hook" || fail "diligence workspace incomplete"
# Canon hold: a digest that names a canon table stays on the Mac, and the receipt says so.
J=opp2; mkjob opp2; echo "- #data-team: counts from mart.canon_term (https://x)" > "$H/cos/outbox/opp2/slack-digest.md"; dil env
[[ ! -e "$H/cos/outbox/opp2/codex/ws/slack-digest.md" ]] && jq -e '(.diligence.held | map(.what) | index("slack-digest.md")) and (.receipt.summary|test("Held on the Mac: slack-digest.md"))' "$H/cos/outbox/opp2/receipt.json" >/dev/null 2>&1 \
  && pass "diligence: canon tripwire holds a file on the Mac and says so" || fail "diligence canon hold"
# Cap: $29 already spent of $30, so Codex's pass ($4 reserve) doesn't start, nor anything after; it says which.
J=opp3; mkjob opp3 29; rm -f "$DG/stub/agent.ran"; dil env
[[ ! -f "$DG/stub/agent.ran" ]] && jq -e '.diligence.steps["codex-pass"].status=="not run" and .diligence.steps["codex-attack"].status=="not run" and (.receipt.summary|test("Didn.t run: codex-pass")) and .diligence.outcomes["651"]=="out"' "$H/cos/outbox/opp3/receipt.json" >/dev/null 2>&1 \
  && pass "diligence: stops cleanly at the \$30 cap and names the steps that didn't run" || fail "diligence cap ($(jq -c '.diligence.steps' "$H/cos/outbox/opp3/receipt.json" 2>/dev/null))"
J=opp4; mkjob opp4 2 fail; rm -f "$DG/stub/agent.ran"; dil env
[[ ! -f "$DG/stub/agent.ran" ]] && jq -e '.diligence.status=="skipped" and (.receipt.summary|test("checker blocked"))' "$H/cos/outbox/opp4/receipt.json" >/dev/null 2>&1 \
  && pass "diligence: a pass the checker blocked goes no further, and says so" || fail "diligence ran on a blocked pass"
# The Codex walls: the hook (second wall after claude/codex/cli.json). Proved live on 2026-11-15 too (HANDOFF lessons).
CX="$COS/claude/codex/cli.json"
jq -e '(.permissions.deny | index("Write(**)") and index("Shell(curl)") and index("Shell(git)") and index("Read(~/cos/zoom/**)") and index("Read(~/meetings/**)") and index("Read(~/.claude/**)") and index("Mcp(*:*)") and index("WebFetch(*)"))
       and (.permissions.allow | all(test("^(Read\\(|Shell\\((gh|ls)\\))")))' "$CX" >/dev/null 2>&1 \
  && pass "codex cli.json: denies writes, network tools, git, transcripts, ~/meetings, chats; allows reads, gh, ls" || fail "codex cli.json is missing a deny"
WSD="$H/cos/outbox/opp1/codex/ws"; echo "plain" > "$H/cos/data-org-main/README.md"; echo "from mart.canon_term" > "$H/cos/data-org-main/drd/c.md"; mkdir -p "$H/cos/zoom"; echo t > "$H/cos/zoom/call.md"
ch() { local got; got="$(jq -nc --arg t "$1" --arg c "$2" --arg p "${3:-}" --arg w "$WSD" '{tool_name:$t, tool_input:{command:$c, file_path:$p}, workspace_roots:[$w]}' | HOME="$H" COS_LEDGER_OFF=1 "$COS/claude/cursor-codex-hook" | jq -r .permission)"
  [[ "$got" == "$4" ]] && pass "codex hook · $4 · $1 ${2:-$3}" || fail "codex hook · expected $4, got $got · $1 ${2:-$3}"; }
ch Read "" "$WSD/slack-digest.md" allow
ch Read "" "$H/cos/data-org-main/README.md" allow
ch Read "" "$H/cos/data-org-main/drd/c.md" deny
ch Read "" "$H/cos/zoom/call.md" deny
ch Read "" "../../diligence.json" deny
ch Grep "" "$H/meetings" deny
ch Write "" "$WSD/x.md" deny
ch Shell 'gh issue view 651 --repo wisecodeai/data-org --json title,body' "" allow
ch Shell 'gh pr diff 37 --repo wisecodeai/nutrient-estimator' "" allow
ch Shell 'gh api repos/wisecodeai/data-org/issues/651/comments' "" allow
ch Shell 'gh issue comment 651 --repo wisecodeai/data-org --body x' "" deny
ch Shell 'gh api -X POST repos/wisecodeai/data-org/issues -f title=x' "" deny
ch Shell "gh api graphql -f query='mutation{x}'" "" deny
ch Shell 'gh issue view 651 --web' "" deny
ch Shell 'gh issue view 651 > out.txt' "" deny
ch Shell 'curl -s https://example.com' "" deny
ch Shell 'cat ~/cos/zoom/call.md' "" deny
ch Shell 'ls ~/meetings' "" deny
got="$(jq -nc --arg w "$WSD" '{tool_name:"Read", tool_input:{file_path:"x"}, workspace_roots:[$w]}' | HOME="$DG/nogate" "$COS/claude/cursor-codex-hook" | jq -r .permission)"
[[ "$got" == deny ]] && pass "codex hook fails closed when the gate is missing" || fail "codex hook ran without the gate"
rm -rf "$DG"
grep -q '"Bash(cos-atlas \*)"' "$COS/claude/settings.investigate.json" && grep -q 'cos-atlas find' "$COS/claude/briefs/atlas.md" && pass "atlas jobs use cos-atlas" || fail "atlas jobs can't run cos-atlas"
[[ -f "$COS/claude/briefs/atlas.md" ]] && grep -q 'canon_risk' "$COS/claude/briefs/atlas.md" && pass "brief: atlas (with the canon_risk rule)" || fail "atlas brief missing"
HOME="$T" "$COS/bin/cos-run" land nofix abc >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "land refuses a job with no fix receipt" || fail "land ran without a fix receipt"
mkdir -p "$T/cos/outbox/fx1"; echo '{"lane":"fix","fix":{"base":"x","branch":"fix/fx1","sha256":"aaa"},"approve_with":"cos-run land fx1 aaa"}' > "$T/cos/outbox/fx1/receipt.json"
HOME="$T" "$COS/bin/cos-run" land fx1 bbb >/dev/null 2>&1; [[ $? -eq 67 ]] && pass "land refuses a sha256 that isn't the reviewed one" || fail "land accepted the wrong sha256"
mkdir -p "$T/cos/fixes"; "$COS/bin/cos-sandbox-test" "$COS" >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-sandbox-test refuses anything outside ~/cos/fixes" || fail "cos-sandbox-test ran outside ~/cos/fixes"
HOME="$T" "$COS/bin/cos-run" note steward "test note" >/dev/null 2>&1 && [[ "$(jq -r .bot "$T/cos/state/corrections.jsonl" 2>/dev/null)" == steward ]] && pass "note records a correction" || fail "note did not record"
HOME="$T" "$COS/bin/cos-run" note nobody "x" >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "note refuses an unknown bot" || fail "note accepted an unknown bot"
HOME="$T" "$COS/bin/cos-run" eval nosuchsuite current >/dev/null 2>&1; [[ $? -ne 0 ]] && pass "eval refuses a missing suite" || fail "eval ran without a suite"
HOME="$T" "$COS/bin/cos-run" pair x y >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "the pair lane is gone (refused as unknown)" || fail "the pair lane still runs"
"$COS/bin/cos-push" nobody pulse /dev/null >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-push refuses an unknown bot" || fail "cos-push accepted an unknown bot"
"$COS/bin/cos-sched" list >/dev/null 2>&1 && pass "cos-sched lists the schedule" || fail "cos-sched list"
HOME="$T" "$COS/bin/cos-obligations" --selftest >/dev/null 2>&1 && pass "standing review line: comment only, exact shape" || fail "cos-obligations selftest"
HOME="$T" "$COS/bin/cos-run" pause keeper 3 >/dev/null 2>&1 && [[ -f "$T/cos/state/pause-keeper" ]] && pass "pause holds a slot" || fail "pause did not write"
HOME="$T" "$COS/bin/cos-run" pause keeper 0 >/dev/null 2>&1 && [[ ! -f "$T/cos/state/pause-keeper" ]] && pass "pause 0 resumes" || fail "pause 0 did not resume"
HOME="$T" "$COS/bin/cos-run" pause nosuch 3 >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "pause refuses an unknown slot" || fail "pause accepted an unknown slot"
HOME="$T" "$COS/bin/cos-run" receipt nosuchjob >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "receipt reports a missing job" || fail "receipt on a missing job"
HOME="$T" "$COS/bin/cos-run" quick x1 "q" --async >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "--async refuses the quick lane" || fail "--async accepted the quick lane"
"$COS/bin/cos-sched" nosuchslot --dry-run >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-sched refuses an unknown slot" || fail "cos-sched accepted an unknown slot"
rm -rf "$T"
# A scheduled job that dies early still leaves a failed receipt, with its error, where cos-run receipt looks.
# Stubs stand in for cos-run, cos-push and the clock (09:00, inside pulse's hours): nothing leaves the Mac.
# The stub's stderr carries a ghp_ token, a Bearer header, an AKIA key and a URL with a password and a query string.
T="$(mktemp -d)"; mkdir -p "$T/cos/bin"; SD="$(date +%Y%m%d)"; SR="$T/cos/outbox/pulse-$SD/receipt.json"
cat > "$T/cos/bin/cos-run" <<'ST'
#!/bin/bash
pwd > "$HOME/cwd"
echo "fatal: unable to access github.com token=ghp_abc123XYZ" >&2
echo "curl -H 'Authorization: Bearer eyJsecretBearer42' failed" >&2
echo "aws key AKIAABCDEFGHIJKLMNOP rejected; see https://bob:pw9secret@example.com/x?sig=q7secret" >&2
exit 128
ST
printf '#!/bin/bash\necho "$*" >> "$HOME/pushed"\n' > "$T/cos/bin/cos-push"
printf '#!/bin/bash\n[[ "$1" == +%%H ]] && { echo 09; exit 0; }\nexec /bin/date "$@"\n' > "$T/cos/bin/date"
chmod +x "$T/cos/bin/"{cos-run,cos-push,date}
mkdir -p "$(dirname "$SR")"; echo '{"receipt":{"status":"done","summary":"an earlier run"}}' > "$SR"
(cd / && HOME="$T" "$COS/bin/cos-sched" pulse >/dev/null 2>&1)
S="$(jq -r .receipt.summary "$SR" 2>/dev/null)"
[[ "$(jq -r .receipt.status "$SR" 2>/dev/null)" == failed && "$S" == *"exit 128"*"unable to access github.com"* ]] && grep -q "steward pulse $SR" "$T/pushed" 2>/dev/null \
  && pass "a scheduled job that dies early gets a failed receipt with its exit code and error, and it is pushed" || fail "scheduled job left no failed receipt with its error ($SR: $S)"
[[ "$(jq -r .receipt.summary "$(dirname "$SR")/receipt.prev.json" 2>/dev/null)" == "an earlier run" ]] && grep -q "Bearer eyJ" "$(dirname "$SR")/sched.err" 2>/dev/null \
  && pass "cos-sched sets the earlier receipt aside and keeps the raw stderr in sched.err" || fail "cos-sched lost the earlier receipt or sched.err"
[[ -n "$S" && "$S" != *ghp_abc* ]] && pass "no ghp_ token reaches the scheduled receipt" || fail "a ghp_ token reached the scheduled receipt: $S"
[[ -n "$S" && "$S" != *eyJsecretBearer* ]] && pass "no Bearer token reaches the scheduled receipt" || fail "a Bearer token reached the scheduled receipt: $S"
[[ -n "$S" && "$S" != *AKIAABCDEFGHIJKLMNOP* ]] && pass "no AKIA key reaches the scheduled receipt" || fail "an AKIA key reached the scheduled receipt: $S"
[[ -n "$S" && "$S" != *pw9secret* && "$S" != *q7secret* ]] && pass "no URL password or query string reaches the scheduled receipt" || fail "a URL secret reached the scheduled receipt: $S"
HOME="$T" "$COS/bin/cos-run" receipt "pulse-$SD" 2>/dev/null | jq -e '.receipt.status == "failed"' >/dev/null \
  && pass "cos-run receipt finds the failed scheduled job" || fail "cos-run receipt can't find the failed scheduled job"
[[ "$(cat "$T/cwd" 2>/dev/null)" == "$T" ]] && pass "cos-sched runs its job from \$HOME" || fail "cos-sched ran its job from $(cat "$T/cwd" 2>/dev/null)"
rm -rf "$T"
# Draft lane and the shared $MAIN worktree. A local bare repo stands in for GitHub and a stub for claude (it adds a line
# to doc.md in the draft worktree, and makes a stray file in data-org-main when the brief says STRAY). Nothing leaves the Mac.
T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"; mkdir -p "$T/cos/bin" "$T/cos/claude" "$T/cos/repos"
cp "$COS/claude/receipt.schema.json" "$COS/claude/lane.md" "$T/cos/claude/"
# The preflight reads each lane's settings and gh: the real settings, and a stub gh that is signed in with calls to spare.
cp "$COS"/claude/settings.{investigate,draft,build}.json "$T/cos/claude/"
printf '#!/bin/bash\n[[ "$1 $2" == "auth status" ]] && exit 0\n[[ "$1 $2" == "api rate_limit" ]] && { echo %s; exit 0; }\nexit 1\n' \
  "'{\"resources\":{\"core\":{\"limit\":5000,\"remaining\":4999,\"reset\":0},\"graphql\":{\"limit\":5000,\"remaining\":4999,\"reset\":0}}}'" > "$T/cos/bin/gh"; chmod +x "$T/cos/bin/gh"
gt() { git -c user.name=t -c user.email=t@t "$@"; }
git init -q --bare "$T/origin.git"; git init -q -b main "$T/seed"; echo a > "$T/seed/doc.md"
gt -C "$T/seed" add -A; gt -C "$T/seed" commit -qm a; gt -C "$T/seed" checkout -qb feat; echo b >> "$T/seed/doc.md"; gt -C "$T/seed" commit -qam b
git -C "$T/seed" push -q "$T/origin.git" main feat 2>/dev/null; git clone -q "$T/origin.git" "$T/cos/repos/data-org" 2>/dev/null
echo c >> "$T/seed/doc.md"; gt -C "$T/seed" commit -qam c; git -C "$T/seed" push -q "$T/origin.git" feat 2>/dev/null   # the clone's origin/feat is now stale
FEAT_TIP="$(git -C "$T/seed" rev-parse feat)"
cat > "$T/cos/bin/claude" <<'STUB'
#!/bin/bash
# Stub claude. The checker passes unless ~/.failchecks says how many checks to fail; a revision round says "revised".
if [[ "$*" == *CHECKER* ]]; then
  n=$(( $(cat "$HOME/.chk" 2>/dev/null || echo 0) + 1 )); echo $n > "$HOME/.chk"
  if [[ $n -le $(cat "$HOME/.failchecks" 2>/dev/null || echo 0) ]]; then
    echo '{"structured_output":{"verdict":"fail","failures":["claim X has no source"],"ask":"Keep or drop claim X?"}}'
  else echo '{"structured_output":{"verdict":"pass","failures":[],"notes":[]}}'; fi
  exit 0
fi
[[ "$PWD" == */.worktrees/* ]] && echo added >> doc.md
pgrep -f "caffeinate -i -s -w $PPID" >/dev/null 2>&1 && touch "$HOME/caffeinated"
[[ "$PWD" == */data-org-main && "$*" == *STRAY* ]] && : > =2026-11-09
[[ "$PWD" == */data-org-main && "$*" == *EDITDOC* ]] && echo edited >> doc.md
if [[ "$*" == *"REVISION ROUND"* ]]; then echo '{"structured_output":{"status":"done","summary":"revised"},"session_id":"s1","total_cost_usd":0.5}'
else echo '{"structured_output":{"status":"done","summary":"stub"},"session_id":"s1","total_cost_usd":1}'; fi
STUB
chmod +x "$T/cos/bin/claude"
HOME="$T" "$COS/bin/cos-run" draft dr1 "Add a line" --base feat >/dev/null 2>&1
DR="$T/cos/outbox/dr1"
jq -e --arg tip "$FEAT_TIP" '.draft.base == "origin/feat" and .draft.base_sha == $tip and .draft.fetched_sha == $tip and .draft.fetched_fresh == true and .draft.files == 1' "$DR/receipt.json" >/dev/null 2>&1 \
  && pass "draft: the worktree starts on the --base branch, fetched fresh" || fail "draft: base not fresh or wrong ($(jq -c .draft "$DR/receipt.json" 2>/dev/null))"
[[ -s "$DR/draft.diff" && "$(jq -r .draft.sha256 "$DR/receipt.json" 2>/dev/null)" == "$(shasum -a 256 "$DR/draft.diff" | cut -d' ' -f1)" ]] && grep -qx '+added' "$DR/draft.diff" \
  && pass "draft: the receipt carries draft.diff and its sha256" || fail "draft: no draft.diff or its sha256 is wrong"
HOME="$T" "$COS/bin/cos-run" draft dr2 "x" --base 'feat;rm' >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "draft refuses a bad --base" || fail "draft accepted a bad --base"
HOME="$T" "$COS/bin/cos-run" draft dr3 "x" --base nosuch >/dev/null 2>&1; rc=$?
[[ $rc -eq 75 && ! -e "$T/cos/outbox/dr3/receipt.json" ]] && pass "draft stops before the model when its base can't be fetched" || fail "draft went on without a fresh base (exit $rc)"
# DRD and DADR drafts (plan item 8): Cassidy's cards only, from main; no status flipped to Approved or accepted; never a
# DRD and a DADR in one diff; at most three questions. A stub cos-gh answers "whose"; the real one guards the diff.
printf '#!/bin/bash\ncase "$2" in whose) cat "$HOME/whose.json";; *) exec "%s" "$@";; esac\n' "$COS/bin/cos-gh" > "$T/cos/bin/cos-gh"; chmod +x "$T/cos/bin/cos-gh"
cp "$COS/bin/cos-flow" "$T/cos/bin/"; echo '{"now":"2026-11-14T18:00:00+00:00","items":[],"prs":[],"docs":[]}' > "$T/flowfix.json"
echo '{"mine":true,"owner":"cassidythilton"}' > "$T/whose.json"; HOME="$T" "$COS/bin/cos-run" draft dd0 "x" --doc drd --card data-org#712 >/dev/null 2>&1; [[ $? -eq 66 && ! -e "$T/cos/outbox/dd0/.draft-doc" ]] && pass "draft --doc stops when its brief template is missing" || fail "draft --doc ran without its template"
mkdir -p "$T/cos/claude/briefs"; cp "$COS/claude/briefs/draft-doc.md" "$T/cos/claude/briefs/"
git -C "$T/seed" push -q "$T/origin.git" main:cassidy/1-x 2>/dev/null
{ head -1 "$T/cos/bin/claude"; cat <<'INS'
[[ "$*" != *CHECKER* ]] && echo x >> "$HOME/claude.calls"
if [[ "$*" != *CHECKER* && -f "$HOME/.docmode" && "$PWD" == */.worktrees/* ]]; then mkdir -p drd
  printf -- '---\nid: DRD-0099\nstatus: %s\n---\n' "$(cat "$HOME/.docmode")" > drd/DRD-0099-test.md
  [[ -f "$HOME/.docmode2" ]] && { mkdir -p dadr; printf -- '---\nid: DADR-0099\nstatus: proposed\n---\n' > dadr/DADR-0099-test.md; }
  echo '{"structured_output":{"status":"done","summary":"stub doc","open_questions":["1?","2?","3?","4?"]},"session_id":"s2","total_cost_usd":1}'; exit 0; fi
INS
tail -n +2 "$T/cos/bin/claude"; } > "$T/claude.new" && mv "$T/claude.new" "$T/cos/bin/claude" && chmod +x "$T/cos/bin/claude"
echo '{"mine":false,"owner":"nicholas"}' > "$T/whose.json"; c0="$(wc -l < "$T/claude.calls" 2>/dev/null || echo 0)"
HOME="$T" "$COS/bin/cos-run" draft dd1 "x" --doc drd --card data-org#800 >/dev/null 2>"$T/err"; rc=$?
[[ $rc -eq 65 && "$(wc -l < "$T/claude.calls" 2>/dev/null || echo 0)" == "$c0" && ! -d "$T/cos/repos/data-org/.worktrees/cos-dd1" ]] && grep -q "never a draft of their doc" "$T/err" \
  && pass "draft --doc refuses another owner's card, before any model or worktree" || fail "draft --doc on another owner's card (rc $rc)"
HOME="$T" "$COS/bin/cos-run" draft dd2 "x" --doc drd >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "draft --doc refuses without --card" || fail "draft --doc ran without --card"
echo '{"mine":true,"owner":"cassidythilton"}' > "$T/whose.json"
HOME="$T" "$COS/bin/cos-run" draft dd3 "x" --doc drd --card data-org#712 --base feat >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "draft --doc refuses a base other than main" || fail "draft --doc ran from another base"
HOME="$T" "$COS/bin/cos-run" draft dd4 "x" --card data-org#712 >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "draft refuses --card without --doc" || fail "draft took --card without --doc"
HOME="$T" "$COS/bin/cos-run" draft dd5 "x" --doc memo --card data-org#712 >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "draft refuses a --doc other than drd or dadr" || fail "draft took --doc memo"
echo Draft > "$T/.docmode"
COS_FLOW_FIXTURE="$T/flowfix.json" HOME="$T" "$COS/bin/cos-run" draft dd6 "He wants the label facts written up" --doc drd --card data-org#712 >/dev/null 2>&1
jq -e '.draft.doc.kind == "drd" and .draft.doc.card == "data-org#712" and .draft.doc.new_ids == ["DRD-0099"] and .draft.doc.next_id.free == true
       and (.receipt.open_questions | length) == 3 and (.receipt.status != "blocked")' "$T/cos/outbox/dd6/receipt.json" >/dev/null 2>&1 \
  && grep -q 'draft-drd/SKILL.md' "$T/cos/outbox/dd6/brief.md" && grep -q 'From the Chief' "$T/cos/outbox/dd6/brief.md" && grep -q '^drd data-org#712$' "$T/cos/outbox/dd6/.draft-doc" \
  && pass "draft --doc on his card: the draft-drd brief, the new ID checked free, at most three questions" || fail "draft --doc pass path ($(jq -c '{d:.draft.doc,q:(.receipt.open_questions|length),s:.receipt.status}' "$T/cos/outbox/dd6/receipt.json" 2>/dev/null))"
echo Approved > "$T/.docmode"
COS_FLOW_FIXTURE="$T/flowfix.json" HOME="$T" "$COS/bin/cos-run" draft dd7 "x" --doc drd --card data-org#712 >/dev/null 2>&1
jq -e '.receipt.status == "blocked" and (.draft.blocked | test("Approved"))' "$T/cos/outbox/dd7/receipt.json" >/dev/null 2>&1 \
  && pass "a draft that sets a DRD to Approved is blocked (no job flips a status)" || fail "a draft flipped a status to Approved and wasn't blocked"
HOME="$T" "$COS/bin/cos-run" draft dd8 "x" --base cassidy/1-x >/dev/null 2>&1
jq -e '.receipt.status == "blocked"' "$T/cos/outbox/dd8/receipt.json" >/dev/null 2>&1 && [[ ! -e "$T/cos/outbox/dd8/apply.sh" ]] \
  && pass "a blocked draft on one of his branches is never staged for a push" || fail "a blocked draft was staged for a push"
echo Draft > "$T/.docmode"; touch "$T/.docmode2"
COS_FLOW_FIXTURE="$T/flowfix.json" HOME="$T" "$COS/bin/cos-run" draft dd9 "x" --doc drd --card data-org#712 >/dev/null 2>&1
jq -e '.receipt.status == "blocked" and (.draft.blocked | test("separate PRs"))' "$T/cos/outbox/dd9/receipt.json" >/dev/null 2>&1 \
  && pass "a draft that adds a DRD and a DADR is blocked (separate PRs)" || fail "a DRD and a DADR went in one draft"
rm -f "$T/.docmode" "$T/.docmode2"
# A lock held by a live job: the next job waits, then stops. It never goes on without the lock.
sleep 60 & LIVE=$!; echo "$LIVE" > "$T/cos/state/data-org-main.lock"
COS_LOCK_WAIT=2 HOME="$T" "$COS/bin/cos-run" investigate ivl "x" >/dev/null 2>&1; rc=$?
[[ $rc -eq 75 && ! -e "$T/cos/outbox/ivl/receipt.json" && "$(cat "$T/cos/state/data-org-main.lock")" == "$LIVE" ]] \
  && pass "a job stops, and leaves the lock alone, when a live job holds data-org-main" || fail "a job went on past a live lock (exit $rc)"
kill "$LIVE" 2>/dev/null; wait "$LIVE" 2>/dev/null; rm -f "$T/cos/state/data-org-main.lock"
# An old git index.lock that a process still holds open is never removed; the job stops on git's error instead.
IXL="$(git -C "$T/cos/data-org-main" rev-parse --path-format=absolute --git-path index.lock 2>/dev/null)"
( exec 9>>"$IXL"; exec sleep 60 ) & HOLD=$!; sleep 1; touch -t 202601010000 "$IXL"
HOME="$T" "$COS/bin/cos-run" investigate ivh "x" >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 && -e "$IXL" ]] && pass "a held index.lock, however old, is never removed" || fail "a held index.lock was removed or ignored (exit $rc)"
kill "$HOLD" 2>/dev/null; wait "$HOLD" 2>/dev/null
# A lock left by a dead job and a git index.lock left by a killed git don't stop the next job; parallel jobs don't collide.
(exit 0) & DEADPID=$!; wait $DEADPID; echo "$DEADPID" > "$T/cos/state/data-org-main.lock"
: > "$IXL"; touch -t 202601010000 "$IXL"
for i in 1 2 3 4; do HOME="$T" "$COS/bin/cos-run" investigate "iv$i" "x" >/dev/null 2>&1 & done; wait
n=0; for i in 1 2 3 4; do jq -e '.receipt.status == "done"' "$T/cos/outbox/iv$i/receipt.json" >/dev/null 2>&1 && n=$((n+1)); done
[[ $n -eq 4 && ! -e "$IXL" && ! -e "$T/cos/state/data-org-main.lock" ]] && pass "4 parallel jobs share data-org-main past a dead lock and a dead index.lock" || fail "shared worktree: $n of 4 jobs finished (index.lock $([[ -e "$IXL" ]] && echo left || echo gone))"
# A file an investigate job leaves in data-org-main moves to its job folder; a file that was there before stays.
echo keep > "$T/cos/data-org-main/keep.txt"
HOME="$T" "$COS/bin/cos-run" investigate ivs "STRAY test" >/dev/null 2>&1
[[ ! -e "$T/cos/data-org-main/=2026-11-09" && -e "$T/cos/outbox/ivs/strays/=2026-11-09" && -e "$T/cos/data-org-main/keep.txt" ]] \
  && jq -e '.strays == ["=2026-11-09"] and (.receipt.summary | startswith("Note: the job left files"))' "$T/cos/outbox/ivs/receipt.json" >/dev/null 2>&1 \
  && pass "investigate: a stray file in data-org-main moves to the job folder and the receipt says so" || fail "investigate: stray file not moved or not reported ($(jq -c .strays "$T/cos/outbox/ivs/receipt.json" 2>/dev/null))"
# An edit to a tracked file in data-org-main is saved to the job folder and undone.
HOME="$T" "$COS/bin/cos-run" investigate ive "EDITDOC test" >/dev/null 2>&1
[[ -z "$(git -C "$T/cos/data-org-main" diff --name-only HEAD)" ]] && grep -q '+edited' "$T/cos/outbox/ive/strays/tracked-edits.diff" 2>/dev/null \
  && jq -e '.stray_edits == ["doc.md"]' "$T/cos/outbox/ive/receipt.json" >/dev/null 2>&1 \
  && pass "investigate: an edit to a tracked file is saved to the job folder and undone" || fail "investigate: a tracked edit stayed in data-org-main"
# Self-healing: the checker blocks the first try, the job revises once, and the second check passes.
rm -f "$T/.chk"; echo 1 > "$T/.failchecks"
HOME="$T" "$COS/bin/cos-run" investigate rv1 "x" >/dev/null 2>&1
jq -e '.checker.verdict == "pass" and .receipt.verdict == "VERIFIED" and .revision.rounds == 1 and .revision.first_failures == ["claim X has no source"] and .receipt.summary == "revised" and .cost_usd == 1.5' "$T/cos/outbox/rv1/receipt.json" >/dev/null 2>&1 \
  && [[ -f "$T/cos/outbox/rv1/receipt.round1.json" ]] && pass "self-healing: a blocked job revises once and passes the second check" || fail "self-healing round didn't run or didn't pass ($(jq -c '{v:.checker.verdict,r:.revision,s:.receipt.summary,c:.cost_usd}' "$T/cos/outbox/rv1/receipt.json" 2>/dev/null))"
rm -f "$T/.chk"; echo 2 > "$T/.failchecks"
HOME="$T" "$COS/bin/cos-run" investigate rv2 "x" >/dev/null 2>&1
jq -e '.checker.verdict == "fail" and .receipt.verdict == "NOT VERIFIED" and .revision.rounds == 1 and (.receipt.summary | startswith("Needs you: Keep or drop claim X?"))' "$T/cos/outbox/rv2/receipt.json" >/dev/null 2>&1 \
  && [[ "$(cat "$T/.chk")" == 2 ]] && pass "self-healing stops after one round and leads with one plain question" || fail "a twice-blocked job looped or didn't ask plainly"
rm -f "$T/.chk" "$T/.failchecks"
if [[ $SANDBOX -eq 1 ]]; then echo "  · sandbox: caffeinate check skipped"
else [[ -f "$T/caffeinated" ]] && pass "long jobs run under caffeinate -i -s -w <cos-run's pid>" || fail "no caffeinate held the Mac awake during a job"; fi
# The pair lane is gone: a build with a new slug scaffolds its workspace from the template first.
cp -R "$COS/builds-template" "$T/cos/builds-template"; cp "$COS/claude/build-lane.md" "$COS/claude/verifier.md" "$COS/claude/agents.json" "$T/cos/claude/" 2>/dev/null
HOME="$T" "$COS/bin/cos-run" build bd1 "Count the scans" --slug demo-scan >/dev/null 2>&1
grep -q 'demo-scan' "$T/builds/demo-scan/BRIEF.md" 2>/dev/null && [[ "$(git -C "$T/builds/demo-scan" rev-parse --abbrev-ref HEAD 2>/dev/null)" == build/demo-scan ]] \
  && pass "build scaffolds a new workspace from the template (replaces cos-run pair)" || fail "build didn't scaffold its workspace"
HOME="$T" "$COS/bin/cos-run" build bd2 "x" --slug 'Bad Slug' >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "build refuses a bad slug" || fail "build accepted a bad slug"
# A job that stopped without a receipt reads "didn't finish, rerun?", with the call to rerun.
mkdir -p "$T/cos/outbox/ij"; (exit 0) & DP=$!; wait $DP; echo "$DP" > "$T/cos/outbox/ij/.running"
printf '%s' "$COS/bin/cos-run investigate ij \"the brief\" --async" > "$T/cos/outbox/ij/.cmd"
RI="$(HOME="$T" "$COS/bin/cos-run" receipt ij 2>/dev/null)"; jq -e '.status == "interrupted" and (.receipt.summary | test("Didn.t finish.*Rerun\\? cos-run investigate ij .the brief. --async$")) and .rerun != null' <<<"$RI" >/dev/null \
  && pass "an interrupted job's receipt says didn't finish, rerun?, with the exact call" || fail "interrupted job not reported plainly ($(HOME="$T" "$COS/bin/cos-run" receipt ij 2>/dev/null | head -c 300))"
# A draft on one of Cassidy's branches stages its push; the approved batch pushes exactly the reviewed diff.
gt -C "$T/seed" checkout -qb cassidy/pr main; echo pr >> "$T/seed/doc.md"; gt -C "$T/seed" commit -qam pr; git -C "$T/seed" push -q "$T/origin.git" cassidy/pr 2>/dev/null
cp "$COS/bin/cos-push-draft" "$T/cos/bin/"
HOME="$T" "$COS/bin/cos-run" draft dp1 "Edit the PR" --base cassidy/pr >/dev/null 2>&1
DS="$(jq -r .draft.sha256 "$T/cos/outbox/dp1/receipt.json" 2>/dev/null)"; BS="$(jq -r .batch.sha256 "$T/cos/outbox/dp1/receipt.json" 2>/dev/null)"
grep -qx "cos-push-draft dp1 $DS" "$T/cos/outbox/dp1/apply.sh" 2>/dev/null && pass "draft on a cassidy/ branch stages its push with the diff's sha256" || fail "draft didn't stage its push"
HOME="$T" "$COS/bin/cos-run" apply dp1 "$BS" --in "$T" >/dev/null 2>&1
[[ "$(git -C "$T/origin.git" log -1 --format=%s cassidy/pr)" == "Edit the PR" ]] && pass "the approved batch pushes the draft onto the PR branch (fast-forward)" || fail "the approved push didn't reach the branch"
HOME="$T" "$COS/bin/cos-run" draft dp2 "Edit again" --base cassidy/pr >/dev/null 2>&1
echo tampered >> "$T/cos/repos/data-org/.worktrees/cos-dp2/doc.md"; git -C "$T/cos/repos/data-org/.worktrees/cos-dp2" commit -qam t 2>/dev/null
HOME="$T" "$COS/bin/cos-push-draft" dp2 "$(jq -r .draft.sha256 "$T/cos/outbox/dp2/receipt.json")" >/dev/null 2>&1; [[ $? -eq 67 ]] && pass "cos-push-draft refuses a draft changed after review" || fail "cos-push-draft pushed a changed draft"
HOME="$T" "$COS/bin/cos-run" draft dp3 "Edit main" --base main >/dev/null 2>&1
HOME="$T" "$COS/bin/cos-push-draft" dp3 "$(jq -r .draft.sha256 "$T/cos/outbox/dp3/receipt.json")" >/dev/null 2>&1; [[ $? -eq 65 ]] && ! grep -q cos-push-draft "$T/cos/outbox/dp3/apply.sh" 2>/dev/null \
  && pass "a draft on main is never pushed (only Cassidy's own branches)" || fail "a draft on main could be pushed"
# A resumed draft re-checks the base it saved, because the job folder is writable by the model.
echo 'feat;rm -rf x' > "$T/cos/outbox/dr1/.draft-base"
HOME="$T" "$COS/bin/cos-run" draft dr1 "x" >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "draft refuses a tampered saved base on resume" || fail "draft trusted a tampered saved base"
rm -rf "$T"
# Preflight (Nov 14): a lane that can't run stops before the model, with a blocked_preflight receipt and one plain reason.
# Stubs stand in for gh (sign-in and rate limit set by files) and claude (logs every model call; answers mcp list).
T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"; mkdir -p "$T/cos/bin" "$T/cos/claude" "$T/cos/zoom"
cp "$COS"/claude/settings.{investigate,sheet}.json "$COS/claude/receipt.schema.json" "$COS/claude/lane.md" "$T/cos/claude/"; cp "$COS/bin/cos-ledger" "$T/cos/bin/"
cat > "$T/cos/bin/gh" <<'STUB'
#!/bin/bash
[[ "$1 $2" == "auth status" ]] && { echo "Token: ghp_preflightSECRET42"; exit "$(cat "$HOME/.gh-auth" 2>/dev/null || echo 0)"; }
[[ "$1 $2" == "api rate_limit" ]] && { cat "$HOME/.gh-rate"; exit 0; }
exit 1
STUB
cat > "$T/cos/bin/claude" <<'STUB'
#!/bin/bash
[[ "$1 $2" == "mcp list" ]] && { cat "$HOME/.mcp" 2>/dev/null; exit 0; }
echo x >> "$HOME/claude.calls"; echo '{"structured_output":{"status":"done","summary":"stub"},"total_cost_usd":1}'
STUB
chmod +x "$T/cos/bin/"{gh,claude}
rate() { printf '{"resources":{"core":{"limit":5000,"remaining":%s,"reset":1700000000},"graphql":{"limit":5000,"remaining":%s,"reset":1700000000}}}' "$1" "$2" > "$T/.gh-rate"; }
pfr() { HOME="$T" "$COS/bin/cos-run" "$@" 2>/dev/null; }
rate 4000 4000; o="$(pfr preflight investigate)"; rc=$?
[[ $rc -eq 0 ]] && jq -e '.preflight == "ok"' <<<"$o" >/dev/null 2>&1 && pass "preflight: investigate is ok with gh signed in and calls to spare" || fail "preflight investigate on a healthy Mac (rc $rc: $o)"
rate 4000 3; pfr investigate pf1 "Which PRs wait on me?" --in "$T" >/dev/null; rc=$?
[[ $rc -eq 0 && ! -e "$T/claude.calls" ]] && jq -e '.receipt.status == "blocked_preflight" and .cost_usd == 0 and (.receipt.summary | test("GraphQL rate limit is nearly spent: 3 of 5000"))' "$T/cos/outbox/pf1/receipt.json" >/dev/null 2>&1 \
  && pass "preflight: a spent GraphQL rate limit stops the job before the model, with the reason" || fail "preflight let a rate-limited job run (rc $rc: $(jq -c .receipt "$T/cos/outbox/pf1/receipt.json" 2>/dev/null))"
rate 40 4000; o="$(pfr preflight investigate)"; [[ $? -eq 1 ]] && jq -e '.reason | test("REST rate limit")' <<<"$o" >/dev/null 2>&1 && pass "preflight: a spent REST rate limit is a reason too" || fail "preflight missed the REST rate limit ($o)"
rate 4000 4000; ZD="$T/cos/zoom/2020-01-01 10.00.00 Sync"; mkdir -p "$ZD"; echo x > "$ZD/meeting_saved_closed_caption.txt"; touch -t 202001011100 "$ZD/meeting_saved_closed_caption.txt"
pfr investigate calls-20200102 "Action items from today's calls" --in "$T" >/dev/null; rc=$?
[[ $rc -eq 0 && ! -e "$T/claude.calls" ]] && jq -e '.receipt.status == "blocked_preflight" and (.receipt.summary | test("no Zoom transcript for 2020-01-02 in ~/cos/zoom"))' "$T/cos/outbox/calls-20200102/receipt.json" >/dev/null 2>&1 \
  && pass "preflight: a calls job with no transcript for its day in ~/cos/zoom stops before the model" || fail "preflight let a calls job run without its transcript (rc $rc: $(jq -c .receipt "$T/cos/outbox/calls-20200102/receipt.json" 2>/dev/null))"
ZD="$T/cos/zoom/2020-01-02 09.00.00 Standup"; mkdir -p "$ZD"; echo x > "$ZD/meeting_saved_closed_caption.txt"
o="$(pfr preflight investigate calls-20200102)"; [[ $? -eq 0 ]] && pass "preflight: that day's transcript in ~/cos/zoom lets the calls job run" || fail "preflight blocked a calls job that has its transcript ($o)"
echo 1 > "$T/.gh-auth"; o="$(pfr preflight investigate)"; rc=$?
[[ $rc -eq 1 ]] && jq -e '.reason | test("gh is not signed in")' <<<"$o" >/dev/null 2>&1 && pass "preflight: gh signed out is the reason, in plain words" || fail "preflight missed gh signed out (rc $rc: $o)"
pfr investigate pf2 "x" --in "$T" >/dev/null
jq -e '.receipt.status == "blocked_preflight"' "$T/cos/outbox/pf2/receipt.json" >/dev/null 2>&1 && jq -e 'select(.stream == "preflight" and .job == "pf2")' "$T/cos/state/ledger/preflight.jsonl" >/dev/null 2>&1 \
  && ! grep -rq 'ghp_preflight' "$T/cos/outbox" "$T/cos/state" && pass "preflight: the block is ledgered, and no token reaches the receipt or the ledger" || fail "preflight: no ledger row, or a token leaked"
rm -f "$T/.gh-auth"
jq '.permissions.allow -= ["Bash(cos-atlas *)"]' "$COS/claude/settings.investigate.json" > "$T/cos/claude/settings.investigate.json"
o="$(pfr preflight atlas)"; [[ $? -eq 1 ]] && jq -e '.reason | test("doesn.t allow Bash\\(cos-atlas \\*\\)")' <<<"$o" >/dev/null 2>&1 && pass "preflight: an atlas lane whose settings don't allow cos-atlas is stopped" || fail "preflight missed atlas's missing Bash rule ($o)"
cp "$COS/claude/settings.investigate.json" "$T/cos/claude/"
# The Sheets connector only warns (KEEPER, Nov 14): no real `claude mcp list` from this Mac has shown its format yet.
echo 'claude.ai Slack: https://mcp.slack.com/mcp - ✓ Connected' > "$T/.mcp"
o="$(pfr preflight apply-sheet)"; [[ $? -eq 0 ]] && jq -e '.preflight == "ok" and (.warning | test("Google Sheets connector may not be attached"))' <<<"$o" >/dev/null 2>&1 \
  && pass "preflight: apply-sheet without the Sheets connector is a warning, not a block" || fail "preflight blocked apply-sheet on the Sheets connector, or gave no warning ($o)"
pfr investigate sheet-20200102-r1 "x" --in "$T" >/dev/null; rc=$?
[[ $rc -eq 0 && -e "$T/claude.calls" ]] && jq -e '.receipt.status != "blocked_preflight" and .preflight.status == "warn" and (.preflight.note | test("Google Sheets connector"))' "$T/cos/outbox/sheet-20200102-r1/receipt.json" >/dev/null 2>&1 \
  && jq -e 'select(.stream == "preflight" and .job == "sheet-20200102-r1" and .status == "warn")' "$T/cos/state/ledger/preflight.jsonl" >/dev/null 2>&1 \
  && pass "preflight: a sheet-* job without the Sheets connector runs, with a ledger row and a note in its receipt" || fail "preflight: the Sheets warning blocked the job, or left no ledger row or receipt note (rc $rc: $(jq -c '{receipt, preflight}' "$T/cos/outbox/sheet-20200102-r1/receipt.json" 2>/dev/null))"
rm -f "$T/claude.calls"
echo 'claude.ai Google Sheets: https://sheets.example/mcp - ✓ Connected' >> "$T/.mcp"
o="$(pfr preflight investigate sheet-20200102-r1)"; [[ $? -eq 0 ]] && jq -e 'has("warning") | not' <<<"$o" >/dev/null 2>&1 && pass "preflight: a sheet-* job with the Sheets connector connected is ok, with no warning" || fail "preflight warned on a sheet job with Sheets connected ($o)"
pfr preflight nosuchlane >/dev/null; [[ $? -eq 64 ]] && pass "preflight refuses an unknown lane" || fail "preflight took an unknown lane"
pfr preflight fix >/dev/null; [[ $? -eq 64 ]] && pass "preflight: the fix lane has none (its block can't change from a fix job)" || fail "preflight took the fix lane"
# eval and quick (the second opinion, Nov 14): eval runs it too, and quick runs it before its --with reads.
printf '#!/bin/bash\necho x >> "$HOME/claude.calls"; echo %s\n' "'{\"result\":\"stub\"}'" > "$T/cos/bin/agent"; chmod +x "$T/cos/bin/agent"
echo 1 > "$T/.gh-auth"; mkdir -p "$T/cos/evals"; echo '{"cases":[{"brief":"x","rubric":["y"]}]}' > "$T/cos/evals/pfe.json"
pfr eval pfe current --async >/dev/null
[[ ! -e "$T/claude.calls" && ! -d "$T/cos/evals/runs" ]] && jq -e '.receipt.status == "blocked_preflight" and (.receipt.summary | test("gh is not signed in"))' "$T/cos/outbox/eval-pfe/receipt.json" >/dev/null 2>&1 \
  && pass "preflight: eval stops before its cases and its judge, with the reason in eval-<suite>" || fail "preflight let an eval run with gh signed out ($(jq -c .receipt "$T/cos/outbox/eval-pfe/receipt.json" 2>/dev/null))"
pfr quick pfq "Which PRs are open?" --with "gh pr list --repo a/b" --in "$T" >/dev/null
[[ ! -e "$T/claude.calls" && ! -e "$T/cos/outbox/pfq/context.txt" ]] && jq -e '.receipt.status == "blocked_preflight"' "$T/cos/outbox/pfq/receipt.json" >/dev/null 2>&1 \
  && pass "preflight: quick stops before its --with reads run" || fail "preflight let quick run its reads or the model with gh signed out"
rm -f "$T/.gh-auth"
# A passing eval keeps its job name: the receipt of the detached run is eval-<suite>, never eval-eval-<suite>. Its one case
# finds data-org-main locked by this shell and stops in a second (COS_LOCK_WAIT=1); the stub judge's output doesn't parse.
mkdir -p "$T/cos/state" "$T/cos/outbox/eval-pfe2"; echo $$ > "$T/cos/state/data-org-main.lock"; cp "$T/cos/evals/pfe.json" "$T/cos/evals/pfe2.json"
COS_ASYNC_CHILD=1 COS_ASYNC_DIR="$T/cos/outbox/eval-pfe2" COS_LOCK_WAIT=1 pfr eval pfe2 current --async >/dev/null
jq -e '.job == "eval-pfe2" and .lane == "eval" and .receipt.status == "done"' "$T/cos/outbox/eval-pfe2/receipt.json" >/dev/null 2>&1 && ! ls "$T/cos/evals/runs" | grep -q '^eval-' \
  && pass "preflight: a passing async eval's receipt is job eval-<suite>, exactly" || fail "a passing eval's receipt job is $(jq -c .job "$T/cos/outbox/eval-pfe2/receipt.json" 2>/dev/null), not eval-pfe2"
rm -rf "$T"

echo "8. lake-query refuses what it should"
T="$(mktemp -d)"; echo "select name from wisecode_gold.canon_ingredient limit 5" > "$T/a.sql"; echo "delete from food" > "$T/b.sql"; echo "select * from food" > "$T/c.sql"
"$COS/bin/lake-query" "$T/a.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "canon values blocked" || fail "canon values not blocked"
"$COS/bin/lake-query" "$T/b.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "writes blocked" || fail "writes not blocked"
"$COS/bin/lake-query" "$T/c.sql" >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "unbounded query blocked" || fail "unbounded query not blocked"
rm -rf "$T"

echo "12. Tier 0 (cos-run gh), the lake lane, help, preview"
# Stubs stand in for gh and make, keeping each card as a JSON file the stubs read and change. Nothing reaches GitHub.
T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"; mkdir -p "$T/cos/bin" "$T/cos/data-org-main" "$T/cards" "$T/cos/handbook"
cp "$COS/bin/cos-ledger" "$COS/bin/cos-gh" "$COS/bin/cos-run" "$T/cos/bin/"
cat > "$T/cos/bin/gh" <<'STUB'
#!/bin/bash
a="$*"; echo "gh ${a//$'\n'/ }" >> "$HOME/gh.log"
if [[ "$1 $2" == "api user" ]]; then echo "${STUB_LOGIN:-cassidythilton}"; exit 0; fi
if [[ "$1 $2" == "api graphql" ]]; then
  r=""; n=""; for a in "$@"; do case "$a" in r=*) r="${a#r=}";; n=*) n="${a#n=}";; esac; done
  [[ "$*" == *mutation* ]] && exit 0
  cat "$HOME/cards/$r-$n.json"; exit 0
fi
if [[ "$1 $2" == "issue edit" || "$1 $2" == "pr edit" ]]; then
  n="$3"; r="${5#wisecodeai/}"; f="$HOME/cards/$r-$n.json"; flag="$6"; v="$7"
  case "$flag" in
    --add-label) jq --arg v "$v" '.data.repository.issueOrPullRequest.labels.nodes += [{name:$v}]' "$f" > "$f.t" && mv "$f.t" "$f";;
    --remove-label) jq --arg v "$v" '.data.repository.issueOrPullRequest.labels.nodes |= map(select(.name != $v))' "$f" > "$f.t" && mv "$f.t" "$f";;
  esac; exit 0
fi
[[ "$1 $2" == "project field-list" ]] && { echo '{"fields":[{"name":"Theme","id":"F_THEME"},{"name":"Status","id":"F_STATUS"}]}'; exit 0; }
exit 0
STUB
cat > "$T/cos/bin/make" <<'STUB'
#!/bin/bash
echo "make ${DRY_RUN:+DRY_RUN=1 }$*" >> "$HOME/make.log"
[[ "${DRY_RUN:-}" == 1 ]] && exit 0
card=""; field=""; to=""; for a in "$@"; do case "$a" in CARD=*) card="${a#CARD=}";; FIELD=*) field="${a#FIELD=}";; TO=*) to="${a#TO=}";; esac; done
[[ " $* " == *" field "* ]] || exit 0
f="$HOME/cards/data-org-$card.json"
jq --arg f "$field" --arg v "$to" '.data.repository.issueOrPullRequest.projectItems.nodes[0].fieldValues.nodes |= (map(select(.field.name != $f)) + [{name:$v, field:{name:$f, id:"F_X"}}])' "$f" > "$f.t" && mv "$f.t" "$f"
STUB
chmod +x "$T/cos/bin/"{gh,make,cos-gh,cos-ledger,cos-run}
mkcard() {  # mkcard <n> <author> <assignees json> <boarded 0|1> [fields json]
  jq -n --argjson n "$1" --arg a "$2" --argjson as "$3" --argjson b "$4" --argjson fv "${5:-[]}" '{data:{repository:{issueOrPullRequest:{
    __typename:"Issue", id:("I_\($n)"), number:$n, title:"card \($n)", state:"OPEN", url:"https://github.com/wisecodeai/data-org/issues/\($n)",
    author:{login:$a}, assignees:{nodes:($as|map({login:.}))}, labels:{nodes:[]}, milestone:null, parent:null,
    subIssues:{nodes:[]}, blockedBy:{nodes:[]},
    projectItems:{nodes:(if $b == 1 then [{id:"PVTI_\($n)", project:{number:1, id:"PVT_1"}, fieldValues:{nodes:$fv}}] else [] end)}}}}}' > "$T/cards/data-org-$1.json"; }
mkcard 712 cassidythilton '["cassidythilton"]' 1 '[{"name":"Shipping","field":{"name":"Status","id":"F_STATUS"}}]'
mkcard 800 nicholas '["nicholas"]' 1 '[{"name":"Shipping","field":{"name":"Status","id":"F_STATUS"}}]'
mkcard 801 cassidythilton '["melanie"]' 1
gx() { HOME="$T" PATH="$T/cos/bin:$PATH" "$T/cos/bin/cos-run" gh "$@"; }
t0rows() { jq -s "$@" "$T/cos/state/ledger/tier_zero.jsonl" 2>/dev/null; }
# His card: a label added, read back, ledgered with its undo; then undone.
gx t1 label data-org#712 add type/test --evidence "installer test" >/dev/null 2>&1; rc=$?
REF="$(t0rows -r '[.[] | select(.decision=="done")][0].ref')"
[[ $rc -eq 0 ]] && jq -e '.receipt.verdict == "VERIFIED"' "$T/cos/outbox/t1/receipt.json" >/dev/null 2>&1 && grep -q 'issue edit 712 --repo wisecodeai/data-org --add-label type/test' "$T/gh.log" \
  && t0rows -e '.[0] | .decision=="done" and .old=="absent" and .new=="present" and .evidence=="installer test" and (.undo_argv|test("--remove-label"))' >/dev/null \
  && pass "tier 0: a label on his card is re-read, written, read back VERIFIED, and ledgered with old, new, evidence and undo" || fail "tier 0 label write (rc $rc)"
gx t1u undo "$REF" >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && [[ "$(jq -r '.data.repository.issueOrPullRequest.labels.nodes|length' "$T/cards/data-org-712.json")" == 0 ]] && t0rows -e 'any(.[]; .decision=="undone" and .verdict=="VERIFIED")' >/dev/null \
  && pass "tier 0: the undo puts it back and is ledgered" || fail "tier 0 undo (rc $rc)"
gx t1u undo "$REF" >/dev/null 2>&1; [[ $? -eq 68 ]] && pass "tier 0: an undo runs once" || fail "tier 0 undid twice"
n0="$(grep -c 'issue edit' "$T/gh.log")"; gx t1 label data-org#712 add type/test >/dev/null 2>&1
[[ "$(grep -c 'issue edit' "$T/gh.log")" == "$n0" ]] && pass "tier 0: the same job again reports, and writes nothing" || fail "tier 0 repeated a write"
gx t2 label data-org#712 add type/x >/dev/null 2>&1; jq '.data.repository.issueOrPullRequest.labels.nodes = []' "$T/cards/data-org-712.json" > "$T/c.t" && mv "$T/c.t" "$T/cards/data-org-712.json"
gx t2u undo "$(t0rows -r '[.[] | select(.job=="t2")][0].ref')" >/dev/null 2>&1; [[ $? -eq 65 ]] && pass "tier 0: no undo when someone changed the value since" || fail "tier 0 undid over someone's change"
gx t3 field data-org#712 Theme "Relevance" >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && grep -q 'make DRY_RUN=1 -s field CARD=712 FIELD=Theme TO=Relevance' "$T/make.log" && grep -q '^make -s field CARD=712 FIELD=Theme TO=Relevance$' "$T/make.log" \
  && t0rows -e 'any(.[]; .job=="t3" and .old=="" and (.undo_argv|test("--clear")))' >/dev/null \
  && pass "tier 0: a roadmap field goes through make field, previewed first; its undo clears it" || fail "tier 0 field (rc $rc)"
gx t3b field data-org#712 Theme "Relevance" >/dev/null 2>&1; jq -e '.tier0.decision == "noop"' "$T/cos/outbox/t3b/receipt.json" >/dev/null 2>&1 && pass "tier 0: a value already set is a no-op" || fail "tier 0 rewrote a set value"
# Walls, each refused with its tier.
t0ref() { local job="$1" want="$2"; shift 2; local before; before="$(cat "$T/gh.log" "$T/make.log" 2>/dev/null | grep -cv 'api \|field-list\|DRY_RUN' )"
  gx "$job" "$@" >/dev/null 2>"$T/err"; local rc=$?
  [[ $rc -eq "$want" && "$(cat "$T/gh.log" "$T/make.log" 2>/dev/null | grep -cv 'api \|field-list\|DRY_RUN')" == "$before" ]] && pass "tier 0 refuses: $* ($(head -c 90 "$T/err"))" || fail "tier 0 didn't refuse (rc $rc): $*"; }
t0ref r1 65 label data-org#800 add type/x
t0ref r2 65 label data-org#801 add type/x
t0ref r3 65 field data-org#800 Theme Relevance --row /dev/null
t0ref r4 65 field data-org#712 Initiative P002
t0ref r5 65 comment data-org#712 hi
t0ref r6 65 lane data-org#712 "Completed No Delivery" --evidence https://github.com/x
t0ref r7 64 lane data-org#712 Defining
t0ref r8 65 lane data-org#800 Defining --evidence https://github.com/wisecodeai/data-org/pull/1
t0ref r9 65 board-add data-org#800
t0ref r10 65 ragb data-org#712 GREEN
t0ref r11 64 create data-org --title x --body-file /etc/hosts --evidence y
t0ref r12 65 merge data-org#712
STUB_LOGIN=someoneelse gx r13 label data-org#712 add type/x >/dev/null 2>&1; [[ $? -eq 77 ]] && pass "tier 0 refuses when gh is signed in as someone else" || fail "tier 0 ran as another login"
t0rows -e '[.[] | select(.decision=="refused")] | length >= 9 and all(.[]; .tier != null)' >/dev/null && pass "tier 0: refusals are ledgered with their tier" || fail "tier 0 refusals not ledgered"
# Other people's cards, switched on only for this test: a blank field, only the sheet row's exact value.
echo '{"gh_tier0_others_cards": true}' > "$T/cos/handbook/standing-approvals.json"; mkdir -p "$T/cos/outbox/o1" "$T/cos/outbox/o2"
mkcard 802 nicholas '["nicholas"]' 1 '[{"name":"Defining","field":{"name":"Status","id":"F_STATUS"}}]'
echo '{"tab":"Data Roadmap","row":12,"row_name":"Label facts","read_at":"2026-11-14T10:00","J":"#802 food-enrichment#220","C":"Relevance","I":"Nutrients · N1 NFP15 coverage","rows_naming_card":[12]}' > "$T/row.json"
echo '{"tab":"Data Roadmap","row":12,"row_name":"Label facts","read_at":"2026-11-14T10:00","J":"#802","C":"Relevance","I":"x","rows_naming_card":[12,19]}' > "$T/row2.json"
t0ref o0d 65 field data-org#802 Theme "Relevance" --row "$T/row2.json"
t0ref o0 65 field data-org#802 Theme "Quarantine" --row "$T/row.json"
t0ref o0b 65 field data-org#802 Target 2026-12-31 --row "$T/row.json"
t0ref o0c 65 board-add data-org#802 Discovery
gx o1 field data-org#802 Theme "Relevance" --row "$T/row.json" >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && t0rows -e 'any(.[]; .job=="o1" and (.evidence|test("Data Roadmap row 12")))' >/dev/null && pass "others' cards (when on): a blank field takes the row's exact value, citing the row" || fail "others' blank-field fill (rc $rc)"
t0ref o2 65 field data-org#802 Theme "Other" --row "$T/row.json"
rm -f "$T/cos/handbook/standing-approvals.json"
t0ref o3 65 field data-org#802 "Pillar metric" "Nutrients · N1 NFP15 coverage" --row "$T/row.json"
gx brief today 2>/dev/null | grep -q '^Done without asking today' && pass "tier 0: today's rows read as 'Done without asking'" || fail "tier 0 today"
# Plain words for a staged batch, and the preview the Chief shows before a yes.
mkdir -p "$T/cos/outbox/pv1"; printf 'make ragb CARD=712 TO=GREEN\ngh pr merge 720 --repo wisecodeai/data-org --squash\n' > "$T/cos/outbox/pv1/apply.sh"
PV="$(HOME="$T" "$T/cos/bin/cos-run" preview pv1 2>/dev/null)"
jq -e --arg s "$(shasum -a 256 "$T/cos/outbox/pv1/apply.sh" | cut -d' ' -f1)" '.preview.github.highest_tier == 2 and (.preview.github.items[0].says | test("RAGB on #712 to GREEN")) and .preview.github.on_yes == ("cos-run apply pv1 " + $s)' <<<"$PV" >/dev/null 2>&1 \
  && pass "preview: a batch in plain words, each line's tier, and the call to run on his yes" || fail "preview ($PV)"
HOME="$T" "$T/cos/bin/cos-run" preview nothing-here >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "preview refuses a job with nothing staged" || fail "preview of nothing"
# cos-share (Nov 17): files for a colleague's branch go on a cassidy/ branch with a draft PR into theirs, only as approved.
SH="$(mktemp -d)"; mkdir -p "$SH/cos/outbox/s1" "$SH/Documents/src/cache"; echo a > "$SH/Documents/src/o.jsonl"; echo b > "$SH/Documents/src/cache/c.json"; echo pr > "$SH/cos/outbox/s1/pr.md"
CS="$(cd "$SH/Documents/src" && find o.jsonl cache -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)"
mkshare() { jq -n --arg r "$SH/Documents/src" --arg c "$CS" --arg b "$1" --arg d "$2" --arg i "$3" '{repo:"food-enrichment",base:"dgonzo/487-tier1-service",branch:$b,dest:$d,source_root:$r,items:[$i,"cache"],content_sha256:$c,title:"t",body_file:"pr.md"}' > "$SH/cos/outbox/s1/share.json"; shasum -a 256 "$SH/cos/outbox/s1/share.json" | cut -d' ' -f1; }
sh1() { HOME="$SH" "$COS/bin/cos-share" s1 "$1" >/dev/null 2>&1; echo $?; }
S="$(mkshare cassidy/487-oracle tests/fx o.jsonl)"; [[ "$(sh1 0000000000000000000000000000000000000000000000000000000000000000)" == 67 ]] && pass "cos-share refuses a share.json that isn't the approved one" || fail "cos-share ran an unapproved share.json"
S="$(mkshare dgonzo/487-tier1-service tests/fx o.jsonl)"; [[ "$(sh1 "$S")" == 65 ]] && pass "cos-share never pushes to the colleague's own branch" || fail "cos-share accepted someone else's branch"
S="$(mkshare cassidy/487-oracle ../escape o.jsonl)"; [[ "$(sh1 "$S")" == 65 ]] && pass "cos-share refuses a destination outside the repo" || fail "cos-share accepted ../"
S="$(mkshare cassidy/487-oracle tests/fx ../../.ssh/id)"; [[ "$(sh1 "$S")" == 65 ]] && pass "cos-share refuses an item outside the source folder" || fail "cos-share accepted an item outside the source"
: > "$SH/Documents/src/-delete"
S="$(mkshare cassidy/487-oracle tests/fx -delete)"; [[ "$(sh1 "$S")" == 65 && -e "$SH/Documents/src/-delete" ]] && pass "cos-share refuses an item starting with - (find would read it as an option)" || fail "cos-share accepted an item starting with -"
S="$(mkshare cassidy/487-oracle tests/fx $'o.jsonl\ncache')"; [[ "$(sh1 "$S")" == 65 ]] && pass "cos-share refuses an item with a newline in its name" || fail "cos-share accepted an item with a newline"
S="$(mkshare cassidy/487-oracle tests/fx o.jsonl)"; echo changed >> "$SH/Documents/src/o.jsonl"; [[ "$(sh1 "$S")" == 67 ]] && pass "cos-share refuses files that changed after the job checked them" || fail "cos-share pushed changed files"
# cos-run seal (Nov 17): a job can't hash a folder, so it stages content_sha256 empty and apply.pending.sh; seal finishes both.
# Seal's content_sha256 recipe is cos-share's, byte for byte (shasum -a 256 at both steps), and matches cos-share line 12.
SR="$(sed -n 's/^GOT="\$(cd "\$SRC" && \(.*\))"$/\1/p' "$KIT/claude/cos-share")"; SL="$(sed -n 's/^  CS="\$(cd "\$SRC" && \(.*\))" \\$/\1/p' "$KIT/claude/cos-run")"
[[ "$SR" == 'find "${ITEMS[@]}" -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d'"' '"' -f1' && "$SL" == "$SR" \
   && "$(sed -n 12p "$KIT/claude/cos-share")" == '#   (cd <source_root> && find <items> -type f -print0 | sort -z | xargs -0 shasum -a 256) | shasum -a 256' ]] \
  && pass "seal hashes with cos-share's recipe, byte for byte (cos-share line 12 and its check)" || fail "seal's recipe differs from cos-share's (cos-share: $SR; seal: $SL)"
J2="$SH/cos/outbox/s2"; mkdir -p "$J2" "$SH/stub"; echo pr > "$J2/pr.md"
printf '#!/bin/bash\necho "$*" >> "%s/git-called"\nexit 2\n' "$SH" > "$SH/stub/git"; chmod +x "$SH/stub/git"
seal() { HOME="$SH" "$COS/bin/cos-run" seal s2 >/dev/null 2>&1; echo $?; }
mks2() { jq -n --arg r "$SH/Documents/src" --arg i "$1" '{repo:"food-enrichment",base:"dgonzo/487-tier1-service",branch:"cassidy/487-oracle",dest:"tests/fx",source_root:$r,items:[$i,"cache"],content_sha256:"",title:"t",body_file:"pr.md"}' > "$J2/share.json"; }
printf '# NOT RUNNABLE YET\ncos-share s2 SHARE_SHA\ngh issue comment 487 --repo wisecodeai/food-enrichment --body-file %s/c.md\n' "$J2" > "$SH/pending"
[[ "$(seal)" == 66 ]] && pass "seal refuses a job without share.json" || fail "seal ran without share.json"
mks2 o.jsonl; [[ "$(seal)" == 66 ]] && pass "seal refuses a job without apply.pending.sh" || fail "seal ran without apply.pending.sh"
mks2 ../../.ssh/id; cp "$SH/pending" "$J2/apply.pending.sh"; [[ "$(seal)" == 65 && ! -e "$J2/apply.sh" ]] && pass "seal refuses an item outside the source folder, as cos-share does" || fail "seal accepted an item outside the source"
mks2 -delete; [[ "$(seal)" == 65 && ! -e "$J2/apply.sh" && -e "$SH/Documents/src/-delete" ]] && pass "seal refuses an item starting with -, as cos-share does" || fail "seal accepted an item starting with -"
mks2 $'o.jsonl\ncache'; [[ "$(seal)" == 65 && ! -e "$J2/apply.sh" ]] && pass "seal refuses an item with a newline in its name, as cos-share does" || fail "seal accepted an item with a newline"
mks2 o.jsonl; outside() { find "$SH" -type f ! -path "$J2/*" -print0 | sort -z | xargs -0 shasum -a 256; }; O1="$(outside)"
rc="$(seal)"; S="$(shasum -a 256 "$J2/share.json" | cut -d' ' -f1)"; CS="$(cd "$SH/Documents/src" && find o.jsonl cache -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)"
[[ $rc == 0 && ! -e "$J2/apply.pending.sh" && "$(jq -r .content_sha256 "$J2/share.json")" == "$CS" && "$(sed -n 2p "$J2/apply.sh")" == "cos-share s2 $S" && "$(sed -n 3p "$J2/apply.sh")" == "$(sed -n 3p "$SH/pending")" ]] \
  && pass "seal writes content_sha256, puts share.json's sha256 in apply.sh and renames it" || fail "seal (rc $rc)"
[[ "$O1" == "$(outside)" ]] && pass "seal writes nothing outside the job folder" || fail "seal wrote outside the job folder"
# Both of cos-share's sha256 checks (share.json, then the files) come before its first git call. The stub git records
# that call and fails it, so reaching ls-remote proves both passed; 66 alone could also mean a missing file.
e="$(PATH="$SH/stub:$PATH" HOME="$SH" "$COS/bin/cos-share" s2 "$S" 2>&1 >/dev/null)"; rc=$?
[[ $rc == 66 && "$e" == *"dgonzo/487-tier1-service isn't on wisecodeai/food-enrichment"* \
   && "$(cat "$SH/git-called" 2>/dev/null)" == "ls-remote --exit-code --heads https://github.com/wisecodeai/food-enrichment.git dgonzo/487-tier1-service" ]] \
  && pass "cos-share accepts a sealed share.json (both sha256 checks pass; it reached git ls-remote)" || fail "cos-share refused a sealed share.json (rc $rc: $e)"
A1="$(shasum -a 256 "$J2/apply.sh")"; [[ "$(seal)" == 0 && "$A1" == "$(shasum -a 256 "$J2/apply.sh")" && "$(shasum -a 256 "$J2/share.json" | cut -d' ' -f1)" == "$S" ]] && pass "seal run twice changes nothing" || fail "seal is not idempotent"
echo again >> "$SH/Documents/src/cache/c.json"; [[ "$(seal)" == 67 && "$A1" == "$(shasum -a 256 "$J2/apply.sh")" ]] && pass "seal refuses, and never rewrites apply.sh, when the files changed after sealing" || fail "seal after a change"
mkdir -p "$SH/cos/outbox/s3"; touch "$SH/cos/outbox/s3/apply.pending.sh"
e="$(HOME="$SH" "$COS/bin/cos-run" preview s3 2>&1 >/dev/null)"; [[ $? -eq 66 && "$e" == *"cos-run seal s3"* ]] && pass "preview of an unsealed share says to run cos-run seal" || fail "preview unsealed: $e"
rm -rf "$SH"
# The Chief learns bot text only through a paste: chief.md's seal lines must be in pending-pastes.md, word for word.
np=0; while IFS= read -r l; do grep -qxF -- "$l" "$KIT/grokbot/pending-pastes.md" && np=$((np+1)); done < <(grep -e '^  cos-run seal ' -e 'run cos-run seal <job> before' "$KIT/grokbot/chief.md")
[[ $np -eq 2 ]] && pass "pending-pastes.md carries chief.md's two cos-run seal lines" || fail "pending-pastes.md has $np of chief.md's 2 seal lines"
# --help for every lane, and refusals that print the correct call.
nh=0; for l in quick investigate atlas gh-scan draft build apply apply-sheet preview seal gh lake eval fix land note pause receipt preflight; do HOME="$T" "$T/cos/bin/cos-run" $l --help 2>/dev/null | grep -q '^Examples:' && nh=$((nh+1)); done
[[ $nh -eq 19 ]] && pass "cos-run <lane> --help has examples for all 19 lanes" || fail "--help examples on $nh of 19 lanes"
e="$(HOME="$T" "$T/cos/bin/cos-run" investigate 2>&1 >/dev/null)"; [[ $? -ne 0 && "$e" == *"Correct call:"*"cos-run investigate inv-"* ]] && pass "a call missing its job id prints the correct call" || fail "no correct call printed: $e"
e="$(HOME="$T" "$T/cos/bin/cos-run" quick q1 "x" --wiht "ls" 2>&1 >/dev/null)"; [[ "$e" == *"unknown option: --wiht"*"Correct call:"*"--with"* ]] && pass "an unknown option prints the correct call" || fail "unknown option: $e"
# The lake lane: never scheduled, Claude only, stops at once without VPN and sign-in.
COS_CALLER=sched HOME="$T" "$T/cos/bin/cos-run" lake lk1 "How many foods?" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/lk1/run.json" ]] && pass "lake refuses to run on a schedule" || fail "lake ran from the schedule"
COS_LAKE_MODEL=gpt-5 HOME="$T" "$T/cos/bin/cos-run" lake lk2 "How many foods?" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 ]] && pass "lake refuses a non-Claude model" || fail "lake accepted a non-Claude model"
printf '#!/bin/bash\necho "agent ran" >> "$HOME/agent.log"\n' > "$T/cos/bin/agent"; chmod +x "$T/cos/bin/agent"
HOME="$T" DATA_ORG_NOTEBOOK="$T/nb" "$T/cos/bin/cos-run" lake lk3 "How many foods?" --in "$T" >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 && ! -e "$T/agent.log" ]] && jq -e '.receipt.status == "waiting" and (.receipt.summary | startswith("Connect the VPN and sign in"))' "$T/cos/outbox/lk3/receipt.json" >/dev/null 2>&1 \
  && pass "lake without the notebook, VPN or sign-in stops at once: 'Connect the VPN and sign in', not a failure" || fail "lake preflight (rc $rc)"
rm -rf "$T"
# The lake lane's walls. Cursor's permission config is the first; its preToolUse hook (which runs the gate) the second.
LC="$COS/claude/lake/cli.json"
jq -e '(.permissions.deny | index("Write(**)") and index("Shell(curl)") and index("Shell(git)") and index("Shell(gh)") and index("Shell(python)") and index("Shell(uv)") and index("Shell(agent)") and index("Read(**/.env*)"))
       and (.permissions.allow | all(test("^(Read\\(|Shell\\((lake-query|ls)\\))")))' "$LC" >/dev/null 2>&1 \
  && pass "lake cli.json: denies writes, network, git, gh, python, uv, other agents and .env; allows only reads, lake-query, ls" || fail "lake cli.json is missing a deny"
lh() { local got; got="$(jq -nc --arg t "$1" --arg c "$2" --arg p "${3:-}" '{tool_name:$t, tool_input:{command:$c, file_path:$p}, workspace_roots:[]}' | COS_LEDGER_OFF=1 "$COS/claude/cursor-lake-hook" | jq -r .permission)"
  [[ "$got" == "$4" ]] && pass "lake hook · $4 · $1 ${2:-$3}" || fail "lake hook · expected $4, got $got · $1 ${2:-$3}"; }
lh Shell 'lake-query --sql "select count(*) from food where brand > 2"' "" allow
lh Shell 'lake-query --sql "select count(*) from lake.mart.foods" --lake --env dev' "" allow
lh Shell 'lake-query --sql "select name from wisecode_gold.canon_term limit 5"' "" deny
lh Shell "lake-query --sql \"select count(*) from food where brand = 'Acme' limit 5\"" "" allow
lh Shell 'curl -sI https://example.com' "" deny
lh Shell 'git push origin HEAD' "" deny
lh Shell 'gh api user' "" deny
lh Shell 'lake-query --sql "select 1 limit 1"; rm -rf ~' "" deny
lh Shell 'lake-query --sql "$(cat ~/.aws/credentials)"' "" deny
lh Shell 'bash -c "lake-query --sql x"' "" deny
lh Shell 'uv run python scripts/run_query.py q.sql' "" deny
lh Write "" "$HOME/cos/outbox/x/a.md" deny
lh Delete "" "/tmp/x" deny
lh mcp__slack__send_message "" "" deny
lh Read "" "$HOME/.aws/credentials" deny
lh Read "" "$COS/notebook-main/AGENTS.md" allow
lgate() { local got; got="$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(jq -Rn --arg c "$1" '$c')" | COS_LEDGER_OFF=1 COS_LANE="$2" COS_GATE_MODE=job "$COS/claude/gate.sh" >/dev/null 2>&1; echo $?)"
  [[ "$got" == "$3" ]] && pass "gate · lane $2 · exit $3 · $1" || fail "gate · lane $2 · expected exit $3, got $got · $1"; }
lgate 'lake-query --sql "select count(*) from food"' investigate 2
lgate 'uv run --project ~/cos/notebook-main python scripts/run_query.py q.sql' build 2
lgate 'lake-query --sql "select count(*) from food"' lake 0
lgate 'grep -n run_query scripts/x.py' investigate 0
lgate 'cos-run gh j1 label data-org#1 add x' investigate 2
lgate 'cos-run lake j1 "how many"' investigate 2
lgate 'grep -n cos-gh README.md' investigate 0
for f in investigate draft build; do jq -e '(.permissions.allow | map(select(test("lake-query"))) | length == 0) and (.permissions.deny | index("Bash(lake-query*)"))' "$COS/claude/settings.$f.json" >/dev/null 2>&1 \
  && pass "settings.$f: lake-query is denied, not allowed" || fail "settings.$f still allows lake-query"; done

echo "13. Build B: throughput, DRD and DADR flow, gh-scan per caller"
# cos-flow on a fixture board: nothing reaches GitHub. Now is 2026-11-14 18:00Z (11:00 MT).
T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"; mkdir -p "$T/cos/bin" "$T/cos/state"
cp "$COS/bin/cos-flow" "$T/cos/bin/"
python3 -I - "$T/flow.json" <<'PY'
import json, sys
def it(n, status, state="OPEN", reason=None, owner="nicholas", author=None, moves=(), comments=(), body="", archived=False, created="2026-11-01T00:00:00Z", title=None):
    return {"id": f"I{n}", "isArchived": archived, "createdAt": created, "fieldValueByName": ({"name": status} if status else None),
            "content": {"__typename": "Issue", "number": n, "title": title or f"card {n}", "url": f"https://github.com/wisecodeai/data-org/issues/{n}",
                        "state": state, "stateReason": reason, "closedAt": ("2026-11-12T00:00:00Z" if state == "CLOSED" else None), "createdAt": created,
                        "body": body, "repository": {"name": "data-org"}, "author": {"login": author or owner},
                        "assignees": {"nodes": ([{"login": owner}] if owner else [])}, "labels": {"nodes": []}, "subIssues": {"nodes": []},
                        "comments": {"nodes": [{"createdAt": c, "author": {"login": owner}, "bodyText": "A or B? Melanie decides.", "url": "u"} for c in comments]},
                        "moves": {"nodes": [{"createdAt": a, "previousStatus": f, "status": t, "project": {"number": 1}} for a, f, t in moves]},
                        "refs": {"nodes": []}}}
items = [
  it(10, "Defining", moves=[("2026-10-15T00:00:00Z", "", "Intake"), ("2026-10-25T00:00:00Z", "Intake", "Defining")]),
  it(11, "Shipping", owner="cassidythilton", moves=[("2026-11-11T00:00:00Z", "Defining", "Shipping")]),
  it(12, "Completed No Delivery", state="CLOSED", reason="COMPLETED", moves=[("2026-11-12T00:00:00Z", "Shipping", "Completed No Delivery")]),
  it(13, None, owner=None, author="cassidythilton"),
  it(14, "Discovery", state="CLOSED", reason="COMPLETED", owner="melanie"),
  it(15, "Discovery", owner="cassidythilton"),
  it(16, "Defining", owner="melanie", moves=[("2026-11-13T00:00:00Z", "Shipping", "Defining")], comments=["2026-11-14T17:00:00Z"]),
  it(17, "Defining", archived=True),
]
prs = [{"number": 900, "title": "DRD-0040 (Draft): x", "body": "Tile: #15", "isDraft": True, "author": {"login": "cassidythilton"}, "url": "https://github.com/wisecodeai/data-org/pull/900",
        "files": [{"path": "drd/DRD-0040-x.md", "additions": 9, "deletions": 0}], "reviewRequests": [], "reviews": [], "headRefName": "cassidy/15-x"},
       {"number": 901, "title": "DRD-0040 (Draft): y", "body": "Tile: #99", "isDraft": True, "author": {"login": "nicholas"}, "url": "https://github.com/wisecodeai/data-org/pull/901",
        "files": [{"path": "drd/DRD-0040-y.md", "additions": 9, "deletions": 0}], "reviewRequests": [], "reviews": [], "headRefName": "nicholas/99-y"}]
docs = [{"path": "drd/DRD-0039-z.md", "kind": "DRD", "front": {"id": "DRD-0039", "status": "Draft", "source_issue": "#10", "review_by": "2026-10-01"}}]
atlas = "cc:1  2026-11-14  claude Label facts  (wisecodeai/data-org @ cassidy/15-label-facts)\ncc:2  2026-11-13  claude old  (wisecodeai/data-org @ cassidy/99-old)"
json.dump({"now": "2026-11-14T18:00:00+00:00", "items": items, "prs": prs, "docs": docs, "atlas": atlas, "gate": "",
           "make_next_id": "  claimed by open PR #901: DRD-0040\n\n  next free: DRD-0041"}, open(sys.argv[1], "w"))
PY
fl() { COS_FLOW_FIXTURE="$T/flow.json" HOME="$T" "$T/cos/bin/cos-flow" "$@"; }
fl lanes --json | jq -e '.items == 7 and .view.Defining == 2 and .view.Discovery == 2 and .view["No Status"] == 1 and .open.Discovery == 1 and .closed["Completed No Delivery"] == 1' >/dev/null 2>&1 \
  && pass "cos-flow lanes: counts every item as the Lanes view does (open and closed, archived left out)" || fail "cos-flow lanes ($(fl lanes --json 2>&1 | jq -c .view 2>/dev/null))"
fl week --json | jq -e '.forward == 1 and .back == 1 and .finished == 1 and (.stuck_over_14_days | map(.card) | index("#10") != null and index("#11") == null)
   and .median_days_in.Shipping.n == 2' >/dev/null 2>&1 \
  && pass "cos-flow week: forward, back and finished moves from the lane history, and cards past 14 days in one lane" || fail "cos-flow week ($(fl week --json 2>&1 | jq -c '{forward,back,finished}' 2>/dev/null))"
EV="$(fl evidence --json)"
jq -e 'any(.[]; .card == "#14" and .to == "Completed No Delivery" and (.next | test("no bot moves it")))
   and any(.[]; .card == "#15" and .to == "Defining" and (.next | test("^cos-run gh <job> lane data-org#15")) and (.evidence | test("ID clash")))
   and all(.[]; .mine or ((.next | test("cos-run gh|make ")) | not))' <<<"$EV" >/dev/null 2>&1 \
  && pass "cos-flow evidence: lines for owners; a tier-0 call only on his card; never a bot move on another owner's card; ID clash named" || fail "cos-flow evidence ($EV)"
fl nostatus --json | jq -e '.open | length == 1 and .[0].card == "#13" and .[0].mine == true' >/dev/null 2>&1 && pass "cos-flow nostatus: open cards in No Status, for their owners" || fail "cos-flow nostatus"
TD="$(fl today --json)"
jq -e '(.cards | map(.card) | sort) == ["#15","#16"] and any(.cards[]; .card == "#16" and .signals[0].row == 1 and (.who_drafts | test("to-do list")))
   and any(.cards[]; .card == "#15" and (.why | test("Agent Atlas")) and .docs.has_drd == true)' <<<"$TD" >/dev/null 2>&1 \
  && pass "cos-flow today: only cards worked today (board and Agent Atlas), the card's DRD facts, PR #524's rows, owners' to-do for others" || fail "cos-flow today ($(jq -c '[.cards[] | {card,signals,who_drafts}]' <<<"$TD" 2>/dev/null))"
fl next-id DRD 0040 >/dev/null 2>&1; rc=$?
NI="$(fl next-id DRD 0040 --json 2>/dev/null)"
[[ $rc -eq 65 ]] && jq -e '.free == false and (.claimed_by | map(.pr) | sort) == [900, 901] and .make_next_id_missed[0].pr == 900 and .next_free_all_prs == "DRD-0041"' <<<"$NI" >/dev/null 2>&1 \
  && pass "cos-flow next-id refuses a number any open PR claims, and names what make next-id didn't show" || fail "cos-flow next-id DRD 0040 (rc $rc: $NI)"
fl next-id DRD 0041 >/dev/null 2>&1 && pass "cos-flow next-id passes a free number" || fail "cos-flow next-id DRD 0041"
fl next-id DRD 0039 >/dev/null 2>&1; [[ $? -eq 65 ]] && pass "cos-flow next-id refuses a number on main" || fail "cos-flow next-id passed a number on main"
fl debt --json | jq -e '.id_clashes["DRD-0040"] == [900, 901] and (.defining_no_drd | map(.card) | index("#16") != null)' >/dev/null 2>&1 \
  && pass "cos-flow debt: Defining cards with no DRD, and an ID two open PRs claim" || fail "cos-flow debt"
fl brief capture "$T/out" >/dev/null 2>&1; grep -q '^## DRD and DADR check' "$T/out/flow-capture.md" 2>/dev/null && grep -q '^## Evidence for lane moves' "$T/out/flow-capture.md" && [[ -s "$T/out/flow-today.json" ]] \
  && pass "cos-flow brief capture: the facts the 16:00 capture reads" || fail "cos-flow brief capture"
fl move data-org#16 Shipping >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-flow has no write command (an unknown command is refused)" || fail "cos-flow accepted a write-like command"
grep -q 'flow-capture.md' "$COS/claude/briefs/capture.md" && grep -q 'flow-week.md' "$COS/claude/briefs/week.md" && grep -q 'DADR candidates' "$COS/claude/briefs/followups.md" \
  && grep -q 'cos-flow brief' "$COS/bin/cos-sched" && pass "briefs: capture and week read cos-flow's facts; follow-ups list DADR candidates with timestamps" || fail "briefs don't read cos-flow's facts"
grep -q '"Bash(cos-flow week\*)"' "$COS/claude/settings.investigate.json" && ! grep -q 'cos-flow brief' "$COS/claude/settings.investigate.json" \
  && pass "investigate jobs may run cos-flow's reads (not brief, which writes files)" || fail "settings.investigate cos-flow rules"
rm -rf "$T"

# gh-scan: each caller keeps its own "since"; PRs others assigned to him are always listed. A stub stands in for gh.
T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"; mkdir -p "$T/cos/bin" "$T/cos/state"
cp "$COS/bin/cos-gh-scan" "$COS/bin/cos-run" "$COS/bin/cos-ledger" "$T/cos/bin/"
cat > "$T/cos/bin/gh" <<'STUB'
#!/bin/bash
[[ "$1 $2" == "api user" ]] && { echo '{"login":"cassidythilton"}'; exit 0; }
[[ "$*" == *review-requested* ]] && { echo '{"data":{"search":{"issueCount":0,"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[]}}}'; exit 0; }
cat "$HOME/search.json"
STUB
chmod +x "$T/cos/bin/gh"
echo '{"data":{"search":{"issueCount":1,"pageInfo":{"hasNextPage":false,"endCursor":null},"nodes":[{"__typename":"PullRequest","number":55,"title":"Gold key review","url":"https://github.com/wisecodeai/data-org/pull/55","updatedAt":"2026-11-01T00:00:00Z","isDraft":false,"reviewDecision":"REVIEW_REQUIRED","repository":{"nameWithOwner":"wisecodeai/data-org"},"author":{"login":"dgonzo"},"assignees":{"nodes":[{"login":"cassidythilton"}]},"reviewRequests":{"nodes":[]},"reviews":{"nodes":[]},"comments":{"nodes":[]},"reviewThreads":{"nodes":[]}}]}}}' > "$T/search.json"
echo '{"at": "2026-11-13T01:00:00+00:00"}' > "$T/cos/state/gh-scan-last.json"
gs() { HOME="$T" PATH="$T/cos/bin:$PATH" COS_GH_WAITS=0 "$T/cos/bin/cos-gh-scan" "$@"; }
gs "$T/o1" --state watch >/dev/null 2>&1
grep -q 'data-org#55 Gold key review. By dgonzo' "$T/o1/digest.md" 2>/dev/null && jq -e '.counts.assigned_prs == 1 and .state == "watch"' "$T/o1/scan.json" >/dev/null 2>&1 \
  && pass "gh-scan lists a PR someone else assigned to him, with no new activity" || fail "gh-scan didn't list the assigned PR"
[[ -f "$T/cos/state/gh-scan-last-watch.json" && ! -e "$T/cos/state/gh-scan-last-brief.json" ]] && grep -q '2026-11-13T01:00:00' "$T/cos/state/gh-scan-last.json" \
  && pass "gh-scan --state watch keeps its own since and leaves the brief's and the shared one alone" || fail "gh-scan --state watch touched another caller's since"
gs "$T/o2" --state brief >/dev/null 2>&1
jq -e '.since | startswith("2026-11-13T01:00:00")' "$T/o2/scan.json" >/dev/null 2>&1 \
  && pass "gh-scan --state brief: an hourly watch never moves the morning brief's since" || fail "gh-scan --state brief since ($(jq -r .since "$T/o2/scan.json" 2>/dev/null))"
gs "$T/o3" --state nightly >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "gh-scan refuses a --state other than brief or watch" || fail "gh-scan took --state nightly"
HOME="$T" "$T/cos/bin/cos-run" gh-scan gs4 --state nightly >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-run gh-scan refuses a bad --state" || fail "cos-run gh-scan took a bad --state"
HOME="$T" PATH="$T/cos/bin:$PATH" COS_GH_WAITS=0 "$T/cos/bin/cos-run" gh-scan gs5 --state watch >/dev/null 2>&1
jq -e '.receipt.status == "done"' "$T/cos/outbox/gs5/receipt.json" >/dev/null 2>&1 && pass "cos-run gh-scan <job> --state watch runs" || fail "cos-run gh-scan --state watch"
HOME="$T" "$T/cos/bin/cos-run" quick qf1 "x" --with "cos-flow week; rm -rf ~" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 ]] && pass "quick refuses: cos-flow with anything after it" || fail "quick ran cos-flow with a chained command"
HOME="$T" "$T/cos/bin/cos-run" quick qf2 "x" --with "cos-flow brief week /tmp/x" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 ]] && pass "quick refuses: cos-flow brief (it writes files)" || fail "quick ran cos-flow brief"
rm -rf "$T"

# Tier 0 for DRD and DADR drafts, and a Cowork handoff. Stubs stand in for gh, git's ls-remote, make and cos-push-draft.
T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"; mkdir -p "$T/cos/bin" "$T/cos/data-org-main" "$T/cards" "$T/cos/handbook" "$T/cos/outbox"
cp "$COS/bin/cos-ledger" "$COS/bin/cos-gh" "$COS/bin/cos-run" "$COS/bin/cos-flow" "$T/cos/bin/"
cat > "$T/cos/bin/gh" <<'STUB'
#!/bin/bash
a="$*"; echo "gh ${a//$'\n'/ }" >> "$HOME/gh.log"
[[ "$1 $2" == "api user" ]] && { echo "cassidythilton"; exit 0; }
[[ "$1" == api && "$2" == repos/*/compare/* ]] && { cat "$HOME/compare.txt" 2>/dev/null; exit 0; }
if [[ "$1 $2" == "api graphql" ]]; then r=""; n=""; for x in "$@"; do case "$x" in r=*) r="${x#r=}";; n=*) n="${x#n=}";; esac; done
  [[ "$*" == *mutation* ]] && exit 0; cat "$HOME/cards/$r-$n.json"; exit 0; fi
if [[ "$1 $2" == "issue edit" ]]; then f="$HOME/cards/${5#wisecodeai/}-$3.json"
  [[ "$6" == --add-label ]] && jq --arg v "$7" '.data.repository.issueOrPullRequest.labels.nodes += [{name:$v}]' "$f" > "$f.t" && mv "$f.t" "$f"; exit 0; fi
[[ "$1 $2" == "pr list" ]] && { echo '[]'; exit 0; }
[[ "$1 $2" == "pr create" ]] && { echo "https://github.com/wisecodeai/data-org/pull/999"; exit 0; }
exit 0
STUB
printf '#!/bin/bash\nif [[ "$1" == ls-remote ]]; then for b in $(cat "$HOME/heads" 2>/dev/null); do [[ "$*" == *" $b" ]] && echo "abc refs/heads/$b"; done; exit 0; fi\nexec /usr/bin/git "$@"\n' > "$T/cos/bin/git"
printf '#!/bin/bash\necho "make ${DRY_RUN:+DRY_RUN=1 }$*" >> "$HOME/make.log"\n' > "$T/cos/bin/make"
printf '#!/bin/bash\necho "$*" >> "$HOME/push.log"\n' > "$T/cos/bin/cos-push-draft"
chmod +x "$T/cos/bin/"{gh,git,make,cos-push-draft,cos-gh,cos-ledger,cos-run,cos-flow}
for c in 712:cassidythilton 800:nicholas; do n="${c%%:*}"; o="${c#*:}"
  jq -n --argjson n "$n" --arg o "$o" '{data:{repository:{issueOrPullRequest:{__typename:"Issue", id:"I_\($n)", number:$n, title:"card \($n)", state:"OPEN",
    url:"https://github.com/wisecodeai/data-org/issues/\($n)", author:{login:$o}, assignees:{nodes:[{login:$o}]}, labels:{nodes:[]}, milestone:null, parent:null,
    subIssues:{nodes:[]}, blockedBy:{nodes:[]}, projectItems:{nodes:[{id:"PVTI_\($n)", project:{number:1, id:"PVT_1"}, fieldValues:{nodes:[{name:"Discovery", field:{name:"Status", id:"F_STATUS"}}]}}]}}}}}' > "$T/cards/data-org-$n.json"; done
echo '{"now":"2026-11-14T18:00:00+00:00","items":[],"docs":[{"path":"drd/DRD-0039-z.md","kind":"DRD","front":{"id":"DRD-0039"}}],"prs":[{"number":901,"title":"t","body":"","url":"https://github.com/wisecodeai/data-org/pull/901","headRefName":"nicholas/9-y","files":[{"path":"drd/DRD-0040-y.md"}]}]}' > "$T/flow.json"
mkdraft() {  # mkdraft <job> <card> <new doc path> [status] [checker verdict] [extra doc path]
  local d="$T/cos/outbox/$1"; mkdir -p "$d"
  { printf -- '--- /dev/null\n+++ b/%s\n@@ -0,0 +1,3 @@\n+---\n+status: %s\n+---\n' "$3" "${4:-Draft}"; [[ -n "${6:-}" ]] && printf -- '--- /dev/null\n+++ b/%s\n@@ -0,0 +1 @@\n+x\n' "$6"; } > "$d/draft.diff"
  jq -n --arg c "$2" --arg s "$(shasum -a 256 "$d/draft.diff" | cut -d' ' -f1)" --arg v "${5:-pass}" \
    '{receipt:{status:"done"}, checker:{verdict:$v}, draft:{base:"origin/main", base_sha:"0000000", sha256:$s, doc:{kind:"drd", card:$c}}}' > "$d/receipt.json"; }
gx() { COS_FLOW_FIXTURE="$T/flow.json" HOME="$T" PATH="$T/cos/bin:$PATH" "$T/cos/bin/cos-run" gh "$@"; }
gx w1 whose data-org#712 2>/dev/null | jq -e '.mine == true' >/dev/null && gx w2 whose data-org#800 2>/dev/null | jq -e '.mine == false and .owner == "nicholas"' >/dev/null \
  && pass "cos-run gh whose: reads who owns a card, writes nothing" || fail "cos-run gh whose"
mkdraft drd1 data-org#712 drd/DRD-0041-label-facts.md
gx pd1 push drd1 --branch cassidy/712-label-facts >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && grep -q "^drd1 [0-9a-f]\{64\} cassidy/712-label-facts$" "$T/push.log" 2>/dev/null && jq -s -e 'any(.[]; .job == "pd1" and .decision == "done" and (.evidence | test("DRD-0041 free")))' "$T/cos/state/ledger/tier_zero.jsonl" >/dev/null 2>&1 \
  && pass "tier 0: a DRD draft goes to a new cassidy/<issue>-<topic> branch after its ID is re-checked free, ledgered" || fail "tier 0 doc push (rc $rc)"
dpref() { local want="$1"; shift; local n0; n0="$(wc -l < "$T/push.log" 2>/dev/null || echo 0)"
  gx "$@" >/dev/null 2>"$T/err"; local rc=$?
  [[ $rc -eq $want && "$(wc -l < "$T/push.log" 2>/dev/null || echo 0)" == "$n0" ]] && pass "tier 0 refuses: $* ($(head -c 100 "$T/err"))" || fail "tier 0 didn't refuse (rc $rc): $*"; }
mkdraft drd2 data-org#712 drd/DRD-0040-taken.md;           dpref 65 pd2 push drd2 --branch cassidy/712-taken
echo "cassidy/712-exists" > "$T/heads"; mkdraft drd3 data-org#712 drd/DRD-0041-a.md; dpref 65 pd3 push drd3 --branch cassidy/712-exists
dpref 64 pd4 push drd3 --branch cassidy/label-facts
mkdraft drd5 data-org#800 drd/DRD-0041-b.md;               dpref 65 pd5 push drd5 --branch cassidy/800-b
mkdraft drd6 data-org#712 drd/DRD-0041-c.md Approved;      dpref 65 pd6 push drd6 --branch cassidy/712-c
mkdraft drd7 data-org#712 drd/DRD-0041-d.md Draft fail;    dpref 65 pd7 push drd7 --branch cassidy/712-d
mkdraft drd8 data-org#712 drd/DRD-0041-e.md Draft pass dadr/DADR-0060-e.md; dpref 65 pd8 push drd8 --branch cassidy/712-e
mkdir -p "$T/cos/outbox/nd1"; echo '{"receipt":{"status":"done"},"checker":{"verdict":"pass"},"draft":{"base":"origin/main","sha256":"x"}}' > "$T/cos/outbox/nd1/receipt.json"
dpref 64 pd9 push nd1 --branch cassidy/712-x
# A draft PR for a doc: the ID in the title, Closes for a DRD, Refs for a DADR, the ID still free.
echo "cassidy/712-label-facts" > "$T/heads"; echo "drd/DRD-0041-label-facts.md" > "$T/compare.txt"
for j in dp1 dp2 dp3 dp4 dp5; do mkdir -p "$T/cos/outbox/$j"; done
printf 'A merge registers a document.\nTile: #712\nCloses #713\n' > "$T/cos/outbox/dp1/b.md"; cp "$T/cos/outbox/dp1/b.md" "$T/cos/outbox/dp2/b.md"; cp "$T/cos/outbox/dp1/b.md" "$T/cos/outbox/dp3/b.md"; cp "$T/cos/outbox/dp1/b.md" "$T/cos/outbox/dp5/b.md"
printf 'Tile: #712\nCloses #712\n' > "$T/cos/outbox/dp4/b.md"
prref() { local want="$1"; shift; local n0; n0="$(grep -c 'pr create' "$T/gh.log" 2>/dev/null)"
  gx "$@" >/dev/null 2>"$T/err"; local rc=$?
  [[ $rc -eq $want && "$(grep -c 'pr create' "$T/gh.log" 2>/dev/null)" == "$n0" ]] && pass "tier 0 refuses a draft PR: ${3:-} ${5:-} ($(head -c 90 "$T/err"))" || fail "draft PR not refused (rc $rc): $*"; }
prref 64 dp2 draft-pr data-org cassidy/712-label-facts --title "Label facts" --body-file "$T/cos/outbox/dp2/b.md"
prref 64 dp3 draft-pr data-org cassidy/712-label-facts --title "DRD-0041 Label facts" --body-file "$T/cos/outbox/dp3/b.md"
prref 64 dp4 draft-pr data-org cassidy/712-label-facts --title "DADR-0061 (Draft): Choose" --body-file "$T/cos/outbox/dp4/b.md"
prref 65 dp5 draft-pr data-org cassidy/712-label-facts --title "DRD-0040 (Draft): Label facts" --body-file "$T/cos/outbox/dp5/b.md"
gx dp1 draft-pr data-org cassidy/712-label-facts --title "DRD-0041 (Draft): Label facts" --body-file "$T/cos/outbox/dp1/b.md" >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && grep -q 'pr create --draft --repo wisecodeai/data-org --head cassidy/712-label-facts --title DRD-0041 (Draft): Label facts' "$T/gh.log" \
  && pass "tier 0: a DRD draft PR opens with the ID in its title, after the ID is re-checked" || fail "tier 0 doc draft PR (rc $rc)"
# A Cowork handoff block: tier-0 lines run, the rest are refused by tier, previews and reads skipped.
mkdir -p "$T/cos/outbox/hoin"; cat > "$T/cos/outbox/hoin/block.sh" <<'HO'
# Ship DRD-0041 (from Cowork's handoff skill)
DRY_RUN=1 make set-pillar CARD=712 TO=Defining
make set-pillar CARD=712 TO=Defining
gh issue edit 712 --repo wisecodeai/data-org --add-label type/drd
make ragb CARD=712 TO=GREEN
make promote CARD=712 TO=Shipping
git push -u origin cassidy/712-label-facts
gh pr merge 5 --repo wisecodeai/data-org --squash
make set-pillar CARD=800 TO=Defining
echo hi; rm -rf ~
sed -i '' 's/status: Draft/status: Approved/' drd/DRD-0041-label-facts.md
gh pr create --title "DRD-0041: Label facts" --body "$(cat <<'EOF'
A merge registers a document.
Tile: #712
EOF
)"
make next-id KIND=DRD   # confirm 0041 is still free before pushing
HO
gx ho1 handoff "$T/cos/outbox/hoin/block.sh" >/dev/null 2>&1; rc=$?
HR="$T/cos/outbox/ho1/receipt.json"
[[ $rc -eq 0 ]] && jq -e '([.handoff[] | select(.result == "ran")] | length) == 1 and ([.handoff[] | select(.result == "skipped")] | length) == 2
   and any(.handoff[]; .result == "refused" and .tier == 1 and (.line | test("ragb")))
   and any(.handoff[]; .result == "refused" and .tier == 2 and (.line | test("promote")))
   and any(.handoff[]; .result == "refused" and .tier == 2 and (.line | test("CARD=800")))
   and any(.handoff[]; .result == "refused" and .tier == 2 and (.line | test("merge")))
   and any(.handoff[]; .result == "refused" and .tier == 0 and (.line | test("^git push")))
   and any(.handoff[]; .result == "refused" and .tier == "never" and (.line | test("Approved")))
   and any(.handoff[]; .result == "refused" and .tier == 1 and (.line | test("pr create")))
   and any(.handoff[]; .result == "refused" and (.line | test("rm -rf")))' "$HR" >/dev/null 2>&1 \
  && grep -q 'issue edit 712 --repo wisecodeai/data-org --add-label type/drd' "$T/gh.log" && ! grep -qE '^make -s (ragb|promote)|CARD=800' "$T/make.log" 2>/dev/null && ! grep -q 'pr merge' "$T/gh.log" \
  && pass "handoff: a Cowork block's tier-0 line runs; ragb, promote, merge, others' cards, git, a status flip and chained commands are refused by tier" \
  || fail "handoff (rc $rc: $(jq -c '[.handoff[] | {r:.result,t:.tier,l:(.line|.[0:30])}]' "$HR" 2>/dev/null))"
jq -s -e '[.[] | select(.decision == "refused" and (.action | startswith("handoff:")))] | length >= 6' "$T/cos/state/ledger/tier_zero.jsonl" >/dev/null 2>&1 \
  && pass "handoff: each refused line is ledgered with its tier" || fail "handoff refusals not ledgered"
gx ho2 handoff /etc/hosts >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "handoff refuses a block outside ~/cos/outbox" || fail "handoff read a file outside the outbox"
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
    case "$days" in *-*) dl="$(seq "${days%-*}" "${days#*-}")";; *) dl="$(echo "$days" | tr ',' ' ')";; esac
    entries=""; for t in $(echo "$hm" | tr ',' ' '); do H=$((10#${t%:*})); M=$((10#${t#*:}))
      for d in $dl; do entries+="<dict><key>Weekday</key><integer>$d</integer><key>Hour</key><integer>$H</integer><key>Minute</key><integer>$M</integer></dict>"; done; done
    P="$LA/com.cos.$slot.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.$slot</string>
<key>ProgramArguments</key><array><string>$COS/bin/cos-launch</string><string>cos-sched</string><string>$slot</string></array>
<key>StartCalendarInterval</key><array>$entries</array>
<key>StandardOutPath</key><string>$COS/state/launchd-$slot.log</string>
<key>StandardErrorPath</key><string>$COS/state/launchd-$slot.log</string>
</dict></plist>
PL
    plutil -lint "$P" >/dev/null && launchctl bootout "gui/$(id -u)/com.cos.$slot" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null \
      && echo "  ✓ scheduled $slot ($days $hm)" || echo "  ✗ could not load $slot"
  done
  # Prove a launchd job can read ~/Documents: a one-shot agent runs cos-tcc-check through cos-launch.
  P="$LA/com.cos.tcccheck.plist"
  cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.tcccheck</string>
<key>ProgramArguments</key><array><string>$COS/bin/cos-launch</string><string>cos-tcc-check</string></array>
<key>EnvironmentVariables</key><dict><key>COS_TCC_CALLER</key><string>launchd</string></dict>
<key>RunAtLoad</key><true/>
</dict></plist>
PL
  before="$(wc -l 2>/dev/null < "$COS/state/tcc-check.log" || echo 0)"
  launchctl bootout "gui/$(id -u)/com.cos.tcccheck" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do [[ "$(wc -l 2>/dev/null < "$COS/state/tcc-check.log" || echo 0)" -gt "$before" ]] && break; sleep 0.5; done
  launchctl bootout "gui/$(id -u)/com.cos.tcccheck" 2>/dev/null; rm -f "$P"
  last="$(tail -1 "$COS/state/tcc-check.log" 2>/dev/null)"
  [[ "$last" == *"caller=launchd documents_zoom=yes"* ]] && pass "a launchd job can read ~/Documents (through cos-launch)" \
    || fail "a launchd job still can't read ~/Documents: give ~/cos/bin/cos-launch Full Disk Access (INSTALL.md), then ./install.sh --schedule"
  if [[ ",${ONLY}," == *",zoommirror,"* ]]; then
    P="$LA/com.cos.zoommirror.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.zoommirror</string>
<key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-g</string><string>$COS/bin/ZoomMirror.app</string></array>
<key>WatchPaths</key><array><string>$HOME/Documents/Zoom</string><string>$HOME/Documents/Data-Org-Repos/data-org-agent-handoff.md</string></array>
<key>StartCalendarInterval</key><array><dict><key>Hour</key><integer>11</integer><key>Minute</key><integer>30</integer></dict><dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>30</integer></dict></array>
<key>RunAtLoad</key><true/>
<key>StandardOutPath</key><string>$COS/state/launchd-zoommirror.log</string>
<key>StandardErrorPath</key><string>$COS/state/launchd-zoommirror.log</string>
</dict></plist>
PL
    plutil -lint "$P" >/dev/null && launchctl bootout "gui/$(id -u)/com.cos.zoommirror" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>/dev/null \
      && echo "  ✓ scheduled zoommirror (on change in ~/Documents/Zoom, plus 11:30 and 13:30)" || echo "  ✗ could not load zoommirror"
  fi
  if [[ ",${ONLY}," == *",dashboard,"* ]]; then
    P="$LA/com.cos.dashboard.plist"
    cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.cos.dashboard</string>
<key>ProgramArguments</key><array><string>$COS/bin/cos-launch</string><string>cos-db</string><string>load</string></array>
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
  d. Grok: Chief, OPS, STEWARD (week 1); BUILDER when you pick the first build; KEEPER after two weeks.
  e. ./install.sh --schedule once the Bots' webhook keys are in the Keychain.
EOF
