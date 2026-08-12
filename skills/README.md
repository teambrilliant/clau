# Skills

Agent skills that ship with the framework — how to *author* the system, not what
any individual hat does. Personal personas and their capability plugins stay in
your own repos.

| skill          | use it when                                                     |
|----------------|------------------------------------------------------------------|
| `clau-persona` | creating, editing or auditing a hat — layers, MCP, secrets, permissions |

## Install

```sh
ln -s "$(pwd)/skills/clau-persona" ~/.claude/skills/clau-persona
```

A symlink keeps it updating with `git pull`. Copy the directory instead if you
prefer to pin it. Skills in `~/.claude/skills/` are persona-blind — they load in
every hat — so hide it where it isn't wanted with `skillOverrides` in that hat's
`settings.json`:

```json
{ "skillOverrides": { "clau-persona": "off" } }
```
