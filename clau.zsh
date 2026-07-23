# clau — persona launcher for Claude Code
# One Claude Code, many hats. A persona = up to 3 files in .claude/personas/
# (repo-local wins over ~/.claude/personas/):
#   <persona>.json      CAPABILITY     settings: enabledPlugins, skillOverrides, permissions
#   <persona>.mcp.json  MCP            servers this persona talks to
#   <persona>.md        SYSTEM PROMPT  injected on top of repo CLAUDE.md
#
# clau            → list available personas
# clau designer   → launch that persona · flags after the name pass through (clau designer -c)
# plain claude?   → just type claude
#
# Install: source this file from ~/.zshrc
clau() {
  local pdir="$HOME/.claude/personas"
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

  # no persona named → self-discovery: read the same files clau launches from
  if (( $# == 0 )) || [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print "clau — persona launcher · clau <persona> [claude flags…]\n"
    local f name plugins side
    for f in "$pdir"/*.json(N) "$root/.claude/personas"/*.json(N); do
      [[ "$f" == *.mcp.json ]] && continue
      name="${${f:t}%.json}"
      plugins=$(jq -r '[.enabledPlugins // {} | to_entries[] | select(.value) | .key | split("@")[0]] | join(", ")' "$f")
      side=""
      [[ -f "$pdir/$name.mcp.json" ]] && side="global sidecar"
      [[ -f "$root/.claude/personas/$name.mcp.json" ]] && side="repo sidecar"
      [[ "$f" == "$root"/* ]] && name="$name (repo override)"
      printf "  %-24s plugins: %-36s mcp: %s\n" "$name" "${plugins:-none}" "${side:-base only}"
    done
    [[ -f "$pdir/base.mcp.json" ]] && print "\n  base.mcp.json ✓ — loads for every persona"
    # marketplace health: every plugin@marketplace key must resolve on this machine
    local m; local -a pfiles; pfiles=("$pdir"/*.json(N))
    (( ${#pfiles} )) && for m in $(jq -r '.enabledPlugins // {} | keys[] | split("@")[1]' "${pfiles[@]}" | sort -u); do
      if [[ -d "$HOME/.claude/plugins/marketplaces/$m" ]]; then
        print "  marketplace $m ✓"
      else
        print "  marketplace $m ✗ NOT registered → /plugin marketplace add <path>"
      fi
    done
    return
  fi

  # persona launch: settings (repo override → global) + base + persona sidecars
  local persona="$1"; shift
  local -a args mcp; local p
  for p in "$root/.claude/personas/$persona.json" "$pdir/$persona.json"; do
    [[ -f $p ]] && { args+=(--settings "$p"); break; }
  done
  (( ${#args} )) || { print -u2 "clau: unknown persona '$persona' — run clau to list personas"; return 1 }
  [[ -f "$pdir/base.mcp.json" ]] && mcp+=("$pdir/base.mcp.json")
  for p in "$root/.claude/personas/$persona.mcp.json" "$pdir/$persona.mcp.json"; do
    [[ -f $p ]] && { mcp+=("$p"); break; }
  done
  (( ${#mcp} )) && args+=(--mcp-config "${mcp[@]}")
  # persona instructions: your own CLAUDE.md-on-top (repo-local wins)
  for p in "$root/.claude/personas/$persona.md" "$pdir/$persona.md"; do
    [[ -f $p ]] && { args+=(--append-system-prompt-file "$p"); break; }
  done
  CLAU_PERSONA="$persona" command claude "${args[@]}" "$@"
}
