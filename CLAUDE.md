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
- Shell changes get sandbox-tested first: **`./test/smoke.zsh`** (fake `$HOME` +
  stub `claude` on `PATH`, temp persona tree, nothing outside `$TMPDIR`
  touched). It covers `-h` list, `--json` shape, leaf-name shorthand, unknown +
  ambiguous names, layer merge, repo override, persona.md concatenation,
  scratch + `.scratch` symlink, `${VAR}`/`.env` resolution, multi-persona merge,
  badge colours, caller-variable hygiene, `clau-mcp` add/list/rm, and the
  no-terminal paths: bare `clau` with stdin redirected (model + tree + skill,
  never a launch), flags-only refusal, `skill` / `skill install` /
  `--global`. Add a case for anything you change; it must stay green. Never
  exercise the bare-`clau` picker there — it blocks on the TTY — and the human
  first-run guide (terminal + no personas) needs a pty, so it is untested.
- The launcher is sourced into an interactive shell, so it must not clobber the
  caller's variables: every loop variable in `clau()` needs a `local`. The
  "shell hygiene" block in the smoke test guards this. Every function also
  opens with `emulate -L zsh`: the caller's options are not ours — Claude
  Code's Bash tool runs zsh with `NO_BARE_GLOB_QUAL` (and no `extendedglob`),
  where every `(/N)` qualifier is a "bad pattern" — and the "caller options"
  smoke block runs the launcher under exactly those. Note `clau` is *not*
  `no_unset`-clean (assoc-array probes like `pmap[$a]`), so don't run the suite
  under `setopt no_unset`.
- Helpers are `__clau_*` — double underscore, deliberately. Claude Code's Bash
  tool loads functions from a shell snapshot that drops `^_[^_]` names as
  completion functions, so a `_clau_*` helper vanishes inside an agent's shell
  and `clau -h` / `--json` break there. The smoke test sources the file
  directly and cannot catch this — check `type __clau_scan` from a Claude Code
  session if in doubt.
- `clau --json` is a **public contract**: `raycast/src/lib/personas.ts` types
  it field for field. Changing a key means changing that type in the same
  commit, and the JSON path must never launch anything.
- The persona-authoring skill is the heredoc in `__clau_skill_body` inside
  `clau.zsh` — `clau skill` prints it, `clau skill install` writes
  `.claude/skills/clau-persona/SKILL.md`; there is no `skills/` directory. It
  documents the same mechanics as the guide — layer resolution, merge rules,
  secret handling — so a behaviour change lands in both. The text must stay
  self-contained and path-agnostic (no `~/.zshrc.d`, no personal tree, no
  "see the repo's X" — an agent reads it with nothing else in context; it
  reads `clau -h` / `clau --json` instead).
- `raycast/` is a real Raycast extension — `npx tsc --noEmit`, `npx eslint src`
  and `npx prettier --check src` must all pass before shipping. It resolves the
  zsh files via `$CLAU_HOME` → `~/.zshrc.d` → `~/.claude` → `~/.config/clau`;
  never hardcode a personal path there.
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

- Bare `clau` decides picker vs onboarding on `[[ -t 0 ]]` alone. Verified in
  Claude Code's Bash tool (2026-08-25): stdin and stdout are not terminals and
  `/dev/tty` does not open, so an agent gets the model + tree + skill in one
  call. `skill` is a reserved first argument — no persona can be launched by
  that leaf name.
- `enabledPlugins` via `--settings` is live-tested (2026-08-24): the flag wins
  over `~/.claude/settings.json` per plugin key in both directions — a persona
  can switch on a globally-disabled plugin and switch off a globally-enabled
  one, so global installs stay persona-scopable.
- `enabledPlugins` merges by OR across layers, so a leaf cannot switch off a
  plugin its `base/` enabled. Documented as a trap in "the layers"; revisit if
  it turns out to bite in practice.
- `docs/atlas/` lags the guide badly — it predates persona directories, layers,
  the picker, multi-persona sessions, secrets and scratch. Read
  `docs/atlas/CLAUDE.md` before editing atlas maps.
