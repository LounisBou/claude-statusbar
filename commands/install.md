---
description: Install or update the two-line status bar
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/install.sh:*), Read
---

Install the status line shipped by this plugin.

Run `${CLAUDE_PLUGIN_ROOT}/install.sh` and report its output to the user.

The script is idempotent: it copies the status line script into
`~/.claude/statusbar/`, creates `~/.claude/statusline-config.txt` if missing,
writes the `statusLine` key into `~/.claude/settings.json`, and migrates any
install still relying on the old web session-cookie mechanism (its
`SessionStart` hook, fetcher script and credentials file).

Nothing is deleted: migrated files are moved to
`~/.claude/backups/statusbar-<timestamp>/`.

Once it finishes, tell the user to restart their session for the bar to appear.

$ARGUMENTS
