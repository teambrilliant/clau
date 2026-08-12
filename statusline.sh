#!/bin/sh
input=$(cat)
model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
dir=$(basename "$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "?"')")
tab=$(printf '\t')
if [ -n "$CLAU_BADGES" ]; then
  printf '%s\n' "$CLAU_BADGES" | while IFS="$tab" read -r color name; do
    [ -z "$name" ] && continue
    [ -z "$color" ] && color='1;38;5;208'
    printf '\033[%sm ⬢ %s \033[0m' "$color" "$name"
  done
  printf ' · '
elif [ -n "$CLAU_PERSONA" ]; then
  printf '\033[1;38;5;208m⬢ %s\033[0m · ' "$CLAU_PERSONA"
fi
printf '%s · %s' "$model" "$dir"
