# clau — profiles for Claude Code

One command switches the skills, MCP servers, permissions and instructions Claude Code loads. Per kind of work, per client, per environment. Plain `claude` stays untouched.

**If you are an agent:** install (below), then run `clau` from a shell without a terminal — it prints the model, the persona tree and the authoring skill in one call. `clau skill` prints the skill alone. Never write a secret value into a file; tell the user the `clau-secret set VAR` command instead.

A persona is a **directory**, resolved repo-local first (`clau/personas/`, walking up from `$PWD`), then `~/.claude/personas/`. Every file in it is optional:

| file            | role          |                                             |
| --------------- | ------------- | ------------------------------------------- |
| `settings.json` | capability    | plugins, skills, permissions                |
| `mcp.json`      | MCP           | which servers it talks to                   |
| `persona.md`    | system prompt | appended on top of repo CLAUDE.md           |
| `.env`          | environment   | vars for the session · `keychain:NAME` refs |
| `color`         | statusline    | ANSI SGR code for this hat's badge          |

Directories nest, and a `base/` at any level is a **layer** every persona below it inherits:

```
~/.claude/personas/
  base/              → every persona: shared MCP, house rules
  acme/
    base/            → every acme/* persona
    prod/  stage/  dev/
  docs/
```

```
clau                    → picker · type to search · space toggles · enter launches
                          no terminal on stdin → prints the model + tree + skill
clau prod               → launch by leaf name (unique names resolve on their own)
clau acme/prod docs     → several hats merged into one session
clau prod -c            → flags after the names pass through to claude
clau -h                 → the model + plain list, no picker
clau --json             → the resolved tree as data
clau skill              → the authoring skill (stdout) · `install` writes .claude/skills/
```

## Install

```sh
git clone https://github.com/teambrilliant/clau ~/.claude/clau

# the launcher and its two helpers — clau.zsh first, the others use its helpers
cat >> ~/.zshrc <<'ZSH'
source ~/.claude/clau/clau.zsh
source ~/.claude/clau/clau-secret.zsh
source ~/.claude/clau/clau-mcp.zsh
ZSH

# a coloured badge per active hat
cp ~/.claude/clau/statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
# then in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

# your first hat
mkdir -p clau/personas/prod && clau -h
```

Requires `zsh`, `jq`, `rg`, and `security` (macOS) for the keychain layer. Update with `git -C ~/.claude/clau pull`.

Or let Claude Code do it: in the repo you want hats for, tell a session _"onboard clau personas for this repo: run `clau` and follow it."_

## Tools

| command       | what it does                                                                     |
| ------------- | -------------------------------------------------------------------------------- |
| `clau`        | launch one or more hats                                                          |
| `clau --json` | the resolved tree as JSON — what the Raycast extension reads                     |
| `clau skill`  | the persona-authoring skill on stdout · `install` writes it to `.claude/skills/` |
| `clau-mcp`    | add / remove / list MCP servers inside a hat, without editing JSON               |
| `clau-secret` | keychain store behind the `${VAR}` placeholders — see [SECRETS.md](SECRETS.md)   |

```sh
clau-mcp add acme/prod exa --env 'EXA_API_KEY=${EXA_API_KEY}' -- npx -y exa-mcp-server
clau-mcp add acme/prod linear --transport http https://mcp.linear.app/sse
clau-mcp list acme/prod
clau-mcp rm acme/prod exa
```

Omit the hat name and `clau-mcp` opens the same picker `clau` uses, so one server can be written into several hats at once. It warns when an `--env` value is a literal rather than a `${VAR}` placeholder.

## Docs

- [`docs/guide.md`](docs/guide.md) — the field guide: layers, blast radius, secrets, the plan-then-build handoff, what does and doesn't isolate
- [`SECRETS.md`](SECRETS.md) — keychain-backed `${VAR}` resolution
- [`SECURITY.md`](SECURITY.md) — the trust model for committed personas, and how to report a problem
- [`raycast/`](raycast/) — a Raycast extension over the same tree; it shells out to `clau --json`, so there is no second source of truth
- https://teambrilliant.ai/clau — the overview page

## Scratch

Every launch gets a per-codebase working directory outside the repo, passed to the session via `--add-dir` and exported as `$CLAU_SCRATCH`. It defaults to a `scratch/` sibling of your personas directory and is symlinked into the repo as `.scratch` (added to `.git/info/exclude`, never to a tracked file). Override with `CLAU_SCRATCH_ROOT`.

## Contributing

Shell changes get sandbox-tested: `./test/smoke.zsh` builds a throwaway `$HOME` with a stub `claude`, exercises the launcher end to end, and touches nothing you own. Add a case for anything you change. `raycast/` needs `npx tsc --noEmit`, `npx eslint src` and `npx prettier --check src` green.

This repo is the framework: launcher, statusline, secret helper, docs. Your personas, your skills and every credential stay in your own private repos.

MIT — see [LICENSE](LICENSE).
