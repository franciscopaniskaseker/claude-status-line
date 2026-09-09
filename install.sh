#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

sudo_prefix() {
  if [ "$(id -u)" -eq 0 ]; then
    printf ''
  elif command -v sudo >/dev/null 2>&1; then
    printf 'sudo '
  else
    printf ''
  fi
}

install_jq() {
  local sp cmd
  sp="$(sudo_prefix)"
  if command -v brew >/dev/null 2>&1; then
    cmd="brew install jq"
  elif command -v apt-get >/dev/null 2>&1; then
    cmd="${sp}apt-get update && ${sp}apt-get install -y jq"
  elif command -v dnf >/dev/null 2>&1; then
    cmd="${sp}dnf install -y jq"
  elif command -v yum >/dev/null 2>&1; then
    cmd="${sp}yum install -y jq"
  else
    say ""
    die "jq is required but no supported package manager was found (brew, apt-get, dnf, yum).
    Install jq manually, then re-run this installer."
  fi

  say ""
  warn "jq is required but not installed."
  say "    This will run: $cmd"
  printf '    Proceed? [y/N] '
  local reply=""
  if [ -t 0 ]; then
    read -r reply || reply=""
  elif [ -r /dev/tty ]; then
    { read -r reply < /dev/tty; } 2>/dev/null || reply=""
  else
    say ""
    die "Not running interactively and no terminal available.
    Install jq manually with: $cmd"
  fi
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) die "Aborted. Install jq manually with: $cmd" ;;
  esac

  say ""
  eval "$cmd" || die "jq installation failed. Install it manually, then re-run this installer."
  command -v jq >/dev/null 2>&1 || die "jq still not found on PATH after installation."
  ok "jq installed"
}

say ""
say "◆ claude-status-line installer"
say ""

[ -f "$SRC_DIR/statusline.sh" ] || die "statusline.sh not found next to install.sh. Run this from a full clone of the repository."

command -v jq >/dev/null 2>&1 || install_jq
ok "jq $(jq --version 2>/dev/null | sed 's/^jq-//')"

command -v git >/dev/null 2>&1 || warn "git not found - the branch indicator will stay empty."

if [ -s "$SETTINGS" ] && ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  backup_file "$SETTINGS"
  die "$SETTINGS is not valid JSON. It was backed up and nothing else was changed.
    Fix the JSON, then re-run this installer."
fi

mkdir -p "$CLAUDE_DIR"
backup_file "$TARGET"
cp "$SRC_DIR/statusline.sh" "$TARGET"
chmod 755 "$TARGET"
ok "installed $TARGET (mode 755)"

if [ -s "$SETTINGS" ]; then
  backup_file "$SETTINGS"
  current="$(cat "$SETTINGS")"
  mode="$(stat -c %a "$SETTINGS" 2>/dev/null || stat -f %Lp "$SETTINGS" 2>/dev/null || printf '644')"
else
  [ -e "$SETTINGS" ] && backup_file "$SETTINGS"
  current="{}"
  mode="644"
fi

tmp="$(mktemp "$CLAUDE_DIR/.settings.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

printf '%s' "$current" | jq --arg cmd "$TARGET" '
  .statusLine = { type: "command", command: $cmd, refreshInterval: 30 }
' > "$tmp" || die "Failed to update $SETTINGS."

mv "$tmp" "$SETTINGS"
trap - EXIT
chmod "$mode" "$SETTINGS" 2>/dev/null || chmod 644 "$SETTINGS"
ok "configured statusLine in $SETTINGS"

say ""
if [ "${#BACKUPS[@]}" -gt 0 ]; then
  say "Backups created:"
  for b in "${BACKUPS[@]}"; do
    say "  $b"
  done
else
  say "Backups created: none (nothing existed to back up)."
fi

say ""
say "Done. Restart Claude Code to load the status line."
say "  (run /exit, then relaunch \`claude\`)"
say ""
