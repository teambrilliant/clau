_clau_pick() {
  local -a rows; rows=("$@")
  local -i n=${#rows}
  local -a disp paths sel vis order
  local i j p g
  for (( i = 1; i <= n; i++ )); do
    disp[i]="${rows[i]%%$'\t'*}"
    paths[i]="${rows[i]#*$'\t'}"
    sel[i]=0
  done

  local ofd opened=0
  if { true < /dev/tty } 2>/dev/null; then
    exec {ofd}>/dev/tty; opened=1
  else
    exec {ofd}>&2
  fi

  local cur=1 key c1 c2 ind txt box query="" cancelled=0
  local -a readargs
  if (( opened )); then readargs=(-k 1); else readargs=(-k 1 -u 0); fi
  trap 'print -n "\033[?25h" >&$ofd; return 130' INT
  local -i h=$(( n + 3 ))
  printf '\n%.0s' {1..$h} >&$ofd
  print -n "\e[${h}A\e7\e[?25l" >&$ofd

  while true; do
    order=()
    for (( i = 1; i <= n; i++ )); do
      p="${paths[i]}"; vis[i]=0
      [[ "$p" == '#'* ]] && continue
      if [[ -z "$query" || "${p:l}" == *"${query:l}"* ]]; then vis[i]=1; order+=($i); fi
    done
    for (( i = 1; i <= n; i++ )); do
      p="${paths[i]}"
      [[ "$p" == '#'* ]] || continue
      g="${p#\#}"
      for j in $order; do
        if [[ "${paths[j]}" == "$g" || "${paths[j]}" == "$g/"* ]]; then vis[i]=1; break; fi
      done
    done
    (( cur > ${#order} )) && cur=${#order}
    (( cur < 1 )) && cur=1

    print -n $'\e8\e[J' >&$ofd
    {
      print $'\e[2m  ↑↓ move · space toggle · type to search · ⌃u clear · enter launch · ⌃c cancel\e[0m'
      if [[ -n "$query" ]]; then
        print "  \e[38;5;208m/\e[0m${query}\e[2m — ${#order} match\e[0m"
      else
        print ""
      fi
      for (( i = 1; i <= n; i++ )); do
        (( vis[i] )) || continue
        ind="${disp[i]%%[^ ]*}"
        txt="${disp[i]:${#ind}}"
        if [[ "${paths[i]}" == '#'* ]]; then
          print "    ${ind}\e[1;38;5;244m${txt}\e[0m"
        else
          box="☐"; (( sel[i] )) && box=$'\e[38;5;208m☑\e[0m'
          if (( ${#order} && order[cur] == i )); then
            print "  \e[38;5;208m❯\e[0m ${ind}${box} \e[1m${txt}\e[0m"
          else
            print "    ${ind}${box} ${txt}"
          fi
        fi
      done
      (( ${#order} )) || print $'\e[2m    no match\e[0m'
    } >&$ofd

    read $readargs key || { cancelled=1; break }
    case "$key" in
      $'\n'|$'\r') break ;;
      ' ') (( ${#order} )) && sel[${order[cur]}]=$(( 1 - sel[${order[cur]}] )) ;;
      $'\x7f'|$'\b') query="${query%?}"; cur=1 ;;
      $'\x15') query=""; cur=1 ;;
      $'\x0e') (( cur < ${#order} )) && (( cur++ )) ;;
      $'\x10') (( cur > 1 )) && (( cur-- )) ;;
      $'\e')
        c1=""; c2=""
        if ! read -t 0.05 $readargs c1; then
          if [[ -n "$query" ]]; then query=""; cur=1; else cancelled=1; fi
        elif [[ "$c1" == '[' || "$c1" == 'O' ]]; then
          read -t 0.05 $readargs c2
          case "$c2" in
            A) (( cur > 1 )) && (( cur-- )) ;;
            B) (( cur < ${#order} )) && (( cur++ )) ;;
          esac
        else
          case "$c1" in
            $'\n'|$'\r') break ;;
            ' ') (( ${#order} )) && sel[${order[cur]}]=$(( 1 - sel[${order[cur]}] )) ;;
            [[:print:]]) query+="$c1"; cur=1 ;;
          esac
        fi
        (( cancelled )) && break
        ;;
      [[:print:]]) query+="$key"; cur=1 ;;
    esac
  done
  print -n $'\e8\e[J\e[?25h' >&$ofd
  trap - INT
  (( opened )) && exec {ofd}>&-
  (( cancelled )) && return 1

  local -a out_paths
  for (( i = 1; i <= n; i++ )); do
    [[ "${paths[i]}" == '#'* ]] && continue
    (( sel[i] )) && out_paths+=("${paths[i]}")
  done
  (( ${#out_paths} == 0 && ${#order} )) && out_paths=("${paths[${order[cur]}]}")
  (( ${#out_paths} )) || return 1
  print -l -- $out_paths
}

_clau_persona_dir() {
  local name="$1" pdir="$HOME/.claude/personas" d="$PWD" rdir="" k
  while [[ -n "$d" ]]; do
    [[ -d "$d/clau/personas" ]] && { rdir="$d/clau/personas"; break }
    [[ -d "$d/.claude/personas" ]] && { rdir="$d/.claude/personas"; break }
    d="${d:h}"; [[ "$d" == "/" ]] && break
  done
  [[ -z "$rdir" ]] && rdir="/nonexistent/clau/personas"
  [[ -d "$rdir/$name" ]] && { print -r -- "$rdir/$name"; return 0 }
  [[ -d "$pdir/$name" ]] && { print -r -- "$pdir/$name"; return 0 }

  typeset -A pmap
  local root dd rel
  for root in "$pdir" "$rdir"; do
    [[ -d "$root" ]] || continue
    for dd in "$root"/**/*(/N); do
      rel="${dd#$root/}"
      [[ "${dd:t}" == "base" || "$rel" == */base/* ]] && continue
      [[ -f "$dd/settings.json" || -f "$dd/mcp.json" || -f "$dd/persona.md" ]] && pmap[$rel]="$dd"
    done
  done
  local -a cand
  for k in ${(k)pmap}; do [[ "${k:t}" == "$name" ]] && cand+=("$k"); done
  (( ${#cand} == 1 )) && { print -r -- "${pmap[$cand[1]]}"; return 0 }
  (( ${#cand} > 1 )) && { print -u2 "clau: '$name' is ambiguous — ${(j:, :)cand}"; return 1 }
  print -u2 "clau: unknown persona '$name' — run clau -h to list personas"
  return 1
}

_clau_scan() {
  local pdir="$HOME/.claude/personas" d="$PWD" rdir=""
  while [[ -n "$d" ]]; do
    [[ -d "$d/clau/personas" ]] && { rdir="$d/clau/personas"; break }
    [[ -d "$d/.claude/personas" ]] && { rdir="$d/.claude/personas"; break }
    d="${d:h}"; [[ "$d" == "/" ]] && break
  done
  [[ "$rdir" == "$pdir" || -z "$rdir" ]] && rdir="/nonexistent/clau/personas"

  typeset -A pmap
  local root dd rel
  for root in "$pdir" "$rdir"; do
    [[ -d "$root" ]] || continue
    for dd in "$root"/**/*(/N); do
      rel="${dd#$root/}"
      [[ "${dd:t}" == "base" || "$rel" == */base/* ]] && continue
      [[ -f "$dd/settings.json" || -f "$dd/mcp.json" || -f "$dd/persona.md" ]] && pmap[$rel]="$dd"
    done
  done
  for rel in ${(oi)${(k)pmap}}; do print -r -- "$rel"$'\t'"${pmap[$rel]}"; done
}

_clau_rows() {
  typeset -A seenhdr
  local rel dir acc i
  local -a parts
  while IFS=$'\t' read -r rel dir; do
    parts=(${(s:/:)rel}); acc=""
    for (( i = 1; i < ${#parts}; i++ )); do
      [[ -n "$acc" ]] && acc="$acc/$parts[i]" || acc="$parts[i]"
      [[ -n "${seenhdr[$acc]}" ]] && continue
      seenhdr[$acc]=1
      printf '%*s%s\t#%s\n' $(( (i - 1) * 2 )) '' "$parts[i]" "$acc"
    done
    printf '%*s%s\t%s\n' $(( (${#parts} - 1) * 2 )) '' "$parts[-1]" "$rel"
  done < <(_clau_scan)
}

_clau_roots() {
  local pdir="$HOME/.claude/personas" d="$PWD" rdir=""
  while [[ -n "$d" ]]; do
    [[ -d "$d/clau/personas" ]] && { rdir="$d/clau/personas"; break }
    [[ -d "$d/.claude/personas" ]] && { rdir="$d/.claude/personas"; break }
    d="${d:h}"; [[ "$d" == "/" ]] && break
  done
  [[ "$rdir" == "$pdir" || -z "$rdir" ]] && rdir="/nonexistent/clau/personas"
  print -r -- "$rdir"
  print -r -- "$pdir"
}

_clau_color() {
  local n="$1" rdir pdir acc seg out=""
  local -a roots plist
  roots=(${(f)"$(_clau_roots)"})
  rdir="$roots[1]"; pdir="$roots[2]"
  plist=(base); acc=""
  for seg in ${(s:/:)n}; do
    [[ -n "$acc" ]] && acc="$acc/$seg" || acc="$seg"
    [[ "$acc" == "$n" ]] || plist+=("$acc/base")
  done
  plist+=("$n")
  local lp dd
  for lp in $plist; do
    for dd in "$rdir/$lp" "$pdir/$lp"; do
      [[ -f "$dd/color" ]] || continue
      out=$(rg -v '^\s*(#|$)' "$dd/color" 2>/dev/null | head -1 | tr -d '[:space:]')
      break
    done
  done
  print -r -- "$out"
}

_clau_scratch_dir() {
  local pdir="$HOME/.claude/personas"
  local scratch_root="${CLAU_SCRATCH_ROOT:-${${pdir:A}:h}/scratch}"
  local gitcommon proj
  gitcommon=$(git rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$gitcommon" ]]; then proj="${${${gitcommon:A}:h}:t}"; else proj="${PWD:t}"; fi
  print -r -- "$scratch_root/$proj"
}

_clau_pick_personas() {
  local -a rows; rows=(${(f)"$(_clau_rows)"})
  (( ${#rows} )) || { print -u2 "clau: no personas found"; return 1 }
  _clau_pick "${rows[@]}"
}

clau() {
  local pdir="$HOME/.claude/personas"
  local d="$PWD" rdir=""
  while [[ -n "$d" ]]; do
    [[ -d "$d/clau/personas" ]] && { rdir="$d/clau/personas"; break }
    [[ -d "$d/.claude/personas" ]] && { rdir="$d/.claude/personas"; break }
    d="${d:h}"; [[ "$d" == "/" ]] && break
  done
  [[ "$rdir" == "$pdir" || -z "$rdir" ]] && rdir="/nonexistent/clau/personas"

  typeset -A pmap
  local rel dent
  while IFS=$'\t' read -r rel dent; do pmap[$rel]="$dent"; done < <(_clau_scan)

  local -a rows; rows=(${(f)"$(_clau_rows)"})

  if [[ "$1" == "--json" ]]; then
    local jrel jdir jgroup
    {
      while IFS=$'\t' read -r jrel jdir; do
        [[ "$jrel" == */* ]] && jgroup="${jrel%/*}" || jgroup=""
        jq -n \
          --arg path "$jrel" --arg name "${jrel:t}" --arg dir "$jdir" \
          --arg group "$jgroup" --arg color "$(_clau_color "$jrel")" \
          --argjson mcp "$([[ -f "$jdir/mcp.json" ]] && print true || print false)" \
          --argjson env "$([[ -f "$jdir/.env" ]] && print true || print false)" \
          --argjson prompt "$([[ -f "$jdir/persona.md" ]] && print true || print false)" \
          '{path:$path,name:$name,dir:$dir,group:$group,color:$color,hasMcp:$mcp,hasEnv:$env,hasPrompt:$prompt}'
      done < <(_clau_scan)
    } | jq -s --arg cwd "$PWD" --arg local "$rdir" --arg global "$pdir" --arg scratch "$(_clau_scratch_dir)" \
      '{cwd:$cwd, roots:{local:$local, global:$global}, scratch:$scratch, personas:.}'
    return 0
  fi

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print "clau — persona launcher"
    print "  clau                        pick personas · type to search · space toggle · enter launch"
    print "  clau <p> [p…] [flags…]      launch personas merged into one session\n"
    if (( ${#rows} )); then printf '  %s\n' ${rows%%$'\t'*}; else print "  (no personas yet)"; fi
    local b
    print ""
    for b in "$pdir"/**/base(/N) "$rdir"/**/base(/N); do
      print "  base ✓ ${b}"
    done
    local m
    (( ${#pmap} )) && for m in $(cat "${(v)pmap[@]/%//settings.json}"(N) 2>/dev/null | jq -r -s '.[] | .enabledPlugins // {} | keys[] | split("@")[1] // empty' | sort -u); do
      if [[ -d "$HOME/.claude/plugins/marketplaces/$m" ]]; then
        print "  marketplace $m ✓"
      else
        print "  marketplace $m ✗ NOT registered → /plugin marketplace add <path>"
      fi
    done
    return 0
  fi

  local -a picked
  local a k
  while (( $# )); do
    [[ "$1" == -* ]] && break
    a="$1"; shift
    if [[ -n "${pmap[$a]}" ]]; then
      picked+=("$a")
    else
      local -a cand; cand=()
      for k in ${(k)pmap}; do [[ "${k:t}" == "$a" ]] && cand+=("$k"); done
      if (( ${#cand} == 1 )); then
        picked+=("$cand[1]")
      elif (( ${#cand} > 1 )); then
        print -u2 "clau: '$a' is ambiguous — ${(j:, :)cand}"; return 1
      else
        print -u2 "clau: unknown persona '$a' — run clau -h to list personas"; return 1
      fi
    fi
  done

  if (( ${#picked} == 0 )); then
    (( ${#rows} )) || { print -u2 "clau: no personas found"; return 1 }
    picked=(${(f)"$(_clau_pick "${rows[@]}")"})
    (( ${#picked} )) || { print "clau: nothing selected"; return 1 }
  fi

  local -a layers
  local n c
  for n in $picked; do
    layers+=("base")
    acc=""
    for c in ${(s:/:)n}; do
      [[ -n "$acc" ]] && acc="$acc/$c" || acc="$c"
      [[ "$acc" == "$n" ]] || layers+=("$acc/base")
    done
    layers+=("$n")
  done
  layers=(${(u)layers})

  local -a badges plist
  local pn pc pacc pseg pdirx
  for pn in $picked; do
    pc=""
    plist=(base); pacc=""
    for pseg in ${(s:/:)pn}; do
      [[ -n "$pacc" ]] && pacc="$pacc/$pseg" || pacc="$pseg"
      [[ "$pacc" == "$pn" ]] || plist+=("$pacc/base")
    done
    plist+=("$pn")
    for pacc in $plist; do
      for pdirx in "$rdir/$pacc" "$pdir/$pacc"; do
        [[ -f "$pdirx/color" ]] || continue
        pc=$(rg -v '^\s*(#|$)' "$pdirx/color" 2>/dev/null | head -1 | tr -d '[:space:]')
        break
      done
    done
    [[ -z "$pc" ]] && pc='1;38;5;208'
    badges+=("${pc}"$'\t'"${pn:t}")
  done

  local -a args mcp mds sets envs
  local dir
  for p in $layers; do
    dir=""
    [[ -d "$rdir/$p" ]] && dir="$rdir/$p"
    [[ -z "$dir" && -d "$pdir/$p" ]] && dir="$pdir/$p"
    [[ -n "$dir" ]] || continue
    [[ -f "$dir/settings.json" ]] && sets+=("$dir/settings.json")
    [[ -f "$dir/mcp.json" ]] && mcp+=("$dir/mcp.json")
    [[ -f "$dir/persona.md" ]] && mds+=("$dir/persona.md")
    [[ -f "$dir/.env" ]] && envs+=("$dir/.env")
  done

  local tmpd
  if (( ${#sets} == 1 )); then
    args+=(--settings "$sets[1]")
  elif (( ${#sets} > 1 )); then
    tmpd=$(mktemp -d "${TMPDIR:-/tmp}/clau-XXXXXX") || return 1
    jq -s '
      def clean: with_entries(select((.value|type) != "array" or (.value|length) > 0));
      reduce .[] as $s ({};
        . as $a
        | ($a * $s)
        | .enabledPlugins = (
            (($a.enabledPlugins // {}) + ($s.enabledPlugins // {}))
            | with_entries(.value = ((($a.enabledPlugins // {})[.key] // false) or (($s.enabledPlugins // {})[.key] // false)))
          )
        | if ((($a.disabledMcpjsonServers // []) + ($s.disabledMcpjsonServers // [])) | length) > 0
          then .disabledMcpjsonServers = ((($a.disabledMcpjsonServers // []) + ($s.disabledMcpjsonServers // [])) | unique)
          else . end
        | if ((($a.permissions // {}) + ($s.permissions // {})) | length) > 0
          then .permissions = (
              (($a.permissions // {}) * ($s.permissions // {}))
              | .allow = (((($a.permissions // {}).allow // []) + (($s.permissions // {}).allow // [])) | unique)
              | .ask   = (((($a.permissions // {}).ask   // []) + (($s.permissions // {}).ask   // [])) | unique)
              | .deny  = (((($a.permissions // {}).deny  // []) + (($s.permissions // {}).deny  // [])) | unique)
              | clean)
          else . end
        | if (.enabledPlugins | length) == 0 then del(.enabledPlugins) else . end
      )' "${sets[@]}" > "$tmpd/settings.json" || {
        print -u2 "clau: failed to merge persona settings"; rm -rf "$tmpd"; return 1
      }
    args+=(--settings "$tmpd/settings.json")
  fi

  (( ${#mcp} )) && args+=(--mcp-config "${mcp[@]}")

  if (( ${#mds} == 1 )); then
    args+=(--append-system-prompt-file "$mds[1]")
  elif (( ${#mds} > 1 )); then
    [[ -n "$tmpd" ]] || tmpd=$(mktemp -d "${TMPDIR:-/tmp}/clau-XXXXXX") || return 1
    for p in $mds; do cat "$p"; print; done > "$tmpd/persona.md"
    args+=(--append-system-prompt-file "$tmpd/persona.md")
  fi

  local scratch_root="${CLAU_SCRATCH_ROOT:-${${pdir:A}:h}/scratch}"
  local gitcommon proj scratch top ex
  gitcommon=$(git rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$gitcommon" ]]; then proj="${${${gitcommon:A}:h}:t}"; else proj="${PWD:t}"; fi
  scratch="$scratch_root/$proj"
  mkdir -p "$scratch"
  args+=(--add-dir "$scratch")
  top=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$top" && ! -e "$top/.scratch" ]]; then
    ln -s "$scratch" "$top/.scratch" && print "clau: linked .scratch → $scratch"
    ex=$(git rev-parse --git-path info/exclude 2>/dev/null)
    [[ -n "$ex" ]] && { grep -qx '\.scratch' "$ex" 2>/dev/null || print '.scratch' >> "$ex" }
  fi

  local -a names
  typeset -A injected
  local v val
  (( ${#mcp} )) && names=(${(f)"$(cat "${mcp[@]}" | rg -o '\$\{[A-Za-z_][A-Za-z0-9_]*' | sed 's/^\${//' | sort -u)"})
  for v in $names; do
    [[ -n "${(P)v}" ]] && continue
    if val=$(security find-generic-password -a "$USER" -s "clau:$v" -w 2>/dev/null); then
      injected[$v]="$val"
    else
      print -u2 "clau: $v is unset and no keychain item clau:$v — run: clau-secret set $v"
    fi
  done
  val=""

  local ef eline ek ev kname
  for ef in $envs; do
    while IFS= read -r eline || [[ -n "$eline" ]]; do
      [[ -z "${eline// /}" || "$eline" == \#* ]] && continue
      ek="${eline%%=*}"; ev="${eline#*=}"
      if [[ "$ev" == keychain:* ]]; then
        kname="${ev#keychain:}"
        if ! ev=$(security find-generic-password -a "$USER" -s "clau:$kname" -w 2>/dev/null); then
          print -u2 "clau: $ek needs keychain item clau:$kname — run: clau-secret set $kname"
          continue
        fi
      fi
      injected[$ek]="$ev"
    done < "$ef"
  done
  ev=""

  local rc
  (
    for v in ${(k)injected}; do export "$v=${injected[$v]}"; done
    export CLAU_PERSONA="${(j:+:)picked}"
    export CLAU_SCRATCH="$scratch"
    export CLAU_BADGES="${(F)badges}"
    command claude "${args[@]}" "$@"
  )
  rc=$?
  injected=()
  [[ -n "$tmpd" ]] && rm -rf "$tmpd"
  return $rc
}
