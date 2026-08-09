# Secrets in clau personas

`mcp.json` files never hold secret values — only `${VAR}` placeholders. Values
live in the macOS login keychain as `clau:<VAR>` and are injected into the
`claude` child process at launch.

The helper is `clau-secret.zsh`; resolution happens inside `clau.zsh`.

## Commands

```
clau-secret set  <NAME>      store or update · hidden input · every read needs approval
clau-secret set -q <NAME>    same, but reads never prompt
clau-secret list             stored names, no prompts
clau-secret check <NAME>     ✓ exists / ✗ missing, no prompts
clau-secret get   <NAME>     print the value
clau-secret rm    <NAME>     delete
```

Update = `set` again with the same name. Never pass a value as an argument; the
prompt keeps it out of argv and shell history.

## How resolution works

At launch `clau` scans the selected layers' `mcp.json` for `${NAME}`
placeholders, then for each name:

1. Already set in the shell → that value is used, keychain untouched.
2. Otherwise `clau:<NAME>` is read from the keychain.
3. Neither → warning naming the fix, launch continues, that server fails.

Values are exported inside a subshell wrapping `claude`, so the parent shell
stays clean.

## Per-persona `.env`

A layer may carry an `.env` file for non-MCP variables — the ones a skill or a
`Bash` command needs, not a server. Same directory as `settings.json`, one
`KEY=value` per line. A value of `keychain:NAME` is resolved from the keychain
exactly like an `mcp.json` placeholder, so secrets still never touch disk:

```
JIRA_SITE=example.atlassian.net
JIRA_API_TOKEN=keychain:JIRA_API_TOKEN
```

Layers apply in order (`base` → `<group>/base` → the persona), so a leaf `.env`
overrides a base one key by key.

## Testing

```
clau <persona> --version    dry run: warns about unresolved placeholders, then prints a version
clau <persona>              real launch · /mcp should show the server connected
print $JIRA_API_TOKEN       empty after the session exits
```

## Notes

- Items live in the local login keychain. They do not appear in Passwords.app,
  do not sync to other devices, and macOS 26 ships no keychain GUI —
  `clau-secret list` is the only inventory.
- Default ACL is locked, so macOS asks for approval on each read. Tick "Always
  Allow" in the dialog, or re-store with `-q`, to stop the prompts.
- A secret injected this way is present in the session's environment, so a
  `Bash` tool call inside that session can read it. Denying `Bash(security*)` in
  your `base` persona is a speed bump; the keychain prompt is the real gate.
- macOS only — `security` is the backing store. On Linux, replace the two
  `security find-generic-password` calls in `clau.zsh` with `secret-tool lookup`
  or `pass`.
