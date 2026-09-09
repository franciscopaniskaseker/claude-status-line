#!/usr/bin/env bash

set -euo pipefail

STAMP="$(date +%s)"
CLAUDE_DIR="$HOME/.claude"
TARGET="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
BACKUPS=()

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

backup_file() {
  local f="$1" dest
  [ -e "$f" ] || return 0
  dest="${f}_backup_${STAMP}"
  cp -p "$f" "$dest"
  BACKUPS+=("$dest")
  ok "backed up $(basename "$f") -> $(basename "$dest")"
}

say ""
say "◆ claude-status-line uninstaller"
say ""

if [ -s "$SETTINGS" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    backup_file "$SETTINGS"
    die "jq is required to edit $SETTINGS but is not installed.
    Remove the \"statusLine\" block by hand, or install jq and re-run."
  fi
  if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
    backup_file "$SETTINGS"
    die "$SETTINGS is not valid JSON. It was backed up and left untouched.
    Remove the \"statusLine\" block by hand."
  fi

  backup_file "$SETTINGS"
  mode="$(stat -c %a "$SETTINGS" 2>/dev/null || stat -f %Lp "$SETTINGS" 2>/dev/null || printf '644')"

  tmp="$(mktemp "$CLAUDE_DIR/.settings.json.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT

  jq 'del(.statusLine)' "$SETTINGS" > "$tmp" || die "Failed to update $SETTINGS."

  mv "$tmp" "$SETTINGS"
  trap - EXIT
  chmod "$mode" "$SETTINGS" 2>/dev/null || chmod 644 "$SETTINGS"
  ok "removed statusLine from $SETTINGS"
else
  warn "no $SETTINGS found - nothing to unconfigure"
fi

if [ -e "$TARGET" ]; then
  backup_file "$TARGET"
  rm -f "$TARGET"
  ok "removed $TARGET"
else
  warn "no $TARGET found - nothing to remove"
fi

rm -f "${TMPDIR:-/tmp}"/claude-statusline-"$(id -u)"-* 2>/dev/null || true
ok "cleared status line cache files"

say ""
if [ "${#BACKUPS[@]}" -gt 0 ]; then
  say "Backups created:"
  for b in "${BACKUPS[@]}"; do
    say "  $b"
  done
  say ""
  say "Nothing was deleted without a backup. Remove them yourself when you no longer need them."
else
  say "Backups created: none (nothing existed to back up)."
fi

say ""
say "Done. Restart Claude Code to drop the status line."
say "  (run /exit, then relaunch \`claude\`)"
say ""
