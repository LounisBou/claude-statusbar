#!/usr/bin/env bash
# Removes the status line: deletes the statusLine key from settings.json and
# removes the installed script. Settings and backups are left in place.

set -euo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST_DIR="$CONFIG_DIR/statusbar"
SETTINGS="$CONFIG_DIR/settings.json"

say() { printf '  %s\n' "$*"; }

if [ -f "$SETTINGS" ] && jq -e '.statusLine.command // "" | test("statusbar/statusline.sh")' \
     "$SETTINGS" >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq 'del(.statusLine)' "$SETTINGS" > "$tmp"
  chmod 600 "$tmp"; mv "$tmp" "$SETTINGS"
  say "statusLine removed from settings.json"
else
  say "settings.json does not point at this status line, left untouched"
fi

if [ -d "$DEST_DIR" ]; then
  rm -rf "$DEST_DIR"
  say "removed: $DEST_DIR"
fi

say "Kept: $CONFIG_DIR/statusline-config.txt and $CONFIG_DIR/backups/"
