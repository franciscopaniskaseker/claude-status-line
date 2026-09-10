#!/usr/bin/env bash

set -euo pipefail

MODE_ASCII="${CLAUDE_STATUSLINE_ASCII:-0}"
MODE_NERD="${CLAUDE_STATUSLINE_NERDFONT:-0}"
MODE_POWERLINE="${CLAUDE_STATUSLINE_POWERLINE:-$MODE_NERD}"

# How many colors the terminal can show: 0, 16, 256, or 16777216 (truecolor).
# Very few terminals advertise this honestly, so guess generously and let the
# user override. The floor is 16 rather than 0: every ANSI terminal since the
# 1980s renders those, PuTTY and the Windows console included, so a terminal we
# fail to recognise still comes out colored.
detect_color_depth() {
  case "${CLAUDE_STATUSLINE_COLOR:-auto}" in
    none|off|0)          printf '0'; return ;;
    16|ansi|basic)       printf '16'; return ;;
    256|8bit)            printf '256'; return ;;
    truecolor|24bit|16m) printf '16777216'; return ;;
  esac

  if [ -n "${NO_COLOR:-}" ]; then printf '0'; return; fi

  case "${FORCE_COLOR:-}" in
    0|false) printf '0'; return ;;
    1|true)  printf '16'; return ;;
    2)       printf '256'; return ;;
    3)       printf '16777216'; return ;;
  esac

  case "${TERM:-}" in
    dumb) printf '0'; return ;;
  esac

  # Truecolor. COLORTERM is the only standard signal and most terminals omit
  # it, so fall through to a roster of terminals known to do 24-bit color.
  case "${COLORTERM:-}" in
    truecolor|24bit) printf '16777216'; return ;;
  esac
  case "${TERM:-}" in
    *truecolor*|*-direct*) printf '16777216'; return ;;
  esac
  case "${TERM_PROGRAM:-}" in
    iTerm.app|WezTerm|vscode|Hyper|ghostty|rio|Tabby|WarpTerminal)
      printf '16777216'; return ;;
  esac
  # Windows Terminal, ConEmu/Cmder, mintty (Git Bash), Konsole.
  if [ -n "${WT_SESSION:-}" ] || [ "${ConEmuANSI:-}" = "ON" ] ||
     [ -n "${KONSOLE_VERSION:-}" ] || [ -n "${MSYSTEM:-}" ]; then
    printf '16777216'; return
  fi
  # GNOME Terminal and friends gained 24-bit color in VTE 0.36.
  if [ -n "${VTE_VERSION:-}" ] && [ "${VTE_VERSION}" -ge 3600 ] 2>/dev/null; then
    printf '16777216'; return
  fi

  case "${TERM:-}" in
    *256color*|*-256*) printf '256'; return ;;
  esac
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal) printf '256'; return ;;
  esac

  printf '16'
}

COLOR_DEPTH=$(detect_color_depth)

if (( COLOR_DEPTH == 0 )); then
  C_OFF=""
  C_CYAN=""
  C_BLUE=""
  C_DIM=""
  C_AMBER=""
  C_LIME=""
  C_ROSE=""
  C_VIOLET=""
else
  C_OFF=$'\033[0m'
  C_CYAN=$'\033[36m'
  C_BLUE=$'\033[34m'
  C_DIM=$'\033[90m'
  C_AMBER=$'\033[33m'
  C_LIME=$'\033[32m'
  C_ROSE=$'\033[31m'
  if (( COLOR_DEPTH >= 16777216 )); then
    C_VIOLET=$'\033[38;2;114;102;234m'
  elif (( COLOR_DEPTH >= 256 )); then
    C_VIOLET=$'\033[38;5;99m'
  else
    C_VIOLET=$'\033[35m'
  fi
fi

if [ "$MODE_ASCII" = "1" ]; then
  G_MARK="<>"
  G_VCS="> "
  G_ALERT="!"
  G_TIMER=""
  G_BADGE="* "
  G_ARROW="->"
  G_DOT=":"
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
  G_DOT="·"
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
  G_DOT="·"
  CELL_ON="█"
  CELL_OFF="░"
  if [ "$MODE_POWERLINE" = "1" ]; then DIVIDER="  "; else DIVIDER=" │ "; fi
fi

bail() {
  printf '%s' "${C_DIM}${1:-─}${C_OFF}"
  exit 0
}


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

# dhm_of <milliseconds> -> 5m | 1h12m | 1d1h0m
dhm_of() {
  local total_m=$(( $1 / 60000 )) d h m
  d=$(( total_m / 1440 ))
  h=$(( (total_m % 1440) / 60 ))
  m=$(( total_m % 60 ))
  if (( d > 0 )); then
    printf '%dd%dh%dm' "$d" "$h" "$m"
  elif (( h > 0 )); then
    printf '%dh%dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
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

# The same green -> red gradient expressed at each color depth, so the gauge
# reads the same way whether the terminal has 16 colors or 16 million.
RAMP_R=(46 116 186 241 239 236 233 231 211 192)
RAMP_G=(204 195 186 196 161 126 101 76 66 57)
RAMP_B=(113 89 64 15 24 34 44 60 50 43)
RAMP_256=(41 113 143 220 214 208 202 203 167 130)
RAMP_16=(32 32 33 33 33 91 91 91 31 31)

EMPTY_RGB="38;2;60;60;60"
EMPTY_256="38;5;237"
EMPTY_16="90"

GAUGE_WIDTH=10

# cell_color <ramp index, or -1 for an unfilled cell> -> SGR escape
cell_color() {
  local idx=$1
  if (( idx < 0 )); then
    if (( COLOR_DEPTH >= 16777216 )); then printf '\033[%sm' "$EMPTY_RGB"
    elif (( COLOR_DEPTH >= 256 )); then printf '\033[%sm' "$EMPTY_256"
    else printf '\033[%sm' "$EMPTY_16"; fi
    return
  fi
  if (( COLOR_DEPTH >= 16777216 )); then
    printf '\033[38;2;%s;%s;%sm' "${RAMP_R[$idx]}" "${RAMP_G[$idx]}" "${RAMP_B[$idx]}"
  elif (( COLOR_DEPTH >= 256 )); then
    printf '\033[38;5;%sm' "${RAMP_256[$idx]}"
  else
    printf '\033[%sm' "${RAMP_16[$idx]}"
  fi
}

# render_gauge <percent 0-100> <cells>
render_gauge() {
  local value=$1 width=$2
  local i idx filled bar=""
  if (( value < 0 )); then value=0; fi
  if (( value > 100 )); then value=100; fi
  filled=$(( value * width / 100 ))
  if (( filled > width )); then filled=$width; fi
  if (( COLOR_DEPTH == 0 )); then
    for (( i=0; i<width; i++ )); do
      if (( i < filled )); then bar="${bar}${CELL_ON}"; else bar="${bar}${CELL_OFF}"; fi
    done
    printf '%s' "$bar"
    return
  fi
  for (( i=0; i<width; i++ )); do
    if (( i < filled )); then
      idx=$(( i * 10 / width ))
      bar="${bar}$(cell_color "$idx")${CELL_ON}"
    else
      bar="${bar}$(cell_color -1)${CELL_OFF}"
    fi
  done
  printf '%s%s' "$bar" "$C_OFF"
}

# --diagnose prints what this terminal was detected as, so a user whose status
# line looks washed out can paste the result back.
if [ "${1:-}" = "--diagnose" ] || [ "${1:-}" = "--colors" ]; then
  printf 'claude-status-line color diagnosis\n\n'
  printf '  detected depth           %s colors\n' "$COLOR_DEPTH"
  printf '  TERM                     %s\n' "${TERM:-<unset>}"
  printf '  COLORTERM                %s\n' "${COLORTERM:-<unset>}"
  printf '  TERM_PROGRAM             %s\n' "${TERM_PROGRAM:-<unset>}"
  printf '  WT_SESSION               %s\n' "${WT_SESSION:+<set>}"
  printf '  ConEmuANSI               %s\n' "${ConEmuANSI:-<unset>}"
  printf '  MSYSTEM                  %s\n' "${MSYSTEM:-<unset>}"
  printf '  VTE_VERSION              %s\n' "${VTE_VERSION:-<unset>}"
  printf '  NO_COLOR                 %s\n' "${NO_COLOR:-<unset>}"
  printf '  FORCE_COLOR              %s\n' "${FORCE_COLOR:-<unset>}"
  printf '  CLAUDE_STATUSLINE_COLOR  %s\n' "${CLAUDE_STATUSLINE_COLOR:-<unset>}"
  printf '\n  gauge at this depth      %s\n' "$(render_gauge 70 "$GAUGE_WIDTH")"
  printf '  16-color check           %sred %sgreen %syellow %sdim%s\n' \
    "$C_ROSE" "$C_LIME" "$C_AMBER" "$C_DIM" "$C_OFF"
  printf '  glyph check              %s %s %s%s %s\n' \
    "$G_MARK" "$DIVIDER" "$CELL_ON" "$CELL_OFF" "$G_ARROW"
  printf '\nIf the swatch above is colorless, set CLAUDE_STATUSLINE_COLOR to\n'
  printf 'truecolor, 256 or 16. If the glyphs are mojibake, set\n'
  printf 'CLAUDE_STATUSLINE_ASCII=1.\n'
  exit 0
fi

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
  (.effort.level // ""),
  (.cost.total_api_duration_ms // 0 | tostring),
  (if .prompt_cache == null then "0" else "1" end),
  (.prompt_cache.warm // false | tostring),
  ((.prompt_cache.hit_ratio // -1) * 100 | round | tostring),
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
  IFS= read -r f_effort
  IFS= read -r f_api_ms
  IFS= read -r f_cache_on
  IFS= read -r f_cache_warm
  IFS= read -r f_cache_hit
  IFS= read -r _end
} <<< "$fields"


model_label="${f_model:-─}"

pct=$(to_int "$f_ctx_pct")
if (( pct < 0 )); then pct=0; fi
if (( pct > 100 )); then pct=100; fi

if (( pct >= 90 )); then heat="$C_ROSE"
elif (( pct >= 70 )); then heat="$C_AMBER"
else heat="$C_LIME"; fi

gauge=$(render_gauge "$pct" "$GAUGE_WIDTH")

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
api_ms=$(to_int "$f_api_ms")
if (( ms > 0 )); then
  elapsed="${C_DIM}$(dhm_of "$ms")"
  if (( api_ms >= 60000 )); then
    elapsed="${elapsed} api:$(dhm_of "$api_ms")"
  fi
  elapsed="${elapsed}${C_OFF}"
fi

effort_tag=""
if [ -n "${f_effort:-}" ]; then
  effort_tag="${C_DIM}${G_DOT}${f_effort}${C_OFF}"
fi

cache_seg=""
if [ "${f_cache_on:-0}" = "1" ]; then
  hit=$(to_int "$f_cache_hit")
  if [ "${f_cache_warm:-false}" != "true" ]; then
    cache_seg="${C_DIM}cache cold${C_OFF}"
  elif (( hit < 0 )); then
    cache_seg="${C_DIM}cache warm${C_OFF}"
  else
    if (( hit >= 80 )); then cache_heat="$C_LIME"
    elif (( hit >= 50 )); then cache_heat="$C_AMBER"
    else cache_heat="$C_ROSE"; fi
    cache_seg="${C_DIM}cache${C_OFF} ${cache_heat}${hit}%${C_OFF}"
  fi
fi

quota=""
q5=$(to_int "$f_5h_pct")
q7=$(to_int "$f_7d_pct")
if (( q5 >= 0 )); then
  if (( q5 > 100 )); then q5=100; fi
  if (( q5 >= 90 )); then q5_heat="$C_ROSE"
  elif (( q5 >= 70 )); then q5_heat="$C_AMBER"
  else q5_heat="$C_LIME"; fi
  q5_gauge=$(render_gauge "$q5" "$GAUGE_WIDTH")
  quota="${C_DIM}5h${C_OFF} ${q5_gauge} ${q5_heat}${q5}%${C_OFF}"
fi
if (( q7 >= 0 )); then
  if (( q7 > 100 )); then q7=100; fi
  if (( q7 >= 80 )); then q7_heat="$C_ROSE"
  elif (( q7 >= 60 )); then q7_heat="$C_AMBER"
  else q7_heat="$C_LIME"; fi
  q7_gauge=$(render_gauge "$q7" "$GAUGE_WIDTH")
  if [ -n "$quota" ]; then quota="${quota} "; fi
  quota="${quota}${C_DIM}7d${C_OFF} ${q7_gauge} ${q7_heat}${q7}%${C_OFF}"
fi

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

row1_segments=()
if [ -n "$quota" ]; then
  row1_segments+=("$quota")
fi
row1_segments+=("${gauge} ${heat}${pct}%${C_OFF}${alert}${tokens}")
if [ -n "$elapsed" ]; then
  row1_segments+=("$elapsed")
fi
row1_segments+=("${spend_color}\$${spend}${C_OFF}")

row1=""
for (( i=0; i<${#row1_segments[@]}; i++ )); do
  if (( i > 0 )); then row1="${row1}${DIVIDER}"; fi
  row1="${row1}${row1_segments[$i]}"
done

segments=("${C_VIOLET}${G_MARK}${C_OFF} ${C_CYAN}${model_label}${C_OFF}${effort_tag}")
if [ -n "$cache_seg" ]; then
  segments+=("$cache_seg")
fi
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
