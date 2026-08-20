---
description: Remove the status bar from settings.json and delete the installed script
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/uninstall.sh:*)
---

Run `${CLAUDE_PLUGIN_ROOT}/uninstall.sh` and report its output.

The settings file (`~/.claude/statusline-config.txt`) and the backups
(`~/.claude/backups/`) are deliberately kept.

$ARGUMENTS
