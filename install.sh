#!/bin/bash
# ============================================================================
# claude-token-usage-display — installer
#
# Installs a Claude Code status line that shows live token/context usage and
# raises a loud alert BEFORE you send a prompt into an already-full context.
#
# Safe to run repeatedly:
#   - copies statusline.sh into ~/.claude/
#   - merges the `statusLine` key into ~/.claude/settings.json (jq),
#     preserving every other key (env, hooks, plugins, permissions…)
#   - backs settings.json up before touching it
#
# Usage:  ./install.sh
# ============================================================================
set -euo pipefail

# --- resolve paths ---------------------------------------------------------
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_SRC="$SRC_DIR/statusline.sh"
SCRIPT_DST="$CLAUDE_DIR/statusline.sh"

say()  { printf '\033[36m▶\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# --- 1. dependencies -------------------------------------------------------
say "Checking dependencies…"
command -v jq >/dev/null 2>&1 || die "jq is required but not found. Install it: 'brew install jq' (macOS) or 'apt install jq' (Linux)."
[ -f "$SCRIPT_SRC" ] || die "statusline.sh not found next to this installer ($SCRIPT_SRC)."
ok "jq found: $(command -v jq)"

# --- 2. copy the status line script ----------------------------------------
say "Installing status line script…"
mkdir -p "$CLAUDE_DIR"
cp "$SCRIPT_SRC" "$SCRIPT_DST"
chmod +x "$SCRIPT_DST"
ok "Installed $SCRIPT_DST"

# --- 3. merge into settings.json -------------------------------------------
say "Wiring into ${SETTINGS} ..."
STATUSLINE_JSON=$(jq -n --arg cmd "$SCRIPT_DST" '{
  type: "command",
  command: $cmd,
  padding: 0,
  refreshInterval: 5
}')

if [ -f "$SETTINGS" ]; then
  jq empty "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS exists but is not valid JSON. Fix it and re-run."
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  ok "Backed up existing settings to $BACKUP"
  tmp=$(mktemp)
  jq --argjson sl "$STATUSLINE_JSON" '.statusLine = $sl' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
else
  jq -n --argjson sl "$STATUSLINE_JSON" '{statusLine: $sl}' > "$SETTINGS"
  ok "Created $SETTINGS"
fi
ok "statusLine configured (existing settings preserved)"

# --- 4. smoke test ---------------------------------------------------------
say "Running a smoke test…"
SAMPLE='{"model":{"display_name":"Opus 4.8"},"context_window":{"context_window_size":1000000,"used_percentage":15,"current_usage":{"input_tokens":150000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}},"cost":{"total_cost_usd":0.42}}'
echo
printf '   '; echo "$SAMPLE" | "$SCRIPT_DST"; echo
echo

ok "Done! Start a new Claude Code session (or wait ~5s) to see your status line."
echo
echo "  Tune thresholds/format by editing: $SCRIPT_DST"
echo "  To uninstall:                      ./uninstall.sh"
