---
name: clau-persona
description: Create, edit or audit a clau persona (hat) — persona folders with settings.json / mcp.json / persona.md, shared base layers, and keychain-backed secrets. Use when the user says "new persona", "create a hat", "add a clau persona", "persona for X", "add an MCP to my persona", or wants a read-only prod / staging / dev hat.
---

# clau persona authoring

`clau` is a zsh launcher that assembles a Claude Code session from persona
folders. `clau-secret` stores the values behind `${VAR}` placeholders;
`clau-mcp` writes MCP servers into a persona without hand-editing JSON. Secrets
are documented in the repo's `SECRETS.md`.

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
