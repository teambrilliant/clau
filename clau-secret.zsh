clau-secret() {
  emulate -L zsh
  local cmd="$1"; shift 2>/dev/null
  local silent=0
  [[ "$1" == "-q" ]] && { silent=1; shift }
  local name="$1"

  case "$cmd" in
    set)
      [[ -n "$name" ]] || { print -u2 "usage: clau-secret set [-q] <NAME>"; return 1 }
      local -a acl
      (( silent )) || acl=(-T '')
      local value readback rc
      print -n "paste the value for $name, then press enter (input is hidden): "
      IFS= read -rs value; rc=$?
      print ""
      (( rc == 0 )) || { value=""; print -u2 "clau: no value read — nothing stored"; return 1 }
      [[ -n "$value" ]] || { print -u2 "clau: empty value — nothing stored"; return 1 }
      if ! security add-generic-password -U -a "$USER" -s "clau:$name" -l "clau:$name" \
        -D "clau secret" -j "used by clau personas via mcp.json lookup" "${acl[@]}" -w "$value"; then
        print -u2 "clau: failed to store clau:$name"; value=""; return 1
      fi
      readback=$(security find-generic-password -a "$USER" -s "clau:$name" -w 2>/dev/null); rc=$?
      if (( rc != 0 )); then
        print -u2 "clau: stored clau:$name — ${#value} chars, UNVERIFIED (keychain read not approved)"
        print -u2 "      run: clau-secret audit   to confirm the stored length"
        value=""; readback=""; return 1
      fi
      if [[ "$readback" != "$value" ]]; then
        print -u2 "clau: clau:$name is CORRUPT — wrote ${#value} chars, keychain holds ${#readback}"
        print -u2 "      the value was not stored intact; do not rely on it"
        value=""; readback=""; return 1
      fi
      if (( silent )); then
        print "stored clau:$name — ${#value} chars, verified · readable without a prompt"
      else
        print "stored clau:$name — ${#value} chars, verified · every read asks for your approval"
      fi
      value=""; readback=""
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
    audit)
      local sname val bad=0 seen=0
      for sname in ${(f)"$(clau-secret list)"}; do
        [[ -n "$sname" ]] || continue
        seen=1
        if val=$(security find-generic-password -a "$USER" -s "$sname" -w 2>/dev/null); then
          if (( ${#val} == 128 )); then
            printf '  %-34s %5d chars  ⚠ likely truncated — clau-secret set %s\n' "$sname" ${#val} "${sname#clau:}"
            bad=1
          else
            printf '  %-34s %5d chars  ok\n' "$sname" ${#val}
          fi
        else
          printf '  %-34s %5s        unreadable — approval declined\n' "$sname" "?"
        fi
      done
      val=""
      (( seen )) || print "  no clau:* secrets stored"
      return $bad
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
      print "  clau-secret audit             stored length of every secret · flags truncated ones"
      print "  clau-secret get <NAME>        print it (prompts unless stored with -q)"
      print "  clau-secret list              list stored names"
      print "  clau-secret rm <NAME>         delete"
      ;;
  esac
}
