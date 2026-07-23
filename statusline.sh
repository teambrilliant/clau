#!/bin/sh
# clau statusline — shows the active persona in Claude Code sessions launched via clau.
# Install: cp to ~/.claude/statusline.sh, chmod +x, then in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }
# Bare claude sessions degrade gracefully: no persona segment, just model + directory.
input=$(cat)
model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
dir=$(basename "$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "?"')")
if [ -n "$CLAU_PERSONA" ]; then
  printf '\033[1;38;5;208m⬢ %s\033[0m · %s · %s' "$CLAU_PERSONA" "$model" "$dir"
else
  printf '%s · %s' "$model" "$dir"
fi
