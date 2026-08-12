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
local o p acc dir n f

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
source "$R/clau.zsh"
source "$R/clau-mcp.zsh"

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
p=KEEP_P; acc=KEEP_ACC; dir=KEEP_DIR; n=KEEP_N; f=KEEP_F
clau acme/prod >/dev/null 2>&1
ok "\$p survives"                 "$p"   "KEEP_P"
ok "\$acc survives"               "$acc" "KEEP_ACC"
ok "\$dir survives"               "$dir" "KEEP_DIR"
ok "\$n survives"                 "$n"   "KEEP_N"
ok "\$f survives"                 "$f"   "KEEP_F"

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

print "\n$pass passed, $fail failed"
cd /
rm -rf "$T"
exit $(( fail > 0 ))
