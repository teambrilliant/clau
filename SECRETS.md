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
clau-secret audit            stored length of every secret · flags truncated ones
clau-secret get   <NAME>     print the value
clau-secret rm    <NAME>     delete
```

Update = `set` again with the same name. Never pass a value as an argument to
`clau-secret`; that puts it in your shell history.

## Length and verification

`set` reads the value itself with `read -rs`, passes it to `security` as
`-w <value>`, then reads it straight back and compares. Only a byte-identical
round-trip prints success, and the message carries the length:

```
stored clau:NEON_PROD_DATABASE_URL — 163 chars, verified · every read asks for your approval
```

Anything else is an error with a non-zero exit — a mismatch (`CORRUPT — wrote N
chars, keychain holds M`) or a read-back you declined (`UNVERIFIED`). There is
no quiet "stored".

Two consequences worth knowing:

- The verification read hits the same locked ACL as any other read, so a default
  `set` shows **one approval dialog immediately after you paste**. `set -q`
  verifies silently.
- The value spends one call inside `security`'s `argv`, visible to `ps` for the
  same user. That is deliberate: `security`'s own input prompt cut every value at
  128 bytes and reported success anyway, so a long connection string or JWT was
  stored corrupt and only surfaced days later as a server that wouldn't connect.

**Secrets stored before this behaviour existed may already be truncated.** The
fingerprint is a stored length of exactly 128. `clau-secret audit` reads every
`clau:*` value and flags them; the missing bytes are unrecoverable, so re-`set`
anything it names. `check` deliberately does not read the value, so it stays
prompt-free — it answers existence only.

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
