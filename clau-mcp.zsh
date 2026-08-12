clau-mcp() {
  local cmd="$1"; shift 2>/dev/null

  case "$cmd" in
    add)
      local transport="stdio"
      local -a envs headers pos cmdline
      while (( $# )); do
        case "$1" in
          --transport|-t) transport="$2"; shift 2 ;;
          --env|-e) envs+=("$2"); shift 2 ;;
          --header|-H) headers+=("$2"); shift 2 ;;
          --) shift; cmdline=("$@"); break ;;
          -*) print -u2 "clau-mcp: unknown flag $1"; return 1 ;;
          *) pos+=("$1"); shift ;;
        esac
      done

      local persona="" name=""
      if [[ "$transport" == "stdio" ]]; then
        (( ${#cmdline} )) || { cmdline=("${pos[@]:1}"); pos=("${pos[1]}") }
        case ${#pos} in
          1) name="$pos[1]" ;;
          2) persona="$pos[1]"; name="$pos[2]" ;;
          *) print -u2 "usage: clau-mcp add [persona] <name> [--env K=\${VAR}]… -- <command> [args…]"; return 1 ;;
        esac
        (( ${#cmdline} )) || { print -u2 "clau-mcp: missing command"; return 1 }
        set -- "${cmdline[@]}"
      else
        case ${#pos} in
          2) name="$pos[1]"; set -- "$pos[2]" ;;
          3) persona="$pos[1]"; name="$pos[2]"; set -- "$pos[3]" ;;
          *) print -u2 "usage: clau-mcp add [persona] <name> --transport http <url> [--header K:V]…"; return 1 ;;
        esac
      fi

      local -a targets
      if [[ -n "$persona" ]]; then
        targets=("$persona")
      else
        targets=(${(f)"$(_clau_pick_personas)"})
        (( ${#targets} )) || { print "clau-mcp: nothing selected"; return 1 }
      fi

      local envjson='{}' hdrjson='{}' e
      for e in $envs; do
        envjson=$(print -r -- "$envjson" | jq --arg k "${e%%=*}" --arg v "${e#*=}" '.[$k]=$v') || return 1
        [[ "${e#*=}" == \$\{*\} ]] || print -u2 "clau-mcp: ${e%%=*} holds a literal value — prefer \${${e%%=*}} and clau-secret set ${e%%=*}"
      done
      for e in $headers; do
        hdrjson=$(print -r -- "$hdrjson" | jq --arg k "${e%%:*}" --arg v "${${e#*:}## }" '.[$k]=$v') || return 1
      done

      local srv
      if [[ "$transport" == "stdio" ]]; then
        local bin="$1"; shift
        local argsjson; argsjson=$(printf '%s\n' "$@" | jq -R . | jq -s .)
        srv=$(jq -n --arg c "$bin" --argjson a "$argsjson" --argjson e "$envjson" \
          '{type:"stdio",command:$c,args:$a} + (if ($e|length)>0 then {env:$e} else {} end)') || return 1
      else
        srv=$(jq -n --arg t "$transport" --arg u "$1" --argjson h "$hdrjson" \
          '{type:$t,url:$u} + (if ($h|length)>0 then {headers:$h} else {} end)') || return 1
      fi

      local t dir f tmp
      for t in $targets; do
        dir=$(_clau_persona_dir "$t") || return 1
        f="$dir/mcp.json"
        [[ -f "$f" ]] || print -r -- '{"mcpServers":{}}' > "$f"
        tmp=$(mktemp) || return 1
        jq --arg n "$name" --argjson s "$srv" '.mcpServers[$n]=$s' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1 }
        print "added $name → ${f/#$HOME/~}"
        jq --arg n "$name" '.mcpServers[$n]' "$f"
      done
      print "\nrestart to pick it up: clau ${targets[1]}"
      ;;

    rm|remove)
      local persona name
      case $# in
        1) name="$1" ;;
        2) persona="$1"; name="$2" ;;
        *) print -u2 "usage: clau-mcp rm [persona] <name>"; return 1 ;;
      esac
      local -a targets
      if [[ -n "$persona" ]]; then
        targets=("$persona")
      else
        targets=(${(f)"$(_clau_pick_personas)"})
        (( ${#targets} )) || { print "clau-mcp: nothing selected"; return 1 }
      fi
      local t dir f tmp
      for t in $targets; do
        dir=$(_clau_persona_dir "$t") || return 1
        f="$dir/mcp.json"
        [[ -f "$f" ]] || { print -u2 "clau-mcp: $t has no mcp.json"; continue }
        tmp=$(mktemp) || return 1
        jq --arg n "$name" 'del(.mcpServers[$n])' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1 }
        print "removed $name from ${f/#$HOME/~}"
      done
      ;;

    list|ls)
      local persona="$1" dir rel
      local filter='.mcpServers | to_entries[] | "  \(.key)  \(.value.type // "stdio")  \(.value.url // .value.command)"'
      if [[ -n "$persona" ]]; then
        dir=$(_clau_persona_dir "$persona") || return 1
        [[ -f "$dir/mcp.json" ]] && jq -r "$filter" "$dir/mcp.json" || print "  (none)"
      else
        while IFS=$'\t' read -r rel dir; do
          [[ -f "$dir/mcp.json" ]] || continue
          print "$rel"
          jq -r "$filter" "$dir/mcp.json"
        done < <(_clau_scan)
      fi
      ;;

    *)
      print "clau-mcp — manage MCP servers inside a persona · omit persona for the picker"
      print "  clau-mcp add [persona] <name> --transport http <url> [--header K:V]…"
      print "  clau-mcp add [persona] <name> [--env K=\${VAR}]… -- <command> [args…]"
      print "  clau-mcp rm  [persona] <name>"
      print "  clau-mcp list [persona]"
      ;;
  esac
}
