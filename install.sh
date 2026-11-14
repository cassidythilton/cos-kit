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
mkdir -p "$COS"/{bin,claude/briefs,claude/lake,handbook,outbox,state,archive,evals/runs} "$HOME/builds"
install -m 755 "$KIT"/claude/{cos-run,cos-gh,cos-sched,cos-push,cos-push-draft,cos-obligations,cos-link,cos-sandbox-test,cos-tcc-check,cos-gh-scan,cos-atlas,board-pulse,lake-query,cos-ledger,cos-db,cos-dash} "$COS/bin/"
# Old hand-made copies (cos-run.bak-20261110*) go to the archive, never deleted (plan 2026-11-14, item 6: subtract).
for b in "$COS"/bin/*.bak*; do [[ -e "$b" ]] || continue; mkdir -p "$COS/archive/bin-bak"; mv -f "$b" "$COS/archive/bin-bak/"; done
bash -n "$KIT/claude/gate.sh" || { echo "install.sh: claude/gate.sh has a syntax error; the live gate was left as it was." >&2; exit 1; }
install -m 755 "$KIT/claude/gate.sh" "$COS/claude/"
bash -n "$KIT/claude/cursor-lake-hook" && install -m 755 "$KIT/claude/cursor-lake-hook" "$COS/claude/" || fail "claude/cursor-lake-hook has a syntax error; the installed hook was left as it was"
install -m 644 "$KIT/claude/lake/cli.json" "$COS/claude/lake/"
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
for s in "$COS"/bin/* "$COS/claude/gate.sh" "$COS/claude/cursor-lake-hook" "$COS/builds-template/verify"; do
  [[ -d "$s" || "$(basename "$s")" == cos-launch ]] && continue; if head -1 "$s" | grep -q python; then python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$s" && pass "$(basename "$s")" || fail "$(basename "$s") syntax"
  else bash -n "$s" && pass "$(basename "$s")" || fail "$(basename "$s") syntax"; fi; done
for j in "$COS"/claude/*.json "$COS/claude/lake/cli.json" "$COS"/evals/*.json "$COS/builds-template/.claude/settings.json"; do jq empty "$j" 2>/dev/null && pass "$(basename "$j")" || fail "$(basename "$j") is not valid JSON"; done
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
chk "aws s3 sync . s3://b" pair block
chk 'psql "host=prod" -c "delete from food"' pair block
chk "select name from wisecode_gold.canon_term" pair block
chk "select count(*) from wisecode_gold.canon_term group by 1" pair allow
chk "cat .env" pair block
chk "EXECUTE=1 make intake-sweep" job block
chk "DRY_RUN=1 make ragb CARD=1 TO=RED" job allow
chk "cos-push steward pulse r.json" pair block
chk "cos-link sub wisecodeai/data-org#1 wisecodeai/data-org#2" job block
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
AP
S5="$(shasum -a 256 "$T/cos/outbox/t5/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t5 "$S5" --in "$T" >/dev/null 2>&1; [[ "$(grep -c '^\$ gh' "$T/cos/outbox/t5/applied.log" 2>/dev/null)" == 6 ]] \
  && pass "apply runs approved PR reviews, comments, a merge, an issue edit and a review request" || fail "apply refused an approved PR write"
mkdir -p "$T/cos/outbox/t7"; echo 'gh pr edit 720 --repo wisecodeai/data-org --add-reviewer x;rm' > "$T/cos/outbox/t7/apply.sh"; S7="$(shasum -a 256 "$T/cos/outbox/t7/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t7 "$S7" --in "$T" >/dev/null 2>&1; [[ $? -eq 65 && ! -e "$T/cos/outbox/t7/applied.log" ]] && pass "apply refuses a review request with anything after the logins" || fail "apply ran a bad review request"
mkdir -p "$T/cos/outbox/t6"; echo 'gh pr review 746 --repo wisecodeai/data-org --approve --body "looks good"' > "$T/cos/outbox/t6/apply.sh"; S6="$(shasum -a 256 "$T/cos/outbox/t6/apply.sh" | cut -d' ' -f1)"
HOME="$T" "$COS/bin/cos-run" apply t6 "$S6" --in "$T" >/dev/null 2>&1; [[ $? -ne 0 && ! -e "$T/cos/outbox/t6/applied.log" ]] && pass "apply refuses a review body that isn't a file in the job folder" || fail "apply ran an inline review body"
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
HOME="$T" "$COS/bin/cos-run" atlas at1 "the dashboard chat" --in "$T" >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "atlas refuses when it can't read Agent Atlas" || fail "atlas ran without Agent Atlas"
HOME="$T" "$COS/bin/cos-atlas" find x >/dev/null 2>&1; [[ $? -eq 66 ]] && pass "cos-atlas refuses when Agent Atlas isn't there" || fail "cos-atlas ran without Agent Atlas"
"$COS/bin/cos-atlas" sql 'x' >/dev/null 2>&1; [[ $? -eq 64 ]] && pass "cos-atlas takes only find|show|search|messages|recent" || fail "cos-atlas took another command"
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
echo '{"tab":"Data Roadmap","row":12,"row_name":"Label facts","read_at":"2026-11-14T10:00","J":"#802 food-enrichment#220","C":"Relevance","I":"Nutrients · N1 NFP15 coverage"}' > "$T/row.json"
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
# --help for every lane, and refusals that print the correct call.
nh=0; for l in quick investigate atlas gh-scan draft build apply apply-sheet preview gh lake eval fix land note pause receipt; do HOME="$T" "$T/cos/bin/cos-run" $l --help 2>/dev/null | grep -q '^Examples:' && nh=$((nh+1)); done
[[ $nh -eq 17 ]] && pass "cos-run <lane> --help has examples for all 17 lanes" || fail "--help examples on $nh of 17 lanes"
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
