#!/bin/bash
# ============================================================================
# claude-token-usage-display — uninstaller
# Removes the `statusLine` key from settings.json (leaving all other keys) and
# deletes the installed statusline.sh. Backs settings.json up first.
# ============================================================================
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DST="$CLAUDE_DIR/statusline.sh"

ok()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
warn(){ printf '\033[33m!\033[0m %s\n' "$1"; }
die() { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required to safely edit settings.json."

if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  tmp=$(mktemp)
  jq 'del(.statusLine)' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  ok "Removed statusLine from settings (backup: $BACKUP)"
else
  warn "No settings.json found — nothing to unwire."
fi

if [ -f "$SCRIPT_DST" ]; then
  rm "$SCRIPT_DST"
  ok "Deleted $SCRIPT_DST"
else
  warn "No statusline.sh found at $SCRIPT_DST."
fi

ok "Uninstalled. Restart Claude Code to clear the status line."
