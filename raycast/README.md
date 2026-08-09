# clau for Raycast

Launch personas without a terminal in front of you. Five commands, all reading
the same persona tree `clau` reads — there is no second source of truth.

| command             | what it does                                                        |
|---------------------|---------------------------------------------------------------------|
| **Clau**            | pick a folder, then one or more hats, and launch in your terminal    |
| **Clau Resume**     | pick a past session in a folder, then the hat to resume it in        |
| **Clau MCP Add**    | add an MCP server to one or more hats (wraps `clau-mcp add`)         |
| **Clau Secret**     | store a `clau:<NAME>` value in the login keychain                    |
| **Clau Config**     | choose which terminal app launches                                   |

## How it reads your personas

`clau --json` prints the resolved tree — every hat, its directory, its group,
its inherited colour, and whether it carries `mcp.json` / `.env` / `persona.md`
— for the folder it runs in. The extension shells out to that, so repo-local
hats and `base/` inheritance behave exactly as they do on the command line.

The folder list is merged from `zoxide`, VS Code's recent workspaces, and the
projects recorded in `~/.claude.json`, ranked with recent VS Code folders first.

Sessions come from `~/.claude/projects/<cwd-slug>/*.jsonl`, previewed by their
first user message. **Resume** offers both `--resume` and
`--resume --fork-session`, so the plan thread survives.

## Install

```sh
git clone <this repo> && cd raycast
npm install
npm run dev        # Raycast picks the extension up while this runs
```

The extension needs the zsh files sourced from a directory it can find. It
checks, in order: `$CLAU_HOME`, `~/.zshrc.d`, `~/.claude`, `~/.config/clau` —
the first one containing `clau.zsh` wins. Set `CLAU_HOME` if yours lives
somewhere else.

The launching terminal defaults to the first installed of Ghostty, iTerm,
Terminal, WezTerm, kitty; **Clau Config** changes it and stores the choice in
`~/.config/clau/raycast.json`.

## Notes

- Multi-select in the hat list mirrors the CLI picker — <kbd>⌘T</kbd> toggles,
  the primary action launches everything selected as one merged session.
- **Clau Secret** writes through `/usr/bin/security` with the value piped on
  stdin, never as an argument, and defaults to an ACL that prompts on every
  read. It is the same store `clau-secret` uses.
- **Clau MCP Add** takes `${VAR}` placeholders in its env field; the values are
  resolved from the keychain at launch, not written into `mcp.json`.
