#!/usr/bin/env bash
# Removes the status line: deletes the statusLine key from settings.json and
# removes the installed script. Settings and backups are left in place.

set -euo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST_DIR="$CONFIG_DIR/statusbar"
DEST="$DEST_DIR/statusline.sh"
SETTINGS="$CONFIG_DIR/settings.json"

say() { printf '  %s\n' "$*"; }

current=""
[ -f "$SETTINGS" ] && current=$(jq -r '.statusLine.command // ""' "$SETTINGS")

case "$current" in
  "$DEST")
    # Only ours: the whole key is ours to remove.
    tmp=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS" > "$tmp"
    chmod 600 "$tmp"; mv "$tmp" "$SETTINGS"
    say "statusLine removed from settings.json"
    ;;
  *"$DEST"*)
    # Another tool wraps us ("<its command> <our path>"): drop only our
    # path and leave that tool's command and every other key as they are.
    stripped=${current//$DEST/}
    stripped=$(printf '%s' "$stripped" | tr -s '[:space:]' ' ')
    stripped="${stripped#"${stripped%%[![:space:]]*}"}"
    stripped="${stripped%"${stripped##*[![:space:]]}"}"
    if [ -z "$stripped" ]; then
      say "statusLine wraps only this status bar, with nothing left to run afterwards: left untouched"
    else
      tmp=$(mktemp)
      jq --arg cmd "$stripped" '.statusLine.command = $cmd' "$SETTINGS" > "$tmp"
      chmod 600 "$tmp"; mv "$tmp" "$SETTINGS"
      say "our path removed from statusLine, wrapper kept: $stripped"
    fi
    ;;
  *)
    say "settings.json does not point at this status line, left untouched"
    ;;
esac

if [ -d "$DEST_DIR" ]; then
  rm -rf "$DEST_DIR"
  say "removed: $DEST_DIR"
fi

say "Kept: $CONFIG_DIR/statusline-config.txt and $CONFIG_DIR/backups/"
