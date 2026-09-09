#!/usr/bin/env bash

set -euo pipefail

MODE_ASCII="${CLAUDE_STATUSLINE_ASCII:-0}"
MODE_NERD="${CLAUDE_STATUSLINE_NERDFONT:-0}"
MODE_POWERLINE="${CLAUDE_STATUSLINE_POWERLINE:-$MODE_NERD}"
MODE_TRUECOLOR=0
case "${COLORTERM:-}" in
  truecolor|24bit) MODE_TRUECOLOR=1 ;;
esac

C_OFF=$'\033[0m'
C_CYAN=$'\033[36m'
C_BLUE=$'\033[34m'
C_DIM=$'\033[90m'
C_AMBER=$'\033[33m'
C_LIME=$'\033[32m'
C_ROSE=$'\033[31m'

if (( MODE_TRUECOLOR )); then
  C_VIOLET=$'\033[38;2;114;102;234m'
else
  C_VIOLET=$'\033[35m'
fi

if [ "$MODE_ASCII" = "1" ]; then
  G_MARK="<>"
  G_VCS="> "
  G_ALERT="!"
  G_TIMER=""
  G_BADGE="* "
  G_ARROW="->"
  DIVIDER=" | "
  CELL_ON="#"
  CELL_OFF="-"
elif [ "$MODE_NERD" = "1" ]; then
  G_MARK="◆"
  G_VCS=" "
  G_ALERT=" 󰀦"
  G_TIMER="󰥔 "
  G_BADGE=" "
  G_ARROW="→"
  CELL_ON="█"
  CELL_OFF="░"
  if [ "$MODE_POWERLINE" = "1" ]; then DIVIDER="  "; else DIVIDER=" │ "; fi
else
  G_MARK="◆"
  G_VCS="⎇ "
  G_ALERT=" ⚠"
  G_TIMER="⏳ "
  G_BADGE="⚙ "
  G_ARROW="→"
  CELL_ON="█"
  CELL_OFF="░"
  if [ "$MODE_POWERLINE" = "1" ]; then DIVIDER="  "; else DIVIDER=" │ "; fi
fi

bail() {
  printf '%s' "${C_DIM}${1:-─}${C_OFF}"
  exit 0
}

command -v jq >/dev/null 2>&1 || bail "─ │ jq not found"

payload=$(cat)

fields=$(printf '%s' "$payload" | jq -r '
  (.model.display_name // ""),
  (.context_window.used_percentage // 0 | tostring),
  (.context_window.total_input_tokens // 0 | tostring),
  (.context_window.context_window_size // 0 | tostring),
  (.cost.total_cost_usd // 0 | tostring),
  (.cost.total_duration_ms // 0 | tostring),
  (.cost.total_lines_added // 0 | tostring),
  (.cost.total_lines_removed // 0 | tostring),
  (.workspace.current_dir // "."),
  (.worktree.branch // ""),
  (.worktree.name // ""),
  (.agent.name // ""),
  (.rate_limits.five_hour.used_percentage // -1 | tostring),
  (.rate_limits.five_hour.resets_at // -1 | tostring),
  (.rate_limits.seven_day.used_percentage // -1 | tostring),
  "END"
' 2>/dev/null) || bail "─ │ bad payload"

{
  IFS= read -r f_model
  IFS= read -r f_ctx_pct
  IFS= read -r f_tok_used
  IFS= read -r f_tok_max
  IFS= read -r f_cost
  IFS= read -r f_ms
  IFS= read -r f_added
  IFS= read -r f_removed
  IFS= read -r f_cwd
  IFS= read -r f_branch
  IFS= read -r f_wt
  IFS= read -r f_agent
  IFS= read -r f_5h_pct
  IFS= read -r f_5h_at
  IFS= read -r f_7d_pct
  IFS= read -r _end
} <<< "$fields"

to_int() {
  local raw="${1%%.*}"
  case "$raw" in
    ''|*[!0-9-]*) printf '0' ;;
    *) printf '%s' "$raw" ;;
  esac
}

abbrev_tokens() {
  local n whole tenth
  n=$(to_int "$1")
  if (( n < 0 )); then n=0; fi
  if (( n < 1000 )); then
    printf '%d' "$n"
  elif (( n < 1000000 )); then
    whole=$(( n / 1000 ))
    tenth=$(( (n % 1000) / 100 ))
    if (( whole >= 100 || tenth == 0 )); then
      printf '%dk' "$whole"
    else
      printf '%d.%dk' "$whole" "$tenth"
    fi
  else
    whole=$(( n / 1000000 ))
    tenth=$(( (n % 1000000) / 100000 ))
    if (( tenth == 0 )); then
      printf '%dM' "$whole"
    else
      printf '%d.%dM' "$whole" "$tenth"
    fi
  fi
}

clock_at() {
  date -d "@$1" +%H:%M 2>/dev/null || date -r "$1" +%H:%M 2>/dev/null || printf -- '--:--'
}

span_of() {
  local secs=$1 h m
  h=$(( secs / 3600 ))
  m=$(( (secs % 3600) / 60 ))
  if (( h > 0 )); then
    printf '%dh%02dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

mtime_of() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf '0'
}

model_label="${f_model:-─}"

pct=$(to_int "$f_ctx_pct")
if (( pct < 0 )); then pct=0; fi
if (( pct > 100 )); then pct=100; fi

if (( pct >= 90 )); then heat="$C_ROSE"
elif (( pct >= 70 )); then heat="$C_AMBER"
else heat="$C_LIME"; fi

filled=$(( pct / 10 ))
if (( filled > 10 )); then filled=10; fi

RAMP_R=(46 116 186 241 239 236 233 231 211 192)
RAMP_G=(204 195 186 196 161 126 101 76 66 57)
RAMP_B=(113 89 64 15 24 34 44 60 50 43)

gauge=""
if [ "$MODE_ASCII" = "1" ]; then
  for (( i=0; i<10; i++ )); do
    if (( i < filled )); then gauge="${gauge}${CELL_ON}"; else gauge="${gauge}${CELL_OFF}"; fi
  done
elif (( MODE_TRUECOLOR )); then
  for (( i=0; i<10; i++ )); do
    if (( i < filled )); then
      gauge="${gauge}"$'\033'"[38;2;${RAMP_R[$i]};${RAMP_G[$i]};${RAMP_B[$i]}m${CELL_ON}"
    else
      gauge="${gauge}"$'\033'"[38;2;60;60;60m${CELL_OFF}"
    fi
  done
  gauge="${gauge}${C_OFF}"
else
  for (( i=0; i<10; i++ )); do
    if (( i < filled )); then gauge="${gauge}${CELL_ON}"; else gauge="${gauge}${CELL_OFF}"; fi
  done
  gauge="${heat}${gauge}${C_OFF}"
fi

alert=""
if (( pct >= 90 )); then alert="${C_ROSE}${G_ALERT}${C_OFF}"; fi

tokens=""
tok_used=$(to_int "$f_tok_used")
tok_max=$(to_int "$f_tok_max")
if (( tok_used > 0 && tok_max > 0 )); then
  tokens=" ${C_DIM}$(abbrev_tokens "$tok_used")/$(abbrev_tokens "$tok_max")${C_OFF}"
elif (( tok_used > 0 )); then
  tokens=" ${C_DIM}$(abbrev_tokens "$tok_used")${C_OFF}"
fi

spend=$(printf '%.2f' "${f_cost:-0}" 2>/dev/null || printf '0.00')
spend_int=$(to_int "${f_cost:-0}")
if (( spend_int >= 10 )); then spend_color="$C_ROSE"
elif (( spend_int >= 5 )); then spend_color="$C_AMBER"
elif [ "$spend" = "0.00" ]; then spend_color="$C_DIM"
else spend_color="$C_AMBER"; fi

elapsed=""
ms=$(to_int "$f_ms")
if (( ms > 0 )); then
  total_s=$(( ms / 1000 ))
  e_m=$(( total_s / 60 ))
  e_s=$(( total_s % 60 ))
  if (( e_m > 0 || e_s > 0 )); then
    elapsed="${DIVIDER}${C_DIM}${e_m}m${e_s}s${C_OFF}"
  fi
fi

quota=""
q5=$(to_int "$f_5h_pct")
q7=$(to_int "$f_7d_pct")
if (( q5 >= 0 )); then
  if (( q5 >= 90 )); then q5_heat="$C_ROSE"
  elif (( q5 >= 70 )); then q5_heat="$C_AMBER"
  else q5_heat="$C_LIME"; fi
  quota="${q5_heat}5h:${q5}%${C_OFF}"
fi
if (( q7 >= 0 )); then
  if [ -n "$quota" ]; then quota="${quota} "; fi
  if (( q7 >= 80 )); then quota="${quota}${C_ROSE}7d:${q7}%${C_OFF}"
  else quota="${quota}${C_DIM}7d:${q7}%${C_OFF}"; fi
fi
if [ -n "$quota" ]; then quota="${DIVIDER}${quota}"; fi

reset_at=$(to_int "$f_5h_at")
now=$(date +%s)
if (( reset_at > 0 && reset_at > now )); then
  left=$(( reset_at - now ))
  if (( left <= 1800 )); then reset_color="$C_AMBER"; else reset_color="$C_DIM"; fi
  countdown="${reset_color}${G_TIMER}reset: $(span_of "$left") ${G_ARROW} $(clock_at "$reset_at")${C_OFF}"
else
  countdown="${C_DIM}${G_TIMER}reset: -- ${G_ARROW} --:--${C_OFF}"
fi

branch="${f_branch:-}"
flag=""
if [ -n "${f_cwd:-}" ] && [ -d "${f_cwd:-}" ]; then
  cache_key=$(printf '%s' "$f_cwd" | cksum | cut -d' ' -f1)
  cache="${TMPDIR:-/tmp}/claude-statusline-$(id -u)-${cache_key}"
  stale=1
  if [ -f "$cache" ]; then
    age=$(( now - $(mtime_of "$cache") ))
    if (( age <= 5 )); then stale=0; fi
  fi
  if (( stale )); then
    if git -C "$f_cwd" rev-parse --git-dir >/dev/null 2>&1; then
      fresh_branch="$branch"
      if [ -z "$fresh_branch" ]; then
        fresh_branch=$(git -C "$f_cwd" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null) || fresh_branch=""
      fi
      if [ -z "$fresh_branch" ]; then
        fresh_branch=$(git -C "$f_cwd" rev-parse --short HEAD 2>/dev/null) || fresh_branch=""
      fi
      fresh_flag=""
      if ! git -C "$f_cwd" -c core.useBuiltinFSMonitor=false diff --quiet 2>/dev/null ||
         ! git -C "$f_cwd" -c core.useBuiltinFSMonitor=false diff --cached --quiet 2>/dev/null; then
        fresh_flag="*"
      fi
      printf '%s|%s\n' "$fresh_branch" "$fresh_flag" > "$cache" 2>/dev/null || true
    else
      printf '|\n' > "$cache" 2>/dev/null || true
    fi
  fi
  if [ -f "$cache" ]; then
    IFS='|' read -r hit_branch hit_flag < "$cache" || true
    if [ -z "$branch" ]; then branch="${hit_branch:-}"; fi
    flag="${hit_flag:-}"
  fi
fi

churn=""
added=$(to_int "$f_added")
removed=$(to_int "$f_removed")
if (( added > 0 || removed > 0 )); then
  churn="${C_LIME}+${added}${C_OFF}/${C_ROSE}-${removed}${C_OFF}"
fi

row1="${C_VIOLET}${G_MARK}${C_OFF} ${C_CYAN}${model_label}${C_OFF}"
row1="${row1}${DIVIDER}${gauge} ${heat}${pct}%${C_OFF}${alert}${tokens}"
row1="${row1}${quota}${elapsed}"
row1="${row1}${DIVIDER}${spend_color}\$${spend}${C_OFF}"

segments=()
if [ -n "$branch" ]; then
  segments+=("${C_DIM}${G_VCS}${branch}${flag}${C_OFF}")
fi
if [ -n "$churn" ]; then
  segments+=("$churn")
fi
segments+=("${C_BLUE}$(basename "${f_cwd:-.}")${C_OFF}")
if [ -n "${f_wt:-}" ]; then
  segments+=("${C_AMBER}${G_BADGE}worktree:${f_wt}${C_OFF}")
elif [ -n "${f_agent:-}" ]; then
  segments+=("${C_AMBER}${G_BADGE}${f_agent}${C_OFF}")
fi
segments+=("$countdown")

row2=""
for (( i=0; i<${#segments[@]}; i++ )); do
  if (( i > 0 )); then row2="${row2}${DIVIDER}"; fi
  row2="${row2}${segments[$i]}"
done

printf '%s\n%s' "$row1" "$row2"
