# Claude Code Configuration Atlas — Personas & Profiles

Source of truth for **how Claude Code sessions assemble their capabilities and how personas (developer / designer / marketer / product / play) isolate skills, plugins and MCP servers from one repo**. One surface: an Actor×Lifecycle coverage home (`index.html#/`) whose tiles open per-flow alignment grids (maps). Build detail does NOT live here.

## Architecture

- `index.html` — the shell. Owns ALL rendering (home, stub, grid) + hash routing + runtime style injection from `window.ATLAS`. Maps never contain markup. Runs from `file://`, no build/server.
- `maps/*.js` — one data file per flow; self-registers via `window.Atlas.register({...})` with a classic `<script src>` line at the bottom of `index.html` (ES modules break on `file://` — keep classic scripts).
- After editing, **hard-reload** (`file://` caches aggressively).

## The config block (top of index.html)

`window.ATLAS` is the only thing that changes per atlas: `title`, `registry`, `home` (Actor rows × Lifecycle columns), `layers` (presets: `flow` = Operator/Config/CC-engine; `reference` = precedence/discovery grids), `lovDefault` (`config` — operator + config files are front-stage, engine behavior backstage), `status` vocabulary. The engine below it is generic — do not edit it to add a map.

## Status vocabulary (confidence, not wiring)

- `verified` — checked live on this machine (e.g. flags confirmed via `claude --help`)
- `documented` — from official Claude Code docs, not exercised here
- `untested` — designed in this system, not yet run end-to-end
- `gap` — known manual step or limitation

## Adding or updating a flow

1. Create/edit `maps/<kebab-id>.js`; add one `<script src>` line in `index.html`.
2. Start as a **stub** (`status:"stub"`, `wouldAnswer:[...]`). Promote to `mapped` by adding `steps[]`.
3. Bump `updated`.
4. Verify in a browser: home tile lands in the right cell, `#/map/<id>` renders, no console errors, no literal `false`/`undefined` in cells.

## Cell kinds (the closed set the renderer understands)

`html` (default — trusted local HTML), `quote`, `mot` (`{level,text}`; `level:2` = ★★, reserved for the 1–2 make-or-break steps), `status` (`[{k}]` from the vocab; drives the filter), `acceptance` (`string[]` or `{text,optional}[]`), `kv` (`[{k,v,todo}]`).

## Conventions (hard rules)

- **Text always black.** Status/layers convey meaning via fills + borders, never colored text.
- **★★ is reserved** for the one or two make-or-break moments per flow.
- **One home placement per map** — one row + one col in `cell`; multiple cells duplicate the tile.
- **Empty cells are the point** — unmapped territory stays visible.
- Reference maps (type `reference`) carry no `cell` → they render in the strip, `lov:false`, `stepWord` relabels columns (`LAYER`, `SOURCE`).

## Known open items (as of 2026-07-15)

- `enabledPlugins` via `--settings` is documented but not live-tested — the ★★ in `launch-persona-session` and `author-persona`.
- The global `clau` zsh function (dotfiles) replaced the earlier per-repo `bin/cc` idea (2026-07-15). Bare `clau` ≡ bare `claude` (pass-through); `clau -h` self-discovers personas/sidecars and checks `~/.claude/plugins/marketplaces/` for registration. Function logic sandbox-tested against a stubbed `claude` (2026-07-15); not yet installed in dotfiles, and real-session `enabledPlugins` behavior still untested.
- MCP sidecars are additive (`base.mcp.json` for every hat + one persona sidecar, repo-local wins); `--strict-mcp-config` is a pass-through flag, not the default (2026-07-15).
- Persona statusline: clau exports `CLAU_PERSONA` (child-only); `~/.claude/statusline.sh` + user-settings `statusLine` key render `⬢ <persona>`. Script + env pass-through sandbox-tested 2026-07-19; not yet run inside a real session.
- Marketplace add is a manual per-machine step (`onboard-machine`, status `gap`).
