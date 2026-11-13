#!/bin/bash
# PreToolUse hook: the wall behind the permission rules. Used by every cos-run job and every build workspace.
#
# Two classes of action:
#   HARD     never, in any mode: secrets, production data writes, infrastructure changes, publishing packages,
#            canon values entering the model's context.
#   OUTWARD  leaves the Mac or changes shared state: push, PR/issue/board writes, connector writes, outbound HTTP,
#            deletes. Blocked in headless jobs (staged in the receipt instead). In pair mode (Cassidy at the keyboard,
#            COS_GATE_MODE=pair) it becomes "ask": Claude must get his yes in the session.
#
# Exit 2 blocks; stderr goes back to Claude. An "ask" is JSON on stdout with exit 0.
input="$(cat)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"
cmd="$(printf '%s' "$input"  | jq -r '.tool_input.command // ""')"
path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')"
MODE="${COS_GATE_MODE:-job}"

# Logging is best-effort and never decides. COS_LEDGER_OFF=1 skips it for the timing check.
# Sourced, not executed: a second bash put the gate about 23 ms slower, over the 20 ms budget.
gate_log() {
  [[ "${COS_LEDGER_OFF:-}" == 1 ]] && return 0
  if ! declare -F cos_ledger_append >/dev/null 2>&1; then
    . "$HOME/cos/bin/cos-ledger" 2>/dev/null || return 0
  fi
  cos_ledger_append gate decision="$1" rule="$2" tool="$tool" job="${COS_JOB:-}" lane="${COS_LANE:-}" mode="$MODE" cmd="${cmd:0:300}" path="${path:0:300}" >/dev/null 2>&1 || true
}
hard() {
  gate_log block "$1"
  echo "BLOCKED (hard wall): $1. This is never done by an agent. Hand it to its owner with the exact command and why." >&2
  exit 2
}
outward() {
  if [[ "$MODE" == "pair" ]]; then
    gate_log ask "$1"
    jq -n --arg r "Outward action: $1. Confirm with Cassidy before running." \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
    exit 0
  fi
  gate_log block "$1"
  echo "BLOCKED by chief-of-staff gate: $1. Stage it in receipt.needs_approval instead." >&2
  exit 2
}

# ---- HARD: secrets
secret_re='(\.env($|\.)|credentials|\.aws/|\.ssh/|id_rsa|\.netrc|\.npmrc|\.pypirc|keychain|secrets?\.(json|ya?ml)|\.pem$|\.p12$)'
if [[ "$path" =~ $secret_re ]] || [[ "$cmd" =~ $secret_re ]]; then hard "secret material"; fi
if [[ "$cmd" =~ (security[[:space:]]+find-|printenv|(^|[;&|[:space:]])env([[:space:]]|$)|aws[[:space:]]+configure[[:space:]]+(get|export)|secretsmanager[[:space:]]+get-secret-value|ssm[[:space:]]+get-parameter.*--with-decryption) ]]; then hard "credential or environment dump"; fi

# >>> fix-lane confinement (a fix job can't change this block; cos-run land refuses a diff that does)
# Fix mode (cos-run fix): Claude edits only its own copy of the kit under ~/cos/fixes/<job>, never its .git, plus
# notes in its job folder. Everything else (installed controls, the schedule, the Keychain, pushes) stays blocked below.
if [[ "$MODE" == fix && "$tool" =~ ^(Edit|Write|MultiEdit|NotebookEdit)$ ]]; then
  rp="$(/usr/bin/python3 -I -c 'import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))' "$path" 2>/dev/null)"
  fd="${COS_FIX_DIR:-/nonexistent}"; fo="${COS_FIX_OUT:-/nonexistent}"
  if [[ -n "$rp" && ( "$rp" == "$fd/"* || "$rp" == "$fo/"* ) && "$rp" != *"/.git/"* && "$rp" != *"/.git" ]]; then gate_log allow "fix-copy write"; exit 0; fi
  hard "a fix job writes only in its own kit copy, $fd ($path)"
fi
if [[ "$MODE" == fix && "$tool" == Bash && "$cmd" =~ (^|[;&|[:space:]/])(install\.sh|sandbox-exec|git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(commit|push|merge|reset|checkout|worktree|config))([[:space:]]|$) ]]; then
  hard "in a fix job, cos-run commits and tests; run cos-sandbox-test <your copy> to test"
fi
# <<< fix-lane confinement

# ---- HARD: the system's own controls. No agent edits its walls, its schedule, a skill, or the webhook path to a bot.
#      Changes to these come from KEEPER as proposals and are applied by Cassidy.
ctl_re='(/cos/(bin|claude|kit|handbook)(/|[[:space:]]|$)|\.claude/(skills|settings)|LaunchAgents)'
if [[ "$tool" =~ ^(Edit|Write|MultiEdit|NotebookEdit)$ ]] && [[ "$path" =~ $ctl_re ]]; then hard "editing the system's own controls ($path)"; fi
if [[ "$tool" == "Bash" ]]; then
  [[ "$cmd" =~ (^|[;&|[:space:]/])(launchctl|cos-push|cos-push-draft|cos-sched|cos-obligations|cos-link)([[:space:]]|$) ]] && hard "the schedule or the webhook path to a bot"
  [[ "$cmd" =~ (^|[;&|[:space:]/])cos-run[[:space:]]+(apply|apply-sheet|land)([[:space:]]|$) ]] && hard "running an approved batch or landing a fix: only the Chief, after Cassidy's yes"
  # Writes into a control path only: a redirect or tee into it, an in-place edit of it, a copy or move onto it, or git in it.
  C='[^[:space:];&|]*/cos/(bin|claude|kit|handbook)(/|[[:space:]]|$)|[^[:space:];&|]*\.claude/(skills|settings)|[^[:space:];&|]*LaunchAgents'
  w1=">>?[[:space:]]*[\"']?($C)"; w2="tee[[:space:]]+(-a[[:space:]]+)?[\"']?($C)"; w3="(sed|perl)[[:space:]]+-[a-zA-Z]*i[^;&|]*($C)"
  w5="git[[:space:]]+-C[[:space:]]+[\"']?($C)[^;&|]*(commit|apply|am|checkout|reset|add|rm|mv|restore|stash|merge|rebase|revert|cherry-pick)"
  w6="cd[[:space:]]+[\"']?($C)[^;&|]*(&&|;)[[:space:]]*git[[:space:]]+(commit|apply|am|checkout|reset|add|rm|mv|restore|stash|merge|rebase|revert)"
  # cp, mv, install, ln, rsync, chmod: only the destination (the last argument of that command) counts.
  while IFS= read -r seg; do
    [[ "$seg" =~ ^[[:space:]]*(sudo[[:space:]]+)?(cp|mv|install|ln|rsync|chmod)[[:space:]] ]] || continue
    last="$(printf '%s' "$seg" | awk '{print $NF}' | tr -d "\"'")"
    [[ "$last " =~ ^($C) ]] && hard "changing the system's own controls"
  done < <(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n')
  for w in "$w1" "$w2" "$w3" "$w5" "$w6"; do [[ "$cmd" =~ $w ]] && hard "changing the system's own controls"; done
fi

# ---- HARD: data-org context/ is a published snapshot the CDO's private repo owns. Cite it, never edit it.
dctx_re='(Data-Org-Repos/data-org/(\.worktrees/[^/]+/)?context/|cos/repos/data-org/(\.worktrees/[^/]+/)?context/|cos/data-org-main/context/)'
if [[ "$tool" =~ ^(Edit|Write|MultiEdit)$ ]] && [[ "$path" =~ $dctx_re ]]; then hard "editing data-org context/ (read-only; file a context-request)"; fi

# ---- Sheet mode (cos-run apply-sheet): only the exact cells and values Cassidy approved, by the batch's sha256.
if [[ "$MODE" == sheet ]]; then
  case "$tool" in
    *Google_Sheets__get_values) exit 0 ;;
    *Google_Sheets__update_values)
      rng="$(printf '%s' "$input" | jq -r '.tool_input.range // ""')"; sid="$(printf '%s' "$input" | jq -r '.tool_input.spreadsheetId // ""')"
      vals="$(printf '%s' "$input" | jq -c '.tool_input.values // null')"
      if [[ -f "${COS_SHEET_BATCH:-}" ]] && jq -e --arg r "$rng" --arg s "$sid" --argjson v "$vals" \
          '.spreadsheet == $s and any(.writes[]; ($r == ("\u0027" + .tab + "\u0027!" + .col + (.row|tostring)) or $r == (.tab + "!" + .col + (.row|tostring))) and $v == [[.new]])' \
          "$COS_SHEET_BATCH" >/dev/null 2>&1; then gate_log allow "approved sheet cell"; exit 0; fi
      hard "a sheet write that is not in the approved batch ($rng)" ;;
    *) hard "sheet mode allows only reading and writing the approved cells" ;;
  esac
fi

# ---- Connectors: read verbs only
if [[ "$tool" == mcp__* ]]; then
  if [[ "$tool" =~ __(.*_)?(update|append|clear|insert|create|delete|send|copy|share|trash|batch|schedule|add|upload|complete|move|rename|use_figma|draft|reply|post|edit|write) ]]; then
    outward "connector write ($tool)"
  fi
  exit 0
fi

[[ "$tool" == "Bash" ]] || exit 0

# ---- Previews are always fine: the repo's scripts print the gh calls instead of running them.
preview_re='^DRY_RUN=1[[:space:]]+make[[:space:]]+(ragb|field|set-pillar|complete|promote|board-add|ship-link)([[:space:]]+[A-Z_]+=("[^"`$;&|]*"|[^[:space:];&|`$"]+))*$'
if [[ "$cmd" =~ $preview_re ]] && [[ ! "$cmd" =~ EXECUTE ]]; then exit 0; fi

lc="$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')"

# ---- HARD: canon values never enter a model's context (David, 2026-10-08, data-org-notebook AGENTS.md).
canon_re='(canon_ingredient|canon_term|canon_assets\.|food_expression_ingredients|mirror\.canon_|history\.canon_|mart\.canon_)'
if [[ "$lc" =~ $canon_re ]] && [[ "$lc" =~ (select|duckdb|psql|run_query|wcx|lake-query) ]] && [[ ! "$lc" =~ (count\(|group[[:space:]]+by|sum\(|avg\() ]]; then
  hard "a query that could return canon values. Use counts, group-bys, null rates or IDs only"
fi

# ---- HARD: writes to production data (local DuckDB files and scratch databases are fine)
if [[ "$lc" =~ (psql|postgres|host=|ducklake|s3://|--env[[:space:]]+(prod|uat)|wcx|the_pantry) ]] && [[ "$lc" =~ (insert[[:space:]]+into|update[[:space:]]+[a-z_.\"]+[[:space:]]+set|delete[[:space:]]+from|drop[[:space:]]+(table|schema|view)|alter[[:space:]]+table|truncate|create[[:space:]]+(table|schema|view)|grant[[:space:]]|copy[[:space:]]+[a-z_.\"]+[[:space:]]+from) ]]; then
  hard "a write to a shared database or the lake"
fi

# ---- HARD: infrastructure, deploys and package publishing belong to their owners
[[ "$lc" =~ (terraform|tofu)[[:space:]]+(apply|destroy|import|state[[:space:]]+(rm|mv|push)) ]] && hard "infrastructure change (terraform)"
[[ "$lc" =~ (cdk[[:space:]]+(deploy|destroy)|pulumi[[:space:]]+(up|destroy)|serverless[[:space:]]+deploy|sam[[:space:]]+deploy|amplify[[:space:]]+(publish|push)) ]] && hard "deploy"
[[ "$lc" =~ (kubectl[[:space:]]+(apply|delete|patch|scale|rollout|edit|create)|helm[[:space:]]+(install|upgrade|uninstall|rollback)) ]] && hard "cluster change"
[[ "$lc" =~ aws[[:space:]]+[a-z0-9-]+[[:space:]]+(create|delete|put|update|run-|start|stop|terminate|invoke|deploy|attach|detach|modify|tag|untag|register|deregister|send|publish|restore|reboot|reset|import|cp|mv|rm|sync|set|enable|disable|associate|disassociate|authorize|revoke) ]] && hard "AWS write"
[[ "$lc" =~ (docker[[:space:]]+push|(npm|pnpm|yarn|uv|twine|poetry|cargo|dotnet[[:space:]]+nuget)[[:space:]]+publish|prefect[[:space:]]+(deploy|deployment[[:space:]]+run)) ]] && hard "publishing or running a deployment"
[[ "$lc" =~ git[[:space:]]+push.*(--force|-f([[:space:]]|$)|\+[a-z]) ]] && hard "force-push"
[[ "$lc" =~ git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+(main|master|prod|production|release)([[:space:]]|$) ]] && hard "push to a protected branch"

# ---- OUTWARD: leaves the Mac or changes shared state
[[ "$lc" =~ git[[:space:]]+push ]]                                                   && outward "git push"
[[ "$lc" =~ gh[[:space:]]+pr[[:space:]]+(merge|close|comment|review|edit|ready|create|reopen) ]] && outward "GitHub PR write"
[[ "$lc" =~ gh[[:space:]]+issue[[:space:]]+(close|comment|edit|create|delete|transfer|reopen) ]] && outward "GitHub issue write"
[[ "$lc" =~ gh[[:space:]]+(project[[:space:]]+item-(edit|add|delete|archive)|repo[[:space:]]+(create|delete|edit)|release[[:space:]]+create) ]] && outward "GitHub write"
[[ "$lc" =~ gh[[:space:]]+api.*(-x|--method)[[:space:]]*(post|patch|put|delete) ]]   && outward "GitHub API write"
# gh api is allowed for reads. It writes when it carries a GraphQL mutation, or sends fields (-f/-F/--field/--input)
# to a REST endpoint without -X GET (gh then POSTs). GraphQL reads (-f query=...) stay allowed.
if [[ "$lc" =~ (^|[;&|[:space:]])gh[[:space:]]+api([[:space:]]|$) ]]; then
  [[ "$lc" =~ mutation ]] && outward "GitHub API write (a GraphQL mutation)"
  if [[ ! "$lc" =~ gh[[:space:]]+api[[:space:]]+graphql ]] && [[ "$lc" =~ [[:space:]](-f|-F|--field|--raw-field|--input)[[:space:]=] ]] \
     && [[ ! "$lc" =~ (-x|--method)[[:space:]]*get ]]; then outward "GitHub API write (fields without -X GET make gh POST)"; fi
fi
# A redirect writes a file. Jobs write only in their job folder or /tmp. This also catches an unquoted ">=" in a search
# filter, which the shell turns into a stray file (2026-11-12: '=2026-11-09' in data-org-main).
unq="$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"
while [[ "$unq" =~ (^|[^0-9&>])[0-9]?\>\>?[[:space:]]*([^[:space:];&|]+)(.*)$ ]]; do
  tgt="${BASH_REMATCH[2]}"; unq="${BASH_REMATCH[3]}"
  case "$tgt" in
    /dev/null|\&[0-9]) ;;
    /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*|"$HOME"/cos/outbox/*|\~/cos/outbox/*|\$HOME/cos/outbox/*) ;;
    "$HOME"/builds/*|\~/builds/*|\$HOME/builds/*) ;;
    /*|\~*|\$*) outward "a redirect that writes '$tgt' outside the job folder" ;;
    *) [[ "${COS_LANE:-}" == build || "$PWD" == "$HOME"/builds/* || -n "${COS_FIX_DIR:-}" && "$PWD" == "$COS_FIX_DIR"* ]] && continue
       outward "a redirect that writes '$tgt' outside the job folder (quote search filters like \">=2026-11-09\")" ;;
  esac
done
[[ "$cmd" =~ EXECUTE=1 ]]                                                             && outward "EXECUTE=1 board operation"
[[ "$lc" =~ make[[:space:]]+(promote|set-pillar|complete|ragb|field|roadmap-fill|intake|board-add|ship-link|labels)([[:space:]]|$) ]] && outward "board-write make target"
[[ "$lc" =~ make[[:space:]]+classifier.*to= ]]                                        && outward "classifier switch"
[[ "$lc" =~ curl.*(-x|--request)[[:space:]]*(post|put|patch|delete)|curl.*(-d|--data|-f[[:space:]]|--form) ]] && outward "outbound HTTP write"
[[ "$lc" =~ (^|[;&|[:space:]])rm[[:space:]] ]]                                        && outward "delete (use git rm for tracked files)"
[[ "$lc" =~ (^|[;&|[:space:]])(chown)[[:space:]] ]]                                   && outward "ownership change"
[[ "$lc" =~ (^|[;&|[:space:]])chmod[[:space:]] ]] && [[ ! "$lc" =~ chmod[[:space:]]+[ug]?\+x[[:space:]]+[^/~] ]] && outward "permission change"
[[ "$lc" =~ (^|[;&|[:space:]])mv[[:space:]] ]] && [[ "$lc" =~ (^|[[:space:]])(/|~) ]]  && outward "move outside the workspace (use git mv inside it)"
agent_re='(^|[;&|(`/]|(env|exec|xargs|nohup|command|time|sudo)[[:space:]])[[:space:]]*(cursor-agent|agent|cursor)([[:space:]]|$)'
if [[ "$MODE" != "pair" ]] && [[ "$lc" =~ $agent_re ]]; then
  # Only "agent" as the command itself (after ; & | ( ` a path, or env/exec/xargs...), not as a word in an argument.
  outward "starting another agent from inside a job (cos-run routes engines)"
fi
exit 0
