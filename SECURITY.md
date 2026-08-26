# Security

## What clau does with your machine

`clau` is a zsh function. It reads persona directories, merges their `settings.json` with `jq` into a temp file, and runs the `claude` you already have with `--settings`, `--mcp-config`, `--append-system-prompt-file` and `--add-dir`. It writes nothing outside `$TMPDIR` except a `.scratch` symlink in the repo root (and that path in `.git/info/exclude`). Secret values come from the macOS keychain (`security`) or your shell, are exported inside a subshell around `claude`, and never reach your interactive shell.

## A committed persona is code someone else wrote

`clau` walks up from `$PWD` and treats the first `clau/personas/` or `.claude/personas/` it finds as a persona root. A persona there can carry:

- `settings.json` — `permissions.allow`, `enabledPlugins`, and `hooks`, which run shell commands;
- `mcp.json` — MCP server definitions, i.e. commands that will be executed;
- `.env` — variables exported into the session, including ones like `PATH` or `ANTHROPIC_BASE_URL`;
- `persona.md` — text appended to the system prompt.

Claude Code's own workspace-trust prompt covers a repo's `.claude/settings.json` and asks before using a repo's `.mcp.json`. It does not cover files clau passes explicitly. So: **read a repo's `clau/personas/` before the first launch in a freshly cloned repo**, the same way you would read its `.mcp.json`. `clau -h` lists which hats resolve and where each `base/` layer comes from; `clau --json` gives the directory of every hat; `clau <hat> --version` is a dry run that resolves everything and launches nothing.

Merging hats unions `permissions.allow`, so never launch a read-only hat together with one that can write.

## Secrets

Persona files hold `${VAR}` placeholders, never values. `clau-secret set NAME` stores a value in the login keychain as `clau:NAME`, reads it back and compares before reporting success, and refuses values passed as arguments (they would land in shell history). The value is briefly visible in `security`'s `argv` to processes of the same user — a deliberate trade against `security`'s own prompt, which silently truncated at 128 bytes. `clau-secret audit` finds values truncated by older versions.

## Reporting

Email alex@teambrilliant.ai. Please do not open a public issue for anything that could expose a user's credentials or execute code on their machine.
