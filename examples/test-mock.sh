#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SL="$HERE/../statusline.sh"
NOW="$(date +%s)"
SOON=$(( NOW + 6420 ))
NEAR=$(( NOW + 900 ))
PAST=$(( NOW - 300 ))
CWD="$(cd "$HERE/.." && pwd)"

render() {
  printf '\n\033[1m── %s\033[0m\n' "$1"
  shift
  printf '%s' "$1" | env "${@:2}" bash "$SL"
  printf '\n'
}

base='{
  "model": {"display_name": "Opus"},
  "context_window": {"used_percentage": 42, "total_input_tokens": 84231, "context_window_size": 200000},
  "cost": {"total_cost_usd": 1.234, "total_duration_ms": 723000, "total_lines_added": 156, "total_lines_removed": 23},
  "workspace": {"current_dir": "CWD"},
  "rate_limits": {"five_hour": {"used_percentage": 23.5, "resets_at": SOON}, "seven_day": {"used_percentage": 41.2, "resets_at": SOON}}
}'

mk() {
  printf '%s' "$1" | sed -e "s#CWD#$CWD#g" -e "s#SOON#$SOON#g" -e "s#NEAR#$NEAR#g" -e "s#PAST#$PAST#g"
}

render "normal" "$(mk "$base")" COLORTERM=truecolor

render "warning (75%)" "$(mk "${base/\"used_percentage\": 42/\"used_percentage\": 75}")" COLORTERM=truecolor

render "danger (94%)" "$(mk "${base/\"used_percentage\": 42/\"used_percentage\": 94}")" COLORTERM=truecolor

render "quota nearly spent (5h 88%, resets in 15m)" "$(mk '{
  "model": {"display_name": "Opus"},
  "context_window": {"used_percentage": 60, "total_input_tokens": 120400, "context_window_size": 200000},
  "cost": {"total_cost_usd": 12.5, "total_duration_ms": 3600000},
  "workspace": {"current_dir": "CWD"},
  "rate_limits": {"five_hour": {"used_percentage": 88, "resets_at": NEAR}, "seven_day": {"used_percentage": 91, "resets_at": SOON}}
}')" COLORTERM=truecolor

render "fresh session (no cost, no churn, no rate_limits)" "$(mk '{
  "model": {"display_name": "Sonnet"},
  "context_window": {"used_percentage": 2, "total_input_tokens": 4200, "context_window_size": 200000},
  "cost": {"total_cost_usd": 0, "total_duration_ms": 0, "total_lines_added": 0, "total_lines_removed": 0},
  "workspace": {"current_dir": "CWD"}
}')" COLORTERM=truecolor

render "expired resets_at (in the past)" "$(mk '{
  "model": {"display_name": "Opus"},
  "context_window": {"used_percentage": 30, "total_input_tokens": 60000, "context_window_size": 200000},
  "cost": {"total_cost_usd": 0.5},
  "workspace": {"current_dir": "CWD"},
  "rate_limits": {"five_hour": {"used_percentage": 12, "resets_at": PAST}}
}')" COLORTERM=truecolor

render "1M context window" "$(mk '{
  "model": {"display_name": "Sonnet"},
  "context_window": {"used_percentage": 15, "total_input_tokens": 154900, "context_window_size": 1000000},
  "cost": {"total_cost_usd": 3.1},
  "workspace": {"current_dir": "CWD"},
  "rate_limits": {"five_hour": {"used_percentage": 5, "resets_at": SOON}}
}')" COLORTERM=truecolor

render "subagent" "$(mk '{
  "model": {"display_name": "Haiku"},
  "context_window": {"used_percentage": 12, "total_input_tokens": 24000, "context_window_size": 200000},
  "cost": {"total_cost_usd": 0.02, "total_duration_ms": 45000},
  "workspace": {"current_dir": "CWD"},
  "agent": {"name": "security-reviewer"},
  "rate_limits": {"five_hour": {"used_percentage": 23, "resets_at": SOON}}
}')" COLORTERM=truecolor

render "worktree" "$(mk '{
  "model": {"display_name": "Opus"},
  "context_window": {"used_percentage": 55, "total_input_tokens": 110000, "context_window_size": 200000},
  "cost": {"total_cost_usd": 2.4, "total_duration_ms": 300000},
  "workspace": {"current_dir": "CWD"},
  "worktree": {"name": "my-feature", "branch": "worktree-my-feature"},
  "rate_limits": {"five_hour": {"used_percentage": 33, "resets_at": SOON}}
}')" COLORTERM=truecolor

render "ASCII mode" "$(mk "$base")" CLAUDE_STATUSLINE_ASCII=1

render "Nerd Font mode" "$(mk "$base")" CLAUDE_STATUSLINE_NERDFONT=1 COLORTERM=truecolor

render "no truecolor (plain ANSI)" "$(mk "$base")" COLORTERM=

render "empty payload" "{}" COLORTERM=truecolor

printf '\n'
