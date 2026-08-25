__clau_pick() {
  emulate -L zsh
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

__clau_persona_dir() {
  emulate -L zsh
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

__clau_scan() {
  emulate -L zsh
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

__clau_rows() {
  emulate -L zsh
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
  done < <(__clau_scan)
}

__clau_roots() {
  emulate -L zsh
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

__clau_color() {
  emulate -L zsh
  local n="$1" rdir pdir acc seg out=""
  local -a roots plist
  roots=(${(f)"$(__clau_roots)"})
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

__clau_scratch_dir() {
  emulate -L zsh
  local pdir="$HOME/.claude/personas"
  local scratch_root="${CLAU_SCRATCH_ROOT:-${${pdir:A}:h}/scratch}"
  local gitcommon proj
  gitcommon=$(git rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$gitcommon" ]]; then proj="${${${gitcommon:A}:h}:t}"; else proj="${PWD:t}"; fi
  print -r -- "$scratch_root/$proj"
}

__clau_pick_personas() {
  emulate -L zsh
  [[ -t 0 ]] || { print -u2 "clau: no terminal to pick from — name the persona"; return 1 }
  local -a rows; rows=(${(f)"$(__clau_rows)"})
  (( ${#rows} )) || { print -u2 "clau: no personas found"; return 1 }
  __clau_pick "${rows[@]}"
}

__clau_intro() {
  emulate -L zsh
  local t; IFS= read -r -d '' t <<'TXT' || true
clau — persona launcher for Claude Code

A persona is a directory of up to five files: settings.json (plugins, skills,
permissions) · mcp.json (MCP servers, ${VAR} placeholders only) · persona.md
(appended to the system prompt) · .env (KEY=value or KEY=keychain:NAME) · color
(statusline badge). Personas resolve repo-local first — clau/personas/ walking
up from $PWD — then ~/.claude/personas/. A base/ at any level is a layer every
persona below it inherits. `clau <p>` merges the layers and runs claude with
the result; plain `claude` stays untouched.

Onboarding — in a Claude Code session, say: "onboard clau personas for this
repo: run `clau` and follow it". Without a terminal clau prints this text plus
the authoring skill (`clau skill` any time; `clau skill install` persists it to
.claude/skills/ for later sessions — optional). The agent then:
  1. inventories — `clau -h`, `clau --json`, the repo's .mcp.json and
     .claude/settings*.json — naming env variables, never their values;
  2. writes clau/personas/<hat>/ files, `clau-mcp add <hat> <name> …` for
     servers, ${VAR} placeholders only — `clau-secret set VAR` is your step;
  3. verifies — `clau <hat> --version` resolves every placeholder, starts nothing.

Commands
  clau                              pick hats · without a terminal: this text + the skill
  clau <p> [p…] [claude flags…]     launch hats merged into one session
  clau -h                           this text and the persona tree
  clau --json                       the resolved tree as data
  clau skill [install [--global]]   the authoring skill: stdout, or written to .claude/skills/
  clau-mcp add|rm|list [<p>] …      MCP servers in a hat without hand-editing mcp.json
  clau-secret set|check|audit …     keychain values behind ${VAR} placeholders
TXT
  print -r -- "${t%$'\n'}"
}

__clau_first_run() {
  emulate -L zsh
  local t; IFS= read -r -d '' t <<'TXT' || true
clau — persona launcher for Claude Code · no personas yet

A persona is a directory under clau/personas/ (this repo) or ~/.claude/personas/
holding any of settings.json · mcp.json · persona.md · .env · color; a base/
beside them is a layer every persona inherits.

Let Claude build them — open `claude` in this repo and say:

    onboard clau personas for this repo: run `clau` and follow it

Without a terminal clau prints the model and the authoring skill instead of a
picker, so the agent has everything it needs. By hand: mkdir -p
clau/personas/<hat>, add a settings.json, then `clau -h`.
TXT
  print -r -- "${t%$'\n'}"
}

__clau_skill_frontmatter() {
  emulate -L zsh
  local t; IFS= read -r -d '' t <<'TXT' || true
---
name: clau-persona
description: Create, edit or audit a clau persona (hat) — persona folders with settings.json / mcp.json / persona.md, shared base layers, and keychain-backed secrets. Use when the user says "new persona", "create a hat", "add a clau persona", "persona for X", "add an MCP to my persona", or wants a read-only prod / staging / dev hat.
---
TXT
  print -r -- "${t%$'\n'}"
}

__clau_skill_body() {
  emulate -L zsh
  local t; IFS= read -r -d '' t <<'TXT' || true
# clau persona authoring

`clau` is a zsh launcher that assembles a Claude Code session from persona
folders. `clau-secret` stores the values behind `${VAR}` placeholders in the
keychain (run it bare for usage); `clau-mcp` writes MCP servers into a persona
without hand-editing JSON. This text is `clau skill`; `clau skill install`
writes it to `.claude/skills/clau-persona/` so it triggers in later sessions.

## Where personas live

Resolution walks up from `$PWD` for the first `clau/personas` (or
`.claude/personas`) directory; `~/.claude/personas` is the global fallback. Same
relative path in both → the ancestor one wins, and it replaces the whole folder
rather than merging file by file.

Never assume the tree — read it first:

```
clau -h            # the list, plus base layers and marketplace health
clau --json | jq   # the resolved tree as data: dirs, groups, colors, flags
```

## Anatomy

A persona is a folder holding any of five files. All are optional; the folder is
a persona if `settings.json`, `mcp.json` or `persona.md` exists.

```
personas/
  base/                    ← applies to every persona
    settings.json
    mcp.json
  <group>/
    base/                  ← applies to every persona under <group>
      mcp.json
      persona.md
    <persona>/
      settings.json        ← plugins, permissions, skillOverrides
      mcp.json             ← MCP servers, ${VAR} placeholders only
      persona.md           ← appended to the system prompt at launch
      .env                 ← KEY=value, or KEY=keychain:NAME
      color                ← SGR params for the statusline badge, e.g. 41;1;97
```

`.env` values are exported into the session, so `pnpm` and any command Claude
runs inherit them; `keychain:NAME` resolves at launch. `color` feeds
`CLAU_BADGES` — one `color⇥name` line per active hat — which `statusline.sh`
renders as ` ⬢ <persona> `. Both resolve through the layer chain, most specific
wins.

- Folders named `base` are shared layers: never selectable, applied
  automatically to everything below.
- A folder holding only folders (like `<group>`) is a container: a heading in
  the picker, not launchable.
- Layer order is outermost-first, so the persona itself wins conflicts —
  **except `enabledPlugins`, which merges by OR** (see "Rules that bite").

## Steps

1. **Ask what the hat is for** if it isn't obvious: which project/environment,
   which capabilities it must have, and — critically — what it must *not* be
   able to do.
2. **Inventory before inventing.** Read the target repo's `.mcp.json`,
   `.claude/settings.json` and `.claude/settings.local.json`. Reuse existing
   server definitions rather than writing new ones from memory.
3. **Check available plugins**: `jq -r '.enabledPlugins' ~/.claude/settings.json`
   and `ls ~/.claude/plugins/marketplaces/`. Keys in `enabledPlugins` must be
   exactly `plugin@marketplace` and the marketplace must be registered on this
   machine, or the persona silently degrades.
4. **Decide the layer.** Anything shared by a family of hats goes in
   `<group>/base/`, not copied into each persona. But only put a plugin in a
   base layer if *every* hat below it should have it — a leaf cannot switch it
   back off.
5. **Write the files.** Never a literal secret — `${VAR}` placeholders only.
   Prefer `clau-mcp add <persona> <name> …` over writing `mcp.json` by hand; it
   gets `type` right and can target several hats at once.
6. **Register secrets**: tell the user to run `clau-secret set <VAR>`
   themselves. Never ask for the value, never run `clau-secret get`, never print
   a value.
7. **Verify** (below), then report what the hat can and cannot reach.

## Rules that bite

- **`enabledPlugins` merges by OR across layers.** `false` at the leaf loses to
  `true` in a `base/`. To keep a plugin away from one hat in a family, don't
  enable it in the family's base at all.
- **Merging hats widens permissions.** `permissions.allow` / `ask` / `deny` and
  `disabledMcpjsonServers` all union across a multi-select launch. `deny`
  unioning is safe; `allow` unioning means never pair a read-only hat with a
  read-write one.
- **`disabledMcpjsonServers` is a deny in any settings file.** A repo's
  `.claude/settings.local.json` rejecting a `.mcp.json` server cannot be
  re-enabled by a persona. Declare the server in the persona's own `mcp.json`
  instead.
- **Sidecars are additive.** Local-scope servers (`~/.claude.json`), plugin
  servers and repo servers still load. `--strict-mcp-config` is the only
  hermetic switch.
- **A sidecar server with the same name as a repo one wins**, and that is a
  useful override for pinning an environment.
- **`${VAR}` expansion works in sidecars** (verified), including
  `${VAR:-default}`.
- **`clau` injects keychain values only for names it finds as `${…}` in the
  selected `mcp.json` files**, and only when the variable isn't already set in
  the shell. A `${VAR}` written anywhere else is never resolved and never
  warned about — use `.env` for those.
- **A stored secret can be present and still wrong.** Values written by older
  `clau-secret` versions were cut at 128 characters and reported as stored, so
  `check` says `✓ exists` while the server fails to connect. When an MCP server
  with a `${VAR}` won't connect, have the user run `clau-secret audit` — a
  length of exactly 128 is the fingerprint, and the fix is to `set` it again.
- **`persona.md` files concatenate**, outermost first.
- **`skillOverrides`** hides loose skills per persona: `"off"`,
  `"user-invocable-only"`, `"name-only"`.
- **CLAUDE.md is persona-blind** — per-hat instructions belong in `persona.md`.

## Environment hats

For a production or otherwise dangerous hat, layer the defences:

- the credential is the boundary — a read-only DB role, not just a deny rule;
- `permissions.deny` for the mutating paths (`Bash(psql*)`, `Edit`, `Write`);
- `permissions.ask` for anything that reaches the environment at all;
- a `persona.md` that states the hat investigates and reports rather than fixes;
- a loud `color`, so the statusline says which blast radius is loaded.

## Verification

Dry run — resolves every placeholder and prints warnings for what's missing,
without starting a session:

```
clau <persona> --version
```

Live probe — confirms which MCP servers connect and which skills are actually
present:

```
claude --settings <persona>/settings.json \
  --mcp-config <base>/mcp.json <persona>/mcp.json \
  --append-system-prompt-file <persona>/persona.md \
  -p "say ok" --output-format stream-json --verbose \
  | jq -c 'select(.type=="system" and .mcp_servers!=null)
           | {mcp:[.mcp_servers[]|"\(.name):\(.status)"], skills:.slash_commands}'
```

Report the result honestly: a `failed` server usually means a missing env var,
not a broken persona.
TXT
  print -r -- "${t%$'\n'}"
}

__clau_skill() {
  emulate -L zsh
  local usage="usage: clau skill [install [--global]]"
  (( $# )) || { __clau_skill_body; return 0 }
  [[ "$1" == "install" ]] || { print -u2 "$usage"; return 1 }
  local root
  case "$2" in
    "")          root=$(git rev-parse --show-toplevel 2>/dev/null); root="${root:-$PWD}/.claude" ;;
    --global|-g) root="$HOME/.claude" ;;
    *)           print -u2 "$usage"; return 1 ;;
  esac
  local dir="$root/skills/clau-persona" file content
  file="$dir/SKILL.md"
  content="$(__clau_skill_frontmatter)"$'\n\n'"$(__clau_skill_body)"
  if [[ -f "$file" && "$(<"$file")" == "$content" ]]; then
    print "up to date  ${file/#$HOME/~}"
  else
    mkdir -p "$dir" && print -r -- "$content" > "$file" || return 1
    print "wrote  ${file/#$HOME/~}"
  fi
  print "loads in every hat launched from here · hide it in one with \"skillOverrides\": { \"clau-persona\": \"off\" } in that hat's settings.json"
}


clau() {
  emulate -L zsh
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
  while IFS=$'\t' read -r rel dent; do pmap[$rel]="$dent"; done < <(__clau_scan)

  local -a rows; rows=(${(f)"$(__clau_rows)"})

  if [[ "$1" == "--json" ]]; then
    local jrel jdir jgroup
    {
      while IFS=$'\t' read -r jrel jdir; do
        [[ "$jrel" == */* ]] && jgroup="${jrel%/*}" || jgroup=""
        jq -n \
          --arg path "$jrel" --arg name "${jrel:t}" --arg dir "$jdir" \
          --arg group "$jgroup" --arg color "$(__clau_color "$jrel")" \
          --argjson mcp "$([[ -f "$jdir/mcp.json" ]] && print true || print false)" \
          --argjson env "$([[ -f "$jdir/.env" ]] && print true || print false)" \
          --argjson prompt "$([[ -f "$jdir/persona.md" ]] && print true || print false)" \
          '{path:$path,name:$name,dir:$dir,group:$group,color:$color,hasMcp:$mcp,hasEnv:$env,hasPrompt:$prompt}'
      done < <(__clau_scan)
    } | jq -s --arg cwd "$PWD" --arg local "$rdir" --arg global "$pdir" --arg scratch "$(__clau_scratch_dir)" \
      '{cwd:$cwd, roots:{local:$local, global:$global}, scratch:$scratch, personas:.}'
    return 0
  fi

  if [[ "$1" == "skill" ]]; then shift; __clau_skill "$@"; return $?; fi

  local tty=0; [[ -t 0 ]] && tty=1
  if [[ "$1" == "-h" || "$1" == "--help" ]] || (( $# == 0 && ! tty )); then
    __clau_intro
    print "\nPersonas"
    if (( ${#rows} )); then printf '  %s\n' ${rows%%$'\t'*}; else print "  (none yet)"; fi
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
    if (( $# == 0 )); then
      print "\n── the skill · same text as \`clau skill\` · \`clau skill install\` persists it ──\n"
      __clau_skill_body
    fi
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
    (( tty )) || { print -u2 "clau: no terminal to pick from — name a persona: clau <p> [flags…] · clau -h lists them"; return 1 }
    (( ${#rows} )) || { __clau_first_run; return 1 }
    print $'\e[2mclau — pick the hats for this session; each is a persona directory and the session gets their union · clau -h explains\e[0m'
    picked=(${(f)"$(__clau_pick "${rows[@]}")"})
    (( ${#picked} )) || { print "clau: nothing selected"; return 1 }
  fi

  local -a layers
  local n c acc p
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
