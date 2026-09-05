# Changelog

No releases or tags yet, so the headings are dates rather than versions. `clau --json` is the only published contract; changes to it say so.

## Unreleased

- Every hat in the picker and in `clau -h` carries a `repo` or `global` column, and both name the root the repo hats resolved from. The root prints relative while it sits under `$PWD` and absolute when it does not, so an absolute path means the hats come from an ancestor directory, not from this project.
- `clau --json` gains `origin` per persona, `"repo"` or `"global"`. Additive; `raycast/src/lib/personas.ts` types it.

## 2026-08-26

- MIT license, `SECURITY.md`, and CI running `test/smoke.zsh` on `macos-latest`.
- The guide became markdown at `docs/guide.md`, linking to the source files instead of embedding them.

## 2026-08-25

- Bare `clau` with no terminal on stdin prints the model, the persona tree and the authoring skill in one call, instead of reaching for a picker it cannot draw. An agent can onboard a repo without a pty.

## 2026-08-12

### Added

- `test/smoke.zsh` — fake `$HOME`, a stub `claude` on `PATH`, a temp persona tree, nothing outside `$TMPDIR` touched.

### Fixed

- `clau-secret set` cut stored values at 128 characters. Values written by an earlier version are still short; `clau-secret audit` flags a length of exactly 128, and `set` again is the fix.
- `clau` leaked loop variables into the calling shell.
- `clau-mcp list` ignored repo-local personas, and `clau-mcp add` could only write one hat at a time.

## 2026-08-09

- Personas became directories: `base/` layers that everything below inherits, the picker, keychain-backed secrets, and a per-codebase scratch directory passed in with `--add-dir`.
- `clau --json`, and a Raycast extension over it.
- The `clau-persona` authoring skill, via `clau skill` and `clau skill install`.

## 2026-07-23

- First cut: the launcher, the statusline badge, and the guide.
