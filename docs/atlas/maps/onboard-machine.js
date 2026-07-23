/* Onboard a machine/teammate — the one manual step the design can't automate. */
window.Atlas.register({
  id: "onboard-machine",
  title: "Onboard a new machine",
  type: "flow",
  status: "mapped",
  updated: "2026-07-15",
  summary:
    "Clone → add the marketplace (manual, one-time) → provide secrets → launch. The marketplace add is the known onboarding gap.",
  cell: { rows: ["team"], cols: ["launch"] },
  steps: [
    {
      num: 1,
      title: "Clone the repo",
      tag: "everything travels in git",
      cells: {
        operator: {
          doing: "Clones the plugins repo and installs dotfiles (personas + the clau function). Project repos need nothing persona-related.",
          thinking: "“The personas should just be… there.”",
        },
        config: {
          touch: [{ k: "arrives via git", v: "plugins repo (marketplace) · dotfiles (~/.claude/personas + clau) · project repos (optional sidecars only)" }],
        },
        engine: {
          backstage: "All persona structure is on disk immediately — but plugin identities don't resolve yet.",
          status: [{ k: "doc" }],
          acceptance: ["~/.claude/personas/ populated; clau function available; plugins repo cloned."],
        },
      },
    },
    {
      num: 2,
      title: "Add the marketplace",
      tag: "manual, one-time",
      cells: {
        operator: {
          doing: "Runs <code>/plugin marketplace add ~/dev/claude-code-plugins</code> once inside a session (or the CLI equivalent).",
          mot: {
            level: 2,
            text: "★★ Skipping this makes every <code>plugin@marketplace</code> key resolve to nothing — the persona silently degrades to bare Claude with no error pointing at the cause.",
          },
        },
        config: {
          touch: [{ k: "one-time", v: "/plugin marketplace add ~/dev/claude-code-plugins" }],
        },
        engine: {
          backstage: "Marketplace registration is per-machine state, not repo state — the one link git cannot carry.",
          status: [{ k: "gap" }],
          gotcha:
            "<span class='risk-text'>Known gap: not automatable from git alone. Mitigate with a README line, a clau preflight check (warn if marketplace missing), or a dotfiles bootstrap script.</span>",
          acceptance: ["/plugin lists the repo's plugins as installable after the add."],
        },
      },
    },
    {
      num: 3,
      title: "Provide secrets",
      tag: "env, not git",
      cells: {
        operator: {
          doing: "Exports the env vars MCP sidecars reference (<code>POSTHOG_API_KEY</code> etc.), or drops gitignored local sidecar files.",
        },
        config: {
          touch: [
            { k: "committed", v: "sidecars with ${ENV_VAR} placeholders" },
            { k: "local-only", v: "gitignored sidecars with real credentials" },
          ],
        },
        engine: {
          backstage: "Same discipline as this repo's .mcp.json guard: credentials never enter git; shape does.",
          status: [{ k: "doc" }],
          acceptance: ["grep of committed sidecars finds placeholders only, no literal tokens."],
        },
      },
    },
    {
      num: 4,
      title: "Launch & verify",
      tag: "done",
      cells: {
        operator: {
          doing: "Runs <code>clau &lt;persona&gt;</code>, checks <code>/plugin</code> and <code>/mcp</code> match the persona's declared surface.",
        },
        config: {
          touch: [{ k: "check", v: "/plugin · /mcp" }],
        },
        engine: {
          backstage: "From here the machine behaves identically to the authoring machine — persona files are the single source of truth.",
          status: [{ k: "untested" }],
          acceptance: ["A second machine reproduces the same /plugin + /mcp surface for the same persona."],
        },
      },
    },
  ],
});
