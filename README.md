# clau — one Claude Code, many hats

Persona launcher for Claude Code. You use Claude Code for everything — but not
everything at once. `clau` gives each kind of work its own **persona**: isolated
skills, plugins, MCP servers and system prompt, switched with one command.

A persona = up to 3 files (any may be absent), resolved repo-local first, then
`~/.claude/personas/`:

| file                 | role          |                                          |
|----------------------|---------------|------------------------------------------|
| `<persona>.json`     | CAPABILITY    | which plugins/skills are on (settings)    |
| `<persona>.mcp.json` | MCP           | which servers it talks to                 |
| `<persona>.md`       | SYSTEM PROMPT | injected on top of repo CLAUDE.md         |

```
clau              → list available personas (+ sidecar & marketplace health)
clau designer     → launch that persona · flags pass through (clau designer -c)
claude            → plain claude, untouched — clau is only for hats
```

## Install

```sh
# 1. the launcher
echo "source $(pwd)/clau.zsh" >> ~/.zshrc

# 2. the statusline (shows ⬢ <persona> in clau sessions)
cp statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
# then in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

# 3. personas — yours to define; see the guide
```

Or don't build it by hand: the guide's **bootstrap section** has a copy-paste
prompt that makes Claude Code set everything up for the repo you're in.

## Docs

- [`docs/index.html`](docs/index.html) — the complete guide (open in a browser)
- [`docs/atlas/`](docs/atlas/) — flow-by-flow alignment atlas (companion; may lag the guide)
- Published: https://teambrilliant.dev/docs/claude-code-personas/ (org) ·
  [public share link](https://teambrilliant.dev/share/lfqAGaoIYSo58n7xIyK40hYrMg/)

## What does NOT belong here

This repo is the **framework**: launcher, statusline, documentation. Your actual
personas (`~/.claude/personas/` — dotfiles), your skills/plugins repos, and
anything credential-adjacent stay in your own private repos. Capability is
yours; this is just the hat rack.
