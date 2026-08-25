#!/bin/zsh -f
# clau smoke test — fake $HOME + stub `claude` on PATH, real persona tree on disk.
# Nothing outside the temp dir is touched and no real session is ever launched.
#
#   ./test/smoke.zsh            # test the files in this repo
#   ./test/smoke.zsh ~/.claude  # test an installed copy
#
# Never exercise the bare-`clau` picker here — it blocks on the TTY.

emulate -L zsh
local R="${1:-${0:A:h:h}}"
local T; T=$(mktemp -d) || exit 1
local -i pass=0 fail=0
local o p acc dir n f tty rc V200 VQ

ok(){ if [[ "$2" == *"$3"* ]]; then print "  ✓ $1"; (( pass++ )); else
      print "  ✗ $1\n      want: $3\n      got:  ${2//$'\n'/ | }"; (( fail++ )); fi }
no(){ if [[ "$2" != *"$3"* ]]; then print "  ✓ $1"; (( pass++ )); else
      print "  ✗ $1 (unexpected: $3)"; (( fail++ )); fi }
is(){ if [[ -n "$2" ]]; then print "  ✓ $1"; (( pass++ )); else print "  ✗ $1"; (( fail++ )); fi }

# ── fixture ────────────────────────────────────────────────────────────
mkdir -p "$T/home/.claude/personas" "$T/bin" "$T/proj"
cat > "$T/bin/claude" <<'EOF'
#!/bin/sh
printf 'ARGS:'; for a in "$@"; do printf ' [%s]' "$a"; done; printf '\n'
printf 'PERSONA=%s\nBADGES=%s\n' "$CLAU_PERSONA" "$CLAU_BADGES"
printf 'TOKEN=%s FROM_ENV=%s\n' "$MY_TOKEN" "$FROM_ENV"
for a in "$@"; do case "$a" in
  *settings.json) [ -f "$a" ] && { printf 'SETTINGS='; tr -d ' \n' < "$a"; printf '\n'; };;
  *persona.md)    [ -f "$a" ] && { printf 'PROMPT='; tr '\n' '/' < "$a"; printf '\n'; };;
esac; done
EOF
chmod +x "$T/bin/claude"

# stub `security` — a keychain made of files under $SECSTORE. Never touches a real
# one. Records a bare `-w` (the value coming from security's own TTY prompt, the
# bug) so the suite can prove clau-secret passes the value itself.
#   SECSTUB_APPROVE=1   read a locked item, as if you clicked Allow
#   SECSTUB_TRUNCATE=N  store only the first N chars, as if the write corrupted
mkdir -p "$T/sec"
cat > "$T/bin/security" <<'EOF'
#!/bin/sh
s="$SECSTORE"; cmd="$1"; shift
svc=''; val=''; wflag=0; interactive=0; locked=0
case "$cmd" in
  add-generic-password)
    while [ $# -gt 0 ]; do case "$1" in
      -s) svc="$2"; shift 2 ;;
      -a|-l|-D|-j) shift 2 ;;
      -T) locked=1; shift 2 ;;
      -w) if [ $# -ge 2 ]; then val="$2"; shift 2; else interactive=1; shift; fi ;;
      *) shift ;;
    esac; done
    if [ "$interactive" -eq 1 ]; then echo "$svc" >> "$s/.interactive"; val=INTERACTIVE; fi
    [ -n "$SECSTUB_TRUNCATE" ] && val=$(printf '%s' "$val" | cut -c1-"$SECSTUB_TRUNCATE")
    printf '%s' "$val" > "$s/$svc"
    if [ "$locked" -eq 1 ]; then : > "$s/$svc.locked"; else rm -f "$s/$svc.locked"; fi
    exit 0 ;;
  find-generic-password)
    while [ $# -gt 0 ]; do case "$1" in
      -s) svc="$2"; shift 2 ;;
      -a) shift 2 ;;
      -w) wflag=1; shift ;;
      *) shift ;;
    esac; done
    [ -f "$s/$svc" ] || exit 44
    if [ "$wflag" -eq 1 ]; then
      [ -f "$s/$svc.locked" ] && [ "$SECSTUB_APPROVE" != 1 ] && exit 128
      cat "$s/$svc"; echo
    fi
    exit 0 ;;
  delete-generic-password)
    while [ $# -gt 0 ]; do case "$1" in -s) svc="$2"; shift 2 ;; *) shift ;; esac; done
    [ -f "$s/$svc" ] || exit 44
    rm -f "$s/$svc" "$s/$svc.locked"; exit 0 ;;
  dump-keychain)
    for f in "$s"/clau:*; do
      [ -f "$f" ] || continue
      case "$f" in *.locked) continue ;; esac
      printf '    "svce"<blob>="%s"\n' "${f##*/}"
    done
    exit 0 ;;
esac
exit 1
EOF
chmod +x "$T/bin/security"

local P="$T/home/.claude/personas"
mkdir -p "$P/base" "$P/acme/base" "$P/acme/prod" "$P/acme/dev" "$P/other/prod"
print '{"permissions":{"allow":["Bash(git *)"]}}'                         > "$P/base/settings.json"
print '{"enabledPlugins":{"dev@mp":true},"permissions":{"ask":["Bash"]}}' > "$P/acme/base/settings.json"
print '{"permissions":{"deny":["Bash(psql*)"]}}'                          > "$P/acme/prod/settings.json"
print '{"enabledPlugins":{"ui@mp":true}}'                                 > "$P/acme/dev/settings.json"
print '{}'                                                                > "$P/other/prod/settings.json"
print '{"mcpServers":{"pg":{"command":"x","env":{"U":"${MY_TOKEN}"}}}}'   > "$P/acme/prod/mcp.json"
print 'FROM_ENV=hello'                                                    > "$P/acme/prod/.env"
print 'PROD' > "$P/acme/prod/persona.md"
print 'DEV'  > "$P/acme/dev/persona.md"
print '48;5;196' > "$P/acme/prod/color"

cd "$T/proj" || exit 1
git init -q .
mkdir -p clau/personas/repoonly
print '{"enabledPlugins":{"repo@mp":true}}'   > clau/personas/repoonly/settings.json
print '{"mcpServers":{"loc":{"command":"z"}}}' > clau/personas/repoonly/mcp.json

export HOME="$T/home" PATH="$T/bin:/opt/homebrew/bin:/usr/bin:/bin" MY_TOKEN=tok
export SECSTORE="$T/sec"
source "$R/clau.zsh"
source "$R/clau-mcp.zsh"
source "$R/clau-secret.zsh"

# ── listing & discovery ────────────────────────────────────────────────
print "\nlisting & discovery"
o=$(clau -h)
ok "-h lists the tree"            "$o" "    prod"
ok "-h sees repo personas"        "$o" "repoonly"
ok "-h reports base layers"       "$o" "base ✓"
o=$(clau --json | jq -r '.personas[]|.path' | tr '\n' ' ')
ok "--json lists every persona"   "$o" "acme/dev acme/prod other/prod repoonly"
o=$(clau --json | jq -r '.personas[]|select(.path=="acme/prod")|"\(.color)|\(.hasMcp)\(.hasEnv)\(.hasPrompt)"')
ok "--json per-persona shape"     "$o" "48;5;196|truetruetrue"

# ── onboarding: no terminal on stdin → model + tree + skill, never a launch ──
print "\nonboarding"
o=$(clau </dev/null 2>&1); rc=$?
ok "no-tty bare prints the model"   "$o" "persona launcher for Claude Code"
ok "no-tty bare lists the tree"     "$o" "repoonly"
ok "no-tty bare appends the skill"  "$o" "## Rules that bite"
no "no-tty bare never launches"     "$o" "ARGS:"
is "no-tty bare exits 0"            "$([[ $rc -eq 0 ]] && print y)"
o=$(clau -c </dev/null 2>&1); rc=$?
ok "no-tty flags-only refuses"      "$o" "no terminal to pick from"
no "no-tty flags-only never launches" "$o" "ARGS:"
is "no-tty flags-only exits 1"      "$([[ $rc -ne 0 ]] && print y)"
o=$(clau acme/dev </dev/null 2>&1); ok "no-tty named hat launches" "$o" "PERSONA=acme/dev"
o=$(clau -h </dev/null)
ok "-h explains the model"          "$o" "Onboarding"
no "-h omits the skill body"        "$o" "## Rules that bite"
o=$(clau skill)
ok "skill prints the body"          "$o" "# clau persona authoring"
no "skill body has no frontmatter"  "$o" "name: clau-persona"
o=$(clau skill install 2>&1);       ok "skill install writes"   "$o" "wrote"
f="$T/proj/.claude/skills/clau-persona/SKILL.md"
is "skill lands in repo .claude"    "$([[ -f "$f" ]] && print y)"
ok "installed skill has frontmatter" "$(head -2 "$f")" "name: clau-persona"
ok "installed skill has the body"   "$(<"$f")" "## Rules that bite"
o=$(clau skill install 2>&1);       ok "skill install is idempotent" "$o" "up to date"
o=$(clau skill install --global 2>&1)
is "skill --global lands in ~/.claude" "$([[ -f "$T/home/.claude/skills/clau-persona/SKILL.md" ]] && print y)"
o=$(clau skill bogus 2>&1); rc=$?;  ok "skill rejects unknown verbs" "$o" "usage: clau skill"
is "skill unknown verb exits 1"     "$([[ $rc -ne 0 ]] && print y)"
o=$(clau-mcp add foo -- x </dev/null 2>&1); ok "clau-mcp picker refuses without a terminal" "$o" "no terminal to pick from"

# ── caller options: Claude Code's shell runs with NO_BARE_GLOB_QUAL ─────
print "\ncaller options"
o=$( setopt nobareglobqual ksharrays shwordsplit; clau -h 2>&1 )
no "hostile opts: no bad pattern"     "$o" "bad pattern"
ok "hostile opts: -h lists the tree"  "$o" "    prod"
o=$( setopt nobareglobqual ksharrays shwordsplit; clau acme/prod 2>&1 )
ok "hostile opts: launch merges"      "$o" '"deny":["Bash(psql*)"]'
ok "hostile opts: badge resolves"     "$o" "BADGES=48;5;196"
o=$( setopt nobareglobqual ksharrays shwordsplit; clau </dev/null 2>&1 )
ok "hostile opts: onboarding prints"  "$o" "## Rules that bite"
no "hostile opts: onboarding clean"   "$o" "bad pattern"
o=$( setopt nobareglobqual ksharrays shwordsplit; clau-mcp list 2>&1 )
ok "hostile opts: clau-mcp list"      "$o" "repoonly"

# ── naming ─────────────────────────────────────────────────────────────
print "\nnaming"
o=$(clau nope 2>&1);      ok "unknown name errors"      "$o" "unknown persona"
o=$(clau prod 2>&1);      ok "ambiguous leaf errors"    "$o" "is ambiguous"
o=$(clau dev 2>&1);       ok "unique leaf shorthand"    "$o" "PERSONA=acme/dev"

# ── launch & merge ─────────────────────────────────────────────────────
print "\nlaunch & merge"
o=$(clau acme/prod 2>&1)
ok "root base merged"             "$o" '"allow":["Bash(git*)"]'
ok "family base merged"           "$o" '"ask":["Bash"]'
ok "leaf deny applied"            "$o" '"deny":["Bash(psql*)"]'
ok "plugin inherited from base"   "$o" '"dev@mp":true'
ok "mcp sidecar passed"           "$o" "acme/prod/mcp.json"
ok "persona.md passed"            "$o" "PROMPT=PROD/"
ok "\${VAR} resolved from shell"  "$o" "TOKEN=tok"
ok ".env injected"                "$o" "FROM_ENV=hello"
ok "badge carries hat colour"     "$o" "BADGES=48;5;196"
ok "scratch dir added"            "$o" "--add-dir"
o=$(clau acme/prod acme/dev 2>&1)
ok "multi-hat persona var"        "$o" "PERSONA=acme/prod+acme/dev"
ok "multi-hat plugin union"       "$o" '"ui@mp":true'
ok "multi-hat prompt concat"      "$o" "PROMPT=PROD//DEV/"
o=$(clau repoonly 2>&1)
ok "repo persona launches"        "$o" "PERSONA=repoonly"
ok "repo persona settings"        "$o" '"repo@mp":true'
is ".scratch symlinked"           "$([[ -L $T/proj/.scratch ]] && print y)"
ok ".scratch git-excluded"        "$(<"$T/proj/.git/info/exclude")" ".scratch"

# ── shell hygiene: launching must not clobber caller variables ─────────
print "\nshell hygiene"
p=KEEP_P; acc=KEEP_ACC; dir=KEEP_DIR; n=KEEP_N; f=KEEP_F; tty=KEEP_TTY
clau acme/prod >/dev/null 2>&1
ok "\$p survives"                 "$p"   "KEEP_P"
ok "\$acc survives"               "$acc" "KEEP_ACC"
ok "\$dir survives"               "$dir" "KEEP_DIR"
ok "\$n survives"                 "$n"   "KEEP_N"
ok "\$f survives"                 "$f"   "KEEP_F"
ok "\$tty survives"               "$tty" "KEEP_TTY"

# ── clau-mcp ───────────────────────────────────────────────────────────
print "\nclau-mcp"
o=$(clau-mcp list)
ok "list spans global personas"   "$o" "acme/prod"
ok "list spans repo personas"     "$o" "repoonly"
o=$(clau-mcp list acme/prod);            ok "list one persona"  "$o" "pg  stdio  x"
o=$(clau-mcp add acme/dev exa --env "K=\${TOK}" -- npx -y exa 2>&1)
ok "add echoes the server"        "$o" '"command": "npx"'
o=$(clau-mcp list acme/dev);             ok "add persisted"     "$o" "exa  stdio  npx"
o=$(clau-mcp rm acme/dev exa 2>&1);      ok "rm reports"        "$o" "removed exa"
o=$(clau-mcp list acme/dev);             no "rm persisted"      "$o" "exa"

# ── clau-secret: the value must reach `security` intact, and be read back ──
print "\nclau-secret"
V200=$(printf 'x%.0s' {1..200})
VQ='p@ss w"or\d$X`!#%^&*()[]{}|;:<>,.?/=+-'

o=$(print -r -- "$V200" | clau-secret set -q LONG 2>&1)
ok "200-char store verified"      "$o" "200 chars, verified"
is "200 chars stored intact"      "$([[ "$(<"$T/sec/clau:LONG")" == "$V200" ]] && print y)"
no "set prints no value"          "$o" "xxxxxxxxxxxxxxxxxxxx"
print -r -- "$VQ" | clau-secret set -q TRICKY >/dev/null 2>&1
is "metacharacters survive"       "$([[ "$(<"$T/sec/clau:TRICKY")" == "$VQ" ]] && print y)"
is "security never interactive"   "$([[ ! -e "$T/sec/.interactive" ]] && print y)"

o=$(print -r -- "eleven-char" | SECSTUB_APPROVE=1 clau-secret set LOCKED 2>&1)
ok "locked store verified"        "$o" "11 chars, verified · every read asks"
o=$(print -r -- "unapproved" | clau-secret set LOCKED2 2>&1); rc=$?
ok "declined read-back warns"     "$o" "UNVERIFIED"
is "declined read-back exits 1"   "$([[ $rc -ne 0 ]] && print y)"
o=$(print -r -- "$V200" | SECSTUB_TRUNCATE=128 clau-secret set -q CUT 2>&1); rc=$?
ok "truncated write is caught"    "$o" "CORRUPT — wrote 200 chars, keychain holds 128"
is "truncated write exits 1"      "$([[ $rc -ne 0 ]] && print y)"
o=$(print -r -- "" | clau-secret set -q EMPTY 2>&1); rc=$?
ok "empty value refused"          "$o" "empty value"
is "empty value exits 1"          "$([[ $rc -ne 0 ]] && print y)"

o=$(clau-secret check LOCKED 2>&1)
ok "check stays prompt-free"      "$o" "clau:LOCKED ✓ exists"
o=$(clau-secret check NOPE 2>&1); ok "check reports missing" "$o" "✗ missing"

o=$(clau-secret audit 2>&1)
ok "audit flags locked as unread" "$o" "unreadable — approval declined"
o=$(SECSTUB_APPROVE=1 clau-secret audit 2>&1); rc=$?
ok "audit fingerprints 128 chars" "$o" "clau:CUT"
ok "audit names the re-store"     "$o" "likely truncated — clau-secret set CUT"
ok "audit passes a good value"    "$o" "200 chars  ok"
no "audit prints no values"       "$o" "xxxxxxxxxxxxxxxxxxxx"
is "audit exits 1 on truncation"  "$([[ $rc -ne 0 ]] && print y)"

o=$(clau-secret list)
ok "list spans stored secrets"    "$o" "clau:LONG"
o=$(clau-secret rm LONG 2>&1);    ok "rm reports"        "$o" "removed clau:LONG"
o=$(clau-secret list);            no "rm persisted"      "$o" "clau:LONG"

print "\n$pass passed, $fail failed"
cd /
rm -rf "$T"
exit $(( fail > 0 ))
