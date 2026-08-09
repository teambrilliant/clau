# clau — one Claude Code, many hats

Persona launcher for Claude Code. You use Claude Code for everything — but not
everything at once. `clau` gives each kind of work its own **persona**: isolated
skills, plugins, MCP servers, permissions and system prompt, switched with one
command.

A persona is a **directory**, resolved repo-local first, then
`~/.claude/personas/`. Every file in it is optional:

| file            | role          |                                            |
|-----------------|---------------|--------------------------------------------|
| `settings.json` | CAPABILITY    | plugins, skills, permissions                |
| `mcp.json`      | MCP           | which servers it talks to                   |
| `persona.md`    | SYSTEM PROMPT | appended on top of repo CLAUDE.md           |
| `.env`          | ENVIRONMENT   | vars for the session · `keychain:NAME` refs |
| `color`         | STATUSLINE    | ANSI SGR code for this hat's badge          |

Directories nest, and a `base/` at any level is a **layer** every persona below
it inherits:

```
~/.claude/personas/
  base/              → every persona: shared MCP, house rules
  acme/
    base/            → every acme/* persona
    prod/  stage/  dev/
  notion/
```

```
clau                    → interactive picker · type to search · space toggles
clau prod               → launch by leaf name (unique names resolve on their own)
clau acme/prod notion   → several hats merged into one session
clau prod -c            → flags after the names pass through to claude
clau -h                 → plain list, no picker
claude                  → plain claude, untouched — clau is only for hats
```

## Tools

| command       | what it does                                                       |
|---------------|--------------------------------------------------------------------|
| `clau`        | launch one or more hats                                             |
| `clau --json` | the resolved tree as JSON — what the Raycast app reads              |
| `clau-mcp`    | add / remove / list MCP servers inside a hat, without editing JSON   |
| `clau-secret` | keychain store behind the `${VAR}` placeholders — see [SECRETS.md](SECRETS.md) |

```sh
clau-mcp add acme/prod exa --env 'EXA_API_KEY=${EXA_API_KEY}' -- npx -y exa-mcp-server
clau-mcp add acme/prod linear --transport http https://mcp.linear.app/sse
clau-mcp list acme/prod
clau-mcp rm acme/prod exa
```

Omit the hat name and `clau-mcp` opens the same picker `clau` uses — so one
server can be written into several hats at once. It warns when an `--env` value
is a literal rather than a `${VAR}` placeholder.

## Install

```sh
# 1. the launcher and its two helpers
echo "source $(pwd)/clau.zsh"        >> ~/.zshrc   # must come first
echo "source $(pwd)/clau-secret.zsh" >> ~/.zshrc
echo "source $(pwd)/clau-mcp.zsh"    >> ~/.zshrc

# 2. the statusline (shows a coloured ⬢ badge per active hat)
cp statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
# then in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

# 3. personas — yours to define; see the guide
mkdir -p ~/.claude/personas/base
```

Requires `zsh`, `jq`, `rg`, and `security` (macOS) for the keychain layer.

Or don't build it by hand: the guide's **bootstrap section** has a copy-paste
prompt that makes Claude Code set everything up for the repo you're in.

## Skill

[`skills/clau-persona`](skills/clau-persona/) teaches Claude Code to author hats
— where they live, which layer a thing belongs in, the merge rules that bite,
and how to verify one without leaking a secret. Symlink it into
`~/.claude/skills/` and ask for "a read-only prod persona for this repo". See
[`skills/README.md`](skills/README.md).

## Raycast

[`raycast/`](raycast/) is a Raycast extension over the same tree: pick a folder,
pick hats, launch — plus resuming a past session in a different hat, adding an
MCP server, and storing a secret. It shells out to `clau --json`, so there is no
second source of truth. See [`raycast/README.md`](raycast/README.md).

## Scratch

Every launch gets a per-codebase working directory outside the repo, passed to
the session via `--add-dir` and exported as `$CLAU_SCRATCH`. It defaults to a
`scratch/` sibling of your personas directory, and is symlinked into the repo as
`.scratch` (added to `.git/info/exclude`, never to a tracked file). Override
with `CLAU_SCRATCH_ROOT`.

## Docs

- [`docs/index.html`](docs/index.html) — the complete guide (open in a browser)
- [`SECRETS.md`](SECRETS.md) — keychain-backed `${VAR}` resolution
- [`docs/atlas/`](docs/atlas/) — flow-by-flow alignment atlas (companion; lags the guide)
- Published: https://teambrilliant.dev/docs/claude-code-personas/ (org) ·
  [public share link](https://teambrilliant.dev/share/lfqAGaoIYSo58n7xIyK40hYrMg/)

## What does NOT belong here

This repo is the **framework**: launcher, statusline, secret helper,
documentation. Your actual personas (`~/.claude/personas/` — dotfiles), your
skills/plugins repos, and every credential stay in your own private repos.
Capability is yours; this is just the hat rack.
