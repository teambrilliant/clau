# clau — persona launcher for Claude Code

Framework + docs only. Personal personas/skills live in dotfiles and private
repos — never commit them here.

## Source of truth & sync rules

- `docs/index.html` is canonical and carries the **full source** of `clau.zsh`,
  `clau-mcp.zsh`, `clau-secret.zsh` and `statusline.sh` in its code blocks —
  the bootstrap prompt tells Claude to install from the page, so a shell change
  that doesn't land in both leaves the page unable to bootstrap itself. After
  editing a shell file, re-embed it rather than hand-patching the HTML, and
  diff embedded-vs-disk before shipping.
- Shell changes get sandbox-tested first (fake `$HOME` + stub `claude` on
  `PATH`; exercise: `-h` list, single launch, leaf-name shorthand, layer merge,
  repo override, persona.md concatenation, scratch + `.scratch` symlink,
  `${VAR}`/`.env` resolution, multi-persona merge, unknown + ambiguous names,
  statusline badges, `clau-mcp` add/list/rm). Never exercise the bare-`clau`
  picker in a non-interactive test — it blocks on the TTY.
- Published to Dossier as `docs/claude-code-personas` (same URL across versions):
  `bun <tap-skills dossier-publish>/scripts/dossier.ts republish docs/claude-code-personas docs/index.html`
  The bootstrap prompt inside the page hardcodes the public share URL — if the
  share link is ever revoked/re-minted, update the prompt.
- Prompt changes (the bootstrap section) get explicit approval before republish.

## Writing conventions (docs/index.html)

- Terminology: **"persona"** for anything typed or configured (code, flags, file
  names, mechanism prose); **"hat"** only as flavor (title, headings, slogans).
- Page is fully self-contained (inline CSS/JS/SVG; Google Fonts degrade offline).
- Sections alternate `band` / `band deep`; verify in a browser after edits with a
  hard reload (`file://` caches), check console + TOC anchors.

## Secrets

- No credential values, ever — `mcp.json` examples carry `${VAR}` placeholders
  only. `SECRETS.md` documents the keychain layer; `clau-secret.zsh` is tooling,
  not a store.
- Real persona trees are private. Examples in the docs use `acme/` as the
  stand-in project family — never a real client or project name.

## Status

- `enabledPlugins` via `--settings` is documented but not yet live-tested — the
  guide's "first flight" step is the test.
- `enabledPlugins` merges by OR across layers, so a leaf cannot switch off a
  plugin its `base/` enabled. Documented as a trap in "the layers"; revisit if
  it turns out to bite in practice.
- `docs/atlas/` lags the guide badly — it predates persona directories, layers,
  the picker, multi-persona sessions, secrets and scratch. Read
  `docs/atlas/CLAUDE.md` before editing atlas maps.
