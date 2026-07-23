# clau — persona launcher for Claude Code

Framework + docs only. Personal personas/skills live in dotfiles and private
repos — never commit them here.

## Source of truth & sync rules

- `docs/index.html` is canonical. `clau.zsh` and `statusline.sh` are extractions
  of its code blocks — **any change to one must land in both**, and shell changes
  get sandbox-tested before shipping (fake $HOME + stub `claude` binary; exercise:
  bare list, launch, repo-override, .md injection, unknown persona).
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

## Status

- `enabledPlugins` via `--settings` is documented but not yet live-tested — the
  guide's "first flight" step is the test.
- `docs/atlas/` lags the guide (predates: bare-clau-lists, `.md` sidecars,
  marketplace-optional). Read `docs/atlas/CLAUDE.md` before editing atlas maps.
