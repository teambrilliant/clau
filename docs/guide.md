# clau — the field guide

clau adds profiles to Claude Code. A profile is a **persona** (a hat, in the prose below): a directory that says which plugins, skills, MCP servers, permissions and instructions a session loads. One command launches Claude Code wearing one or more of them. Plain `claude` is untouched.

The [README](../README.md) covers install and the commands. This guide covers how the pieces fit and where they bite.

**If you are an agent reading this:** the facts you need are in [The model](#1-the-model) and [Reference](#10-reference). Once `clau.zsh` is sourced, run `clau` from a shell with no terminal attached (Claude Code's `Bash` tool qualifies): it prints the model, the persona tree and the authoring skill in one call. `clau skill` prints the skill alone; `clau -h` and `clau --json` are the inventory. Never write a secret value into a file. Use `${VAR}` placeholders and tell the user which `clau-secret set VAR` commands to run.

1. [The model](#1-the-model)
2. [Where hats live](#2-where-hats-live)
3. [Layers and merging](#3-layers-and-merging)
4. [Setup, step by step](#4-setup-step-by-step)
5. [Environments as hats](#5-environments-as-hats)
6. [Secrets](#6-secrets)
7. [Plan in one hat, build in another](#7-plan-in-one-hat-build-in-another)
8. [Day to day](#8-day-to-day)
9. [A new hat, end to end](#9-a-new-hat-end-to-end)
10. [Reference](#10-reference)

## 1. The model

You install skills and MCP servers for everything you do: development, marketing, product, experiments. Every session loads all of it. The copy skills from launch week sit in the context of every refactor, the experimental skill leaks into every repo, every MCP server connects whether or not the session could use it. Each addition is reasonable on its own. The sum is a polluted context and a model that has to ignore most of what it was handed.

Claude Code has no profiles feature. 3 mechanisms it already has compose into one:

1. **Plugins are the unit.** A plugin bundles skills, agents, hooks and MCP servers and toggles as one key in `enabledPlugins`. Loose skills work too, per name, via `skillOverrides`.
2. **A persona is a directory.** One folder per hat: `settings.json` for capability, `mcp.json` for servers, `persona.md` for instructions, `.env` and `color` for the rest. The settings file goes in with `--settings`, which outranks every settings file on disk. Folders nest, so hats come in families.
3. **A `base/` is inherited.** Any `base/` folder is a layer every persona beneath it wears. Root `base/` holds house rules and shared servers; `acme/base/` holds what the acme family shares; the leaf holds what only it needs. Launch merges the chain and hands one file to Claude Code.

```
A HAT — ONE DIRECTORY · every file optional
  prod/settings.json   plugins, skills, permissions
  prod/mcp.json        MCP servers · ${VAR} placeholders only
  prod/persona.md      appended to the system prompt, on top of repo CLAUDE.md
  prod/.env            KEY=value or KEY=keychain:NAME · exported into the session
  prod/color           ANSI SGR code for the statusline badge

WHERE HATS LIVE · repo beats global
  ~/.claude/personas/          dotfiles · serves every repo
    base/                      LAYER · every hat
    acme/                      a family, not a hat
      base/                    LAYER · every acme/* hat
      prod/  stage/  dev/      the leaves you launch
    docs/                      a top-level hat

  <repo>/clau/personas/        or .claude/personas/ · found by walking up from $PWD
    prod/                      replaces the global prod/ (the whole folder, not file by file)
    support/                   committed, project-owned

  a folder is a hat when it holds settings.json, mcp.json or persona.md and is not named base

LAUNCH
  $ clau                       picker · type to filter · space toggles · enter launches
  $ clau prod                  base → acme/base → acme/prod, merged, then claude
  $ clau acme/stage docs       2 hats, one session, the union of both
```

## 2. Where hats live

From `$PWD`, `clau` walks up until it finds a `clau/personas/` or `.claude/personas/` directory. That root wins over `~/.claude/personas/`. It is an ancestor walk, not a git lookup, so a plain directory of projects can carry one set of hats for everything beneath it.

- **Committed, shared.** A hat that belongs to the project. Anyone who clones the repo (and has clau plus the marketplace) gets it. Its `mcp.json` carries `${VAR}` placeholders, never values.
- **Committed override.** A repo `designer/` wins over your global `designer/` while you are inside that tree.
- **Gitignored, personal.** Machine-local hats. In repos you don't own, use `.git/info/exclude` so no tracked file changes.

2 rules that bite:

- **The override is the whole folder.** A repo `designer/` holding only `settings.json` does not inherit the global `designer/`'s `mcp.json` or `persona.md`; those stop loading. Copy across what the repo copy still needs. `base/` layers are unaffected; they resolve separately.
- **A committed persona is code someone else wrote.** It can carry `permissions.allow`, `hooks` (shell commands), MCP server commands and an `.env` that is exported into the session. Read it before the first launch in a freshly cloned repo, the way you would read a committed `.mcp.json`. `clau -h` shows what resolves; `clau <hat> --version` is a dry run. See [SECURITY.md](../SECURITY.md).

```
# resolution — clau <name>
1. <first ancestor of $PWD with clau/personas or .claude/personas>/<name>/
2. ~/.claude/personas/<name>/                       ← global fallback

# committed project hat, no secrets
$ cat acme-repo/clau/personas/support/settings.json
{ "enabledPlugins": { "copy-skills@my-marketplace": true } }
$ cat acme-repo/clau/personas/support/mcp.json
{ "mcpServers": { "crm": { …, "env": { "CRM_TOKEN": "${CRM_TOKEN}" } } } }

# personal hat — .gitignore, or .git/info/exclude in repos you don't own
clau/personas/scratchpad/
.scratch
```

## 3. Layers and merging

A folder named `base` is never launchable. It is a layer every persona below it wears. The directory path decides inheritance and nothing else: `clau acme/prod` wears `base`, then `acme/base`, then `acme/prod`. A level without a `base/` contributes nothing.

**Leaf names are enough.** `clau prod` finds `acme/prod` while that leaf name is unique. A second `prod` anywhere in the tree makes `clau` refuse and name both candidates.

**Groups are structure.** `acme/` holds no files and cannot be launched. The picker shows it as a heading.

**Several hats at once.** Name more than one and the session gets the union: every layer of every hat, deduplicated, merged once. The statusline shows one badge per hat.

```
enabledPlugins          OR — true in any layer wins
permissions.allow       union of every layer
permissions.ask         union of every layer
permissions.deny        union of every layer
disabledMcpjsonServers  union of every layer
persona.md              concatenated, root first
.env                    deeper layer overwrites
color                   deepest wins
everything else         deep merge, later layer wins
```

3 consequences:

- **A leaf cannot switch a base layer off.** `"dev-skills": false` in `acme/prod` loses to `"dev-skills": true` in `acme/base`. Inheritance only adds. Keep `base/` layers minimal and enable capability at the leaf. If one hat in a family must not have a plugin, don't enable it in the family's base.
- **Permissions only widen.** `deny` unions, so a base layer's denial survives. `allow` unions too, so merging a permissive hat into a session widens the strict one for that session. Never merge `prod-ro` with anything that can write.
- **Order is fixed.** Root first, leaf last. To reorder, move a directory.

## 4. Setup, step by step

### 4.1 Capability: you probably already have it

Personas toggle what is already installed. Capability comes from marketplaces (`/plugin`) or the skills ecosystem (`npx skills add`). Note each plugin's `plugin@marketplace` name; that is what persona files reference. Loose skills load in every persona by default and each persona hides them with `skillOverrides`. Your own plugins repo is the advanced path; [section 9](#9-a-new-hat-end-to-end) walks through it.

```
> /plugin marketplace add <owner>/<repo>     # once per machine
> /plugin                                    # install · note the plugin@marketplace names
$ npx skills add someone/design-skills       # loose skills, from the ecosystem
```

### 4.2 A directory per hat

`mkdir` is the whole ceremony. `settings.json` says which plugins are on and off (keys exactly as `/plugin` lists them), which loose skills are hidden, plus persona-scoped permissions and suppressed repo MCP servers. Every file is optional: a directory with one `persona.md` in it is a hat.

Hats live in `~/.claude/personas/` (dotfiles), one copy for every repo. Context comes later, in `mcp.json`.

```json
// ~/.claude/personas/marketer/settings.json
{
  "enabledPlugins": {
    "copy-skills@my-marketplace":    true,
    "dev-skills@my-marketplace":     false,
    "product-skills@my-marketplace": false
  },
  "skillOverrides": { "some-loose-skill": "off" },
  "disabledMcpjsonServers": ["postgres-prod-readonly"]
}

// ~/.claude/personas/base/settings.json — worn by every hat
{ "permissions": { "deny": ["Bash(security*)"] } }
```

### 4.3 MCP servers per hat

An `mcp.json` in any layer. Root `base/` loads for every persona (chrome-devtools lives here), a family's `base/` covers that project, the leaf adds what only it needs. They are **additive**: they stack on top of user-level and repo `.mcp.json` servers. Suppress an inherited server with `disabledMcpjsonServers`, or pass `--strict-mcp-config` for a session with only the persona's servers.

Use [`clau-mcp`](../clau-mcp.zsh) rather than editing JSON. It gets the shape right, including `type`, and with no hat named it opens the picker so one server can be written into several hats.

```json
// ~/.claude/personas/product/mcp.json — product hat only
{
  "mcpServers": {
    "posthog": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@posthog/mcp"],
      "env": { "POSTHOG_API_KEY": "${POSTHOG_API_KEY}" }
    }
  }
}
```

```
$ clau-mcp add product posthog --env 'POSTHOG_API_KEY=${POSTHOG_API_KEY}' -- npx -y @posthog/mcp
$ clau-mcp add product linear --transport http https://mcp.linear.app/sse
$ clau-mcp add exa …                 # no hat named → picker, write to many
$ clau-mcp list product
$ clau-mcp rm product exa
```

### 4.4 The launcher

[`clau.zsh`](../clau.zsh) defines the picker, the tree scanner and `clau`. Source it before [`clau-secret.zsh`](../clau-secret.zsh) and [`clau-mcp.zsh`](../clau-mcp.zsh), which use its helpers. Needs `zsh`, `jq`, `rg`; the keychain calls use macOS `security`.

| command | does |
|---|---|
| `clau` | picker over the tree. With no terminal on stdin (a pipe, an agent's shell) it prints the model, the tree and the authoring skill instead; with no personas at all it prints the prompt to hand an agent |
| `clau <hat> [hat…] [flags]` | merges the layer chain of every named hat with `jq`, stacks the `mcp.json` files, concatenates `persona.md`, resolves `${VAR}`, creates the scratch directory, runs `claude`. Flags after the names pass through: `clau designer -c` |
| `clau -h` | the model, the plain list, and a check that every `plugin@marketplace` key resolves on this machine |
| `clau --json` | the resolved tree as data. Launches nothing. The [Raycast extension](../raycast/) reads it |
| `clau skill [install [--global]]` | the persona-authoring skill on stdout, or written to `.claude/skills/clau-persona/` so it triggers by itself in later sessions. The text lives inside `clau.zsh` |

The session gets `CLAU_PERSONA`, `CLAU_BADGES` and `CLAU_SCRATCH` in the child process only. Your shell stays clean.

Every function opens with `emulate -L zsh` and helpers are named `__clau_*`, because Claude Code's `Bash` tool runs zsh with `NO_BARE_GLOB_QUAL` and drops single-underscore functions from its snapshot. The [smoke test](../test/smoke.zsh) runs the launcher under those conditions.

### 4.5 Statusline

[`statusline.sh`](../statusline.sh) reads the session JSON Claude Code pipes to it plus `CLAU_BADGES`, one `colour⇥name` line per active hat, and prints one badge each. The colour is a `color` file in the hat's directory: a raw SGR sequence, so `48;5;196;1;97` is bold white on red. A family's `base/` colour is inherited; the most specific wins; no colour anywhere falls back to orange. Bare `claude` shows model and directory, no badge.

```
# ~/.claude/personas/acme/prod/color
48;5;196;1;97

# ~/.claude/settings.json
{ "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

# ⬢ prod  ⬢ docs  · Opus 5 · acme-repo
```

### 4.6 Scratch

Agents produce debris: exports, query results, screenshots, throwaway scripts. Every launch gets a per-codebase directory outside the repo, passed in with `--add-dir` and exported as `$CLAU_SCRATCH`. Default: a `scratch/` sibling of your personas directory (`CLAU_SCRATCH_ROOT` overrides), keyed by the git common dir so worktrees share one. It is symlinked into the repo root as `.scratch`, and `.scratch` is added to `.git/info/exclude`, never to `.gitignore`.

The directory alone changes nothing. Tell the hat to use it, in the root `base/persona.md`:

```markdown
# working files

`$CLAU_SCRATCH` is a per-codebase directory outside the repo, also reachable as `.scratch/` from the repo root. It is not in git.

- Put working files there: exports, dumps, query results, screenshots, throwaway scripts, notes.
- Put files in the repo only when they are meant to be committed. Ask before adding to a tracked directory.
- Prefer `.scratch/<topic>/` over a flat dump, and say where a file landed.
```

### 4.7 Verify

```
$ clau -h                      # what can this machine launch? marketplace ✓?
$ clau product --version       # dry run: resolves every ${VAR}, warns, launches nothing
$ clau product                 # then inside the session:
> /plugin                      # product-skills ✓ · dev-skills ✗
> /mcp                         # chrome-devtools + posthog (+ inherited repo servers)
> /skills                      # no dev or design commands
```

`enabledPlugins` via `--settings` is tested: it wins over `~/.claude/settings.json` per key in both directions. It only toggles plugins that are installed; enabling an uninstalled one does nothing until `claude plugin install` runs.

## 5. Environments as hats

Staging and production are different postures. Model them as one family: shared debug skills in `acme/base/`, a different `mcp.json` and permission layer per environment. Which blast radius a session holds is decided at launch, shown in the statusline all session, and cannot drift.

Both hats declare the same servers; only the `${VAR}` names differ. Non-server variables go in the hat's `.env`, where `keychain:NAME` resolves like a placeholder, so two hats can hand the same variable name two different secrets. Give the dangerous hat a red `color`.

```
# acme/stage/mcp.json                       # acme/prod/mcp.json
"env": { "DATABASE_URL": "${STAGING_DB_URL}" }   "env": { "DATABASE_URL": "${PROD_DB_URL_RO}" }

# acme/prod/.env
JIRA_SITE=acme.atlassian.net
JIRA_API_TOKEN=keychain:ACME_JIRA_PROD

# no secrets on disk at all — 1Password injects for one process tree:
$ op run --env-file=prod.env -- clau acme/prod
```

**Read-only and read-write are different hats.** `prod-ro` uses a read-only database role; the credential is the boundary and the deny list is the second layer. `prod-rw` holds the write credential and asks before every mutating tool. Treat `prod-rw` like sudo: launched for one mutation, closed after. `prod-ro` is the reflex.

```
# acme/prod-ro/settings.json
{ "permissions": { "deny": ["Bash(psql*)", "mcp__postgres__execute_sql"] },
  "disabledMcpjsonServers": ["postgres-prod-readonly"] }

# acme/prod-rw/settings.json
{ "permissions": { "ask": ["mcp__postgres__*", "Bash"] } }

# acme/base/settings.json — the shared debug plugin, once
{ "enabledPlugins": { "debug-skills@my-marketplace": true } }

$ clau prod-ro                          # reflexive
$ clau prod-rw --strict-mcp-config      # deliberate, short-lived
$ clau prod-ro prod-rw                  # never: allow-lists union
```

Crossing from `prod-ro` to `prod-rw` mid-investigation does not mean re-explaining it. The conversation resumes into the bigger hat ([section 7](#7-plan-in-one-hat-build-in-another)).

## 6. Secrets

Persona files hold placeholders only. `${PROD_DB_URL_RO}` is a name; the value lives in the macOS login keychain as `clau:PROD_DB_URL_RO` and is handed to one child process at launch. [SECRETS.md](../SECRETS.md) is the reference, [`clau-secret.zsh`](../clau-secret.zsh) the tool.

Resolution, per `${NAME}` found in the selected layers' `mcp.json`:

1. Already set in your shell: that value wins, keychain untouched. This is what keeps `op run` and direnv working.
2. Otherwise `clau:NAME` from the keychain.
3. Neither: a warning naming the exact fix, the launch continues, that one server fails.

Everything resolved is exported inside a subshell around `claude`. Your interactive shell never holds the value. `.env` files in a layer work the same way for what isn't an MCP server; `keychain:NAME` resolves identically, anything else is literal.

```
$ clau-secret set PROD_DB_URL_RO         # hidden input · reads back and compares before saying "stored"
$ clau-secret set -q EXA_API_KEY         # low-stakes: never prompt on read
$ clau-secret check PROD_DB_URL_RO       # exists? never prompts
$ clau-secret list                       # the only inventory that exists
$ clau-secret audit                      # stored lengths · flags values truncated by old versions

$ clau acme/prod --version               # dry run: warnings, then a version
$ print $PROD_DB_URL_RO                  # empty — it only ever existed in the child
```

How the helper behaves, and why:

- `set` reads the value itself, hidden, hands it to `security`, then reads it back and compares. Success is reported only when the stored bytes match. A mismatch or a declined read-back is a non-zero exit.
- Never pass a value as an argument; it would land in shell history. The value does spend one call in `security`'s `argv`, visible to `ps` for the same user. That is the price of not using `security`'s own prompt, which silently cut every value at 128 bytes.
- By default the keychain item's ACL is locked, so macOS asks on every read, including the verification read. Tick "Always Allow", or store with `-q`, when the prompt is only friction.
- These items never appear in Passwords.app and never sync. `clau-secret list` is the only inventory, which is why the `clau:NAME` convention matters.

Linux: swap the two `security find-generic-password` calls in `clau.zsh` for `secret-tool lookup` or `pass`. Nothing else changes.

## 7. Plan in one hat, build in another

Wear hats in sequence over one conversation. Explore the codebase and write the plan in a hat that cannot reach production, then hand the finished thread to a hat that can, without re-briefing it. A conversation is a file on disk; capability is decided at launch. They are independent.

1. **Explore**: `clau planner`. Read the repo, run the research skills. No prod `mcp.json`, no write credential.
2. **Shape**: same session. Tradeoffs argued in-thread, plan written to `thoughts/plans/`. The reasoning, and the options you rejected, stay in the conversation.
3. **Exit**: `ctrl-d`. The thread is a transcript under `~/.claude/projects/`, keyed by directory. Nothing in it records which hat wrote it.
4. **Relaunch**: `clau builder -c --fork-session`. Same thread, new capability: write tools, the staging hat's servers, builder instructions.
5. **Build**: it opens holding the whole investigation and its own plan. You type "implement it".

Claude Code stores every conversation by working directory: `~/.claude/projects/<cwd-slug>/<session-id>.jsonl`. It has no concept of a persona, so any hat can pick up any thread started in that repo. `clau <persona>` decides capability; `-c` / `--resume` decides the conversation. Flags go after the persona name and pass straight through, which is also how plan mode stacks on top of a read-only hat.

`-c` means the most recent conversation in this directory. Anything run in the repo in between, a quick question or another persona, becomes the most recent one. Use `--resume` when in doubt; `-r <term>` prefilters the picker.

```
$ clau planner --permission-mode plan   # capability, fixed at launch
# …explore, argue, write thoughts/plans/rate-limit.md, ctrl-d

$ clau builder -c --fork-session        # the reflex: same thread, new hat, original untouched
$ clau builder --resume                 # interactive picker
$ clau builder -r "rate limit"          # picker, prefiltered
$ clau builder -r 3f9c8b21-… --fork-session   # a second attempt off the same clean plan
$ clau prod-rw -r 3f9c8b21-… --fork-session --strict-mcp-config
```

**Fork, don't consume.** `--fork-session` writes the continuation under a new session id and leaves the original transcript intact. Without it the resume consumes the thread: planning and execution become one growing conversation. With it the plan session is a reusable base: fork it again when execution goes sideways, or fork it twice and run `builder` and `prod-ro` from the same plan in parallel terminals.

What crosses the relaunch and what is re-decided:

| layer | across the relaunch |
|---|---|
| conversation, files read, the plan and its reasoning | carries; it is the transcript |
| plugins and skills | re-decided by `enabledPlugins` in the new persona |
| MCP servers | re-decided by the new hats' `mcp.json`; old servers' output stays in history as text |
| permissions | re-decided; the new rules apply from the first tool call |
| `persona.md` instructions | re-decided; the new chain, still on top of the same repo CLAUDE.md |
| `CLAU_PERSONA` and statusline | re-decided from the new launch |

2 traps: **context doesn't shrink.** The forked thread still holds everything the planning hat read, including MCP output. A persona gates what a session can do, never what it already knows. If the next hat must not see something, start clean and point it at the plan file. And **it remembers tools it no longer has.** A resumed conversation may reach for a skill or server from the previous hat. Open the new session with a concrete instruction naming the plan file.

## 8. Day to day

**Experiments stay in a sandbox.** A new skill, written or pulled with `npx skills add`, goes in `plugins/sandbox-skills/`, never in `~/.claude/skills/` where it would load everywhere. `"sandbox-skills@my-marketplace": true` lives in `play/settings.json` and in no `base/`. Trial it with `clau play`, editing in place and `/reload-plugins` to retry. A survivor is `git mv`'d into the real plugin; a failure is a deleted directory.

Skills from the ecosystem, by commitment: `npx skills use` runs one once without installing; `npx skills add --copy` inside the plugins repo, then `git mv` into the sandbox plugin, quarantines it to `clau play`; promoting it from sandbox into `ui-skills` ships it with the designer persona in every repo. Bare `npx skills add` drops loose skills into `.claude/skills/` (or `~/.claude/skills/` with `-g`), which every persona sees.

```
$ npx skills use someone/design-skills@polish-ui                       # taste
$ cd ~/dev/claude-code-plugins && npx skills add someone/design-skills --copy -a claude -y
$ git mv .claude/skills/polish-ui plugins/sandbox-skills/skills/polish-ui   # trial
$ git mv plugins/sandbox-skills/skills/polish-ui plugins/ui-skills/skills/polish-ui   # keep
```

**Raycast.** `clau --json` is the resolved tree as data, and the [Raycast extension](../raycast/) sits on it: pick a folder and hats, resume a past session in a different hat (with or without `--fork-session`), add an MCP server to several hats, store a secret, choose the terminal. Folders come from `zoxide`, VS Code's recent workspaces and `~/.claude.json`. It shells out to the same `clau`, so there is no second source of truth.

```
$ clau --json | jq '.personas[] | {path, dir, color, hasMcp}'
$ cd raycast && npm install && npm run dev      # finds clau via $CLAU_HOME → ~/.zshrc.d → ~/.claude → ~/.config/clau
```

**Short moves.**

- Flip a plugin mid-session: `/plugin`, then `/reload-plugins`.
- Resume in a different hat: exit, `clau builder -c --fork-session`.
- Add a hat: one plugin, one line in the marketplace manifest, one directory. `clau researcher` works in every repo at once.
- Onboard a machine: clone the plugins repo, install dotfiles, then the 2 steps git cannot carry: `/plugin marketplace add ~/dev/claude-code-plugins` and `clau-secret set …` per name. `clau -h` shows the marketplace ✓.
- Point a hat at one more server: `clau-mcp add product linear --transport http https://mcp.linear.app/sse`.
- Audit a hat before trusting it with production: `clau-mcp list acme/prod`, `clau-secret list`, `clau acme/prod --version`.

## 9. A new hat, end to end

A "researcher" hat with its own skill and its own MCP server: 2 files in a plugins repo that doubles as a personal marketplace, 2 in dotfiles, none in any project repo.

```
# 1 · the skill, inside a new plugin (plugins repo)
$ cd ~/dev/claude-code-plugins
$ mkdir -p plugins/research-skills/{.claude-plugin,skills/deep-dive}
$ cat > plugins/research-skills/.claude-plugin/plugin.json <<'JSON'
{ "name": "research-skills", "version": "0.1.0",
  "description": "Everything the researcher persona knows how to do" }
JSON
$ cat > plugins/research-skills/skills/deep-dive/SKILL.md <<'MD'
---
name: deep-dive
description: Produce a structured research brief on a topic. Use when asked to "research X", "deep dive", or "compare sources".
---
1. Clarify the question and success criteria.
2. Search broadly, then read the 3 strongest sources.
3. Return: findings · disagreements · open questions · sources.
MD

# 2 · the marketplace manifest (.claude-plugin/marketplace.json, created once)
{ "name": "my-marketplace", "owner": { "name": "you" },
  "plugins": [ { "name": "research-skills", "source": "./plugins/research-skills" } ] }
$ git add -A && git commit -m "research-skills plugin"

# 3 · the hat (dotfiles)
$ mkdir -p ~/.claude/personas/researcher
$ cat > ~/.claude/personas/researcher/settings.json <<'JSON'
{ "enabledPlugins": { "research-skills@my-marketplace": true, "dev-skills@my-marketplace": false } }
JSON

# 4 · its MCP server, seen by this hat only
$ clau-secret set -q EXA_API_KEY
$ clau-mcp add researcher exa --env 'EXA_API_KEY=${EXA_API_KEY}' -- npx -y exa-mcp-server
$ print 'Answer with sources or say you could not find any.' > ~/.claude/personas/researcher/persona.md
$ print '48;5;25;1;97' > ~/.claude/personas/researcher/color

# 5 · register the marketplace once per machine, then launch anywhere
> /plugin marketplace add ~/dev/claude-code-plugins
$ clau -h                    # researcher · marketplace my-marketplace ✓
$ clau researcher
```

The `description:` frontmatter is what makes Claude invoke the skill. Write it as what it does plus when to use it.

**Or let the skill do it.** `clau skill` is the same knowledge packaged for Claude Code. In a session say "run `clau` and follow it", or `clau skill install` once and ask for "a read-only prod hat for this repo". It reads the repo's existing `.mcp.json` and settings before inventing servers, checks that every `plugin@marketplace` key resolves on this machine, decides which layer a thing belongs in, and picks the defences for an environment hat: read-only credential first, deny rules second, a `persona.md` that says investigate, don't fix, a loud colour. It writes `${VAR}` placeholders and hands you the `clau-secret set` commands; it never asks for, reads or prints a value. An installed skill is persona-blind; hide it in a hat with `"skillOverrides": { "clau-persona": "off" }`.

**Don't know the hats yet?** Have the agent propose the split from what the repo actually contains: 3 variations at different granularities, each with its tradeoff, and a recommendation. Pick one, edit it, then say "build it".

```
Read this repo's README and docs/guide.md (github.com/teambrilliant/clau), then look at THIS repository and propose how to split the work here into personas:

1. Inventory before proposing: the stack and its scripts (package.json / pyproject / go.mod: dev, test, migrate), services (docker-compose, .env.example), deploy and infra targets, CI, e2e setup, monorepo layout, any existing .claude/ or .mcp.json. Then what this machine has: /plugin marketplace list, ~/.claude/plugins/, ~/.claude/settings.json. Name env variables, never echo their values.

2. Propose 3 variations, deliberately different in granularity: 2 hats (build + prod-ro) · one hat per workflow phase (plan → build → review) · one hat per surface (frontend / backend / data / infra). For each: the persona list as a directory tree (which base/ layers hold what, which hats are worth wearing together), what each hat can and cannot touch, its MCP servers and permission rules, and the switching friction.

3. Ground every hat in something you found: name the file, script or server. Drop any hat this repo does not justify. Never invent MCP servers that are not installed here; mark anything I would have to install first, and anything global that should move into a persona.

4. Recommend one, say what would make me switch later, and which hat to add first when the repo grows.

Then stop and wait. I will pick before you write any files.
```

Start small: personas in the repo under `clau/personas/`, the 3 zsh files as the only global change. Move personas into dotfiles once you want them in every repo.

## 10. Reference

### Settings precedence

The persona slot sits above every file on disk; only CLI flags and managed policy outrank it. `clau` reduces every `settings.json` on the layer chain into one temp file and passes that, so Claude Code sees one settings source.

| layer | rank | role |
|---|---|---|
| CLI flags (`--model`, `--mcp-config`, …) | highest | the launcher's assembled flags |
| managed org policy | · | unused in a solo setup |
| `--settings` file | · | **the persona**: `enabledPlugins`, permissions, hooks, model, env |
| `.claude/settings.local.json` | · | machine-local tweaks for all personas in a repo |
| `.claude/settings.json` | · | team baseline |
| `~/.claude/settings.json` | lowest | keep experiments disabled here; personas opt in |

### Where capability comes from

Keep the layers you cannot control nearly empty; put everything else in plugins.

| source | scope | persona lever |
|---|---|---|
| project `.claude/` | skills in `.claude/skills/`, servers in `.mcp.json`; loads for every persona | `skillOverrides` hides skills; `disabledMcpjsonServers` suppresses servers |
| user `~/.claude/` | loose skills, user-scope servers, user-enabled plugins; the weakest isolation point | `skillOverrides` one name at a time. Real fix: move loose skills into plugins |
| plugins | skills + agents + hooks + bundled MCP, all-or-nothing per plugin | `enabledPlugins`; `/plugin` + `/reload-plugins` mid-session |
| persona `mcp.json` | one file per layer, stacked root first, `${VAR}` resolved at launch | `--mcp-config` stacks them; `--strict-mcp-config` makes them the only source |
| bundled | built-in skills and core tools, present everywhere | none; a same-named skill in any layer above shadows a bundled one |

### What does not isolate

- **CLAUDE.md is persona-blind.** Repo and user CLAUDE.md load for every persona. Per-persona instructions go in `persona.md`.
- **Loose skills leak.** Everything in `~/.claude/skills/` appears in all personas. Hide per persona with `skillOverrides`, or package into plugins.
- **Sidecars add, they don't replace.** User-level and repo `.mcp.json` servers still load. Suppress one with `disabledMcpjsonServers`; for only yours, `--strict-mcp-config`.
- **Inheritance only adds.** A leaf cannot switch off what its `base/` switched on ([section 3](#3-layers-and-merging)).
- **A repo hat replaces the whole folder.** A repo-local `designer/` with only `settings.json` shadows the global `designer/` entirely ([section 2](#2-where-hats-live)).
- **Merging hats widens permissions.** `allow` unions across everything launched together. Never merge `prod-ro` with anything that can write.
- **Marketplace add is per machine.** Without `/plugin marketplace add`, every `plugin@marketplace` key resolves to nothing and the persona silently degrades. `clau -h` flags it.
- **Plugin MCP is all-or-nothing.** To have a plugin's skills without its servers, split the servers into their own plugin.
- **A stored secret can exist and still be wrong.** Older `clau-secret` versions cut values at 128 characters; `check` says it exists while the server fails to connect. `clau-secret audit` flags a length of exactly 128; `set` again is the fix.
