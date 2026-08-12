clau-secret() {
  local cmd="$1"; shift 2>/dev/null
  local silent=0
  [[ "$1" == "-q" ]] && { silent=1; shift }
  local name="$1"

  case "$cmd" in
    set)
      [[ -n "$name" ]] || { print -u2 "usage: clau-secret set [-q] <NAME>"; return 1 }
      local -a acl
      (( silent )) || acl=(-T '')
      print "paste the value for $name, then press enter (input is hidden):"
      security add-generic-password -U -a "$USER" -s "clau:$name" -l "clau:$name" \
        -D "clau secret" -j "used by clau personas via mcp.json lookup" "${acl[@]}" -w || return 1
      if (( silent )); then
        print "stored clau:$name — readable without a prompt"
      else
        print "stored clau:$name — every read asks for your approval"
      fi
      ;;
    get)
      [[ -n "$name" ]] || { print -u2 "usage: clau-secret get <NAME>"; return 1 }
      security find-generic-password -a "$USER" -s "clau:$name" -w
      ;;
    check)
      [[ -n "$name" ]] || { print -u2 "usage: clau-secret check <NAME>"; return 1 }
      if security find-generic-password -a "$USER" -s "clau:$name" >/dev/null 2>&1; then
        print "clau:$name ✓ exists"
      else
        print "clau:$name ✗ missing"; return 1
      fi
      ;;
    list)
      security dump-keychain 2>/dev/null | rg -o '"svce"<blob>="clau:[^"]+"' | sed 's/.*="clau:/clau:/;s/"$//' | sort -u
      ;;
    rm)
      [[ -n "$name" ]] || { print -u2 "usage: clau-secret rm <NAME>"; return 1 }
      security delete-generic-password -a "$USER" -s "clau:$name" >/dev/null 2>&1 && print "removed clau:$name"
      ;;
    *)
      print "clau-secret — keychain store for clau personas"
      print "  clau-secret set [-q] <NAME>   store a value (hidden input · -q = no prompt on read)"
      print "  clau-secret check <NAME>      does it exist"
      print "  clau-secret get <NAME>        print it (prompts unless stored with -q)"
      print "  clau-secret list              list stored names"
      print "  clau-secret rm <NAME>         delete"
      ;;
  esac
}
