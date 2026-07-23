/* Launch a persona session — the core runtime flow: how one `clau designer` becomes
   an isolated session with only that persona's skills, plugins and MCP servers. */
window.Atlas.register({
  id: "launch-persona-session",
  title: "Launch a persona session",
  type: "flow",
  status: "mapped",
  updated: "2026-07-15",
  summary:
    "clau <persona> → settings merge → plugin resolution → MCP sidecars → isolated session. The flow everything else exists to serve.",
  cell: { rows: ["operator"], cols: ["launch"] },
  goal: {
    kind: "isolation",
    text: "Same repo, different hat — a designer session must never see dev skills or the marketer's experimental servers, and vice versa.",
  },
  steps: [
    {
      num: 1,
      title: "Pick the persona",
      tag: "one command",
      cells: {
        operator: {
          doing: "Runs <code>clau designer</code> — a global zsh function from dotfiles — from anywhere inside any project repo.",
          thinking: "“Same repo, different hat — I don't want dev skills polluting a design session. And no per-repo launcher scripts.”",
        },
        config: {
          touch: [
            { k: "launcher", v: "clau() in ~/.zshrc (dotfiles, global)" },
            { k: "bare / flags-first", v: "clau · clau -c → plain claude, full pass-through" },
            { k: "discovery", v: "clau -h → lists personas, sidecars, marketplace health" },
          ],
          example: "<code>claude --settings ~/.claude/personas/designer.json …</code>",
        },
        engine: {
          backstage:
            "The function resolves the git root, prefers a repo-local <code>.claude/personas/&lt;persona&gt;.json</code> override, falls back to the global <code>~/.claude/personas/&lt;persona&gt;.json</code>, and gathers MCP sidecars (base + persona). Unknown persona → error, not a bare session.",
          status: [{ k: "verified" }],
          gotcha:
            "Function logic sandbox-tested against a stubbed <code>claude</code> (all 8 paths: bare, flags-first, -h, persona, repo-sidecar precedence, strict pass-through, unknown persona, empty home). Real-session flag behavior is the step-3 test.",
          acceptance: ["`clau designer` starts a session from any repo (and any subdirectory); `clau` alone behaves exactly like bare `claude`; `clau -h` lists every persona; `clau nope` errors."],
        },
      },
    },
    {
      num: 2,
      title: "Settings merge",
      tag: "--settings enters the stack",
      cells: {
        operator: {
          doing: "Nothing — this is invisible. The persona file silently outranks project and user settings.",
        },
        config: {
          touch: [
            { k: "persona", v: "~/.claude/personas/designer.json (repo-local override wins if present)" },
            { k: "outranked", v: "settings.local.json · project settings.json · ~/.claude/settings.json" },
          ],
          example: "<code>--settings</code> sits above local/project/user, below CLI flags &amp; managed policy.",
        },
        engine: {
          backstage:
            "CC merges settings by precedence; the persona file wins for <code>enabledPlugins</code>, <code>permissions</code>, <code>hooks</code>, <code>model</code>, <code>env</code>, <code>disabledMcpjsonServers</code>.",
          status: [{ k: "doc" }],
          gotcha:
            "<span class='risk-text'>CLAUDE.md is persona-blind — repo + user CLAUDE.md load for EVERY persona. Persona-specific instructions must live inside plugin skills; keep CLAUDE.md neutral.</span>",
          acceptance: ["A setting overridden in the persona file (e.g. model) is visibly in effect in-session."],
        },
      },
    },
    {
      num: 3,
      title: "Plugin resolution",
      tag: "the persona unit toggles",
      cells: {
        operator: {
          thinking: "“Enabling ui-skills should bring its skills, agents AND anything it bundles — as one unit. And copy-skills should be nowhere in sight.”",
          mot: {
            level: 2,
            text: "★★ The whole persona model hinges on <code>enabledPlugins</code> actually flipping via <code>--settings</code>. Documented, not yet live-tested — the first real persona session is the test.",
          },
        },
        config: {
          touch: [
            { k: "key format", v: "\"ui-skills@my-marketplace\": true/false" },
            { k: "unit", v: "plugin = skills + agents + MCP + hooks (all-or-nothing)" },
          ],
          example: "<code>{\"enabledPlugins\":{\"ui-skills@mp\":true,\"dev-skills@mp\":false,\"copy-skills@mp\":false}}</code>",
        },
        engine: {
          backstage:
            "Enabled plugins load every component together; disabled plugins unload everything. Loose skills are NOT toggleable this way — only <code>skillOverrides</code> can hide them.",
          status: [{ k: "untested" }, { k: "doc" }],
          gotcha:
            "<span class='risk-text'>Loose-skills leakage: anything still in ~/.claude/skills/ appears in ALL personas. Migrating loose skills into plugins is a precondition for real isolation.</span>",
          acceptance: [
            "Designer session: /plugin shows ui-skills enabled, dev-skills and copy-skills disabled.",
            "A dev-skills slash command is absent from the designer session's skill list.",
          ],
        },
      },
    },
    {
      num: 4,
      title: "MCP sidecars attach",
      tag: "base + persona, additive",
      cells: {
        operator: {
          doing: "Still nothing — the launcher stacked the shared base sidecar plus this persona's sidecar (repo-local wins over global).",
          thinking: "“Every hat gets chrome-devtools; only product gets PostHog; only marketer gets their experiments.”",
        },
        config: {
          touch: [
            { k: "base", v: "~/.claude/personas/base.mcp.json — chrome-devtools, every hat" },
            { k: "persona", v: "<repo>/.claude/personas/<p>.mcp.json wins, else ~/.claude/personas/<p>.mcp.json" },
            { k: "flags", v: "--mcp-config base.json persona.json (additive)" },
          ],
          example: "<code>--mcp-config ~/.claude/personas/base.mcp.json ~/.claude/personas/product.mcp.json</code>",
        },
        engine: {
          backstage:
            "Sidecars are additive by default — user-level and repo <code>.mcp.json</code> servers still load, so dev sessions keep their databases. Both flags verified via <code>claude --help</code> (<code>--mcp-config</code> accepts multiple files).",
          status: [{ k: "verified" }],
          gotcha:
            "<span class='risk-text'>Sidecars add, they don't replace: inherited servers remain. Suppress one via disabledMcpjsonServers in the persona file, or pass --strict-mcp-config through clau for a hermetic session.</span>",
          acceptance: ["/mcp in the product session lists chrome-devtools + posthog (+ inherited repo servers)."],
        },
      },
    },
    {
      num: 5,
      title: "Session ready",
      tag: "verify the hat fits",
      cells: {
        operator: {
          doing: "Sanity-checks the persona: <code>/plugin</code> (enabled set), <code>/mcp</code> (servers), tries one persona skill.",
          thinking: "“Do I see ONLY this hat's tools?”",
          mot: { level: 1, text: "First proof the isolation actually holds — worth doing explicitly on the first launch of each persona." },
        },
        config: {
          touch: [{ k: "checks", v: "/plugin · /mcp · skill list" }],
          example: "Mid-session plugin flips: <code>/plugin</code> + <code>/reload-plugins</code> — no restart needed.",
        },
        engine: {
          backstage: "Session runs with the persona's merged settings until exit; clau exports <code>CLAU_PERSONA</code> to the session, and the statusline script (statusLine command inherits session env) renders <code>⬢ &lt;persona&gt;</code> — the hat is visible the whole session. Other terminals can run other personas concurrently against the same repo.",
          status: [{ k: "verified" }, { k: "doc" }],
          acceptance: [
            "Statusline shows ⬢ <persona> in clau sessions and no persona segment in bare claude.",
            "Concurrent sessions (clau, clau designer, clau marketer) show disjoint skill sets.",
            { text: "/reload-plugins picks up a plugin toggle without restart.", optional: true },
          ],
        },
      },
    },
  ],
});
