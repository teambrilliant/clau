/* Author a new persona — from nothing to a launchable hat, using the designer as the example. */
window.Atlas.register({
  id: "author-persona",
  title: "Author a persona",
  type: "flow",
  status: "mapped",
  updated: "2026-07-15",
  summary:
    "Plugin → marketplace entry → persona settings JSON → MCP sidecars → global launcher → first live test. Everything in git (plugins repo + dotfiles), nothing per-project.",
  cell: { rows: ["operator"], cols: ["author"] },
  goal: {
    kind: "git-native",
    text: "The whole persona lives in git — plugins repo for capability, dotfiles for hats and sidecars. Project repos carry nothing but optional MCP overrides.",
  },
  steps: [
    {
      num: 1,
      title: "Create the plugin",
      tag: "the capability bundle",
      cells: {
        operator: {
          doing: "Creates <code>plugins/ui-skills/</code> in the plugins repo with a manifest and the design skills (plus agents/hooks/bundled MCP if the hat needs them).",
          thinking: "“Skills are the capability — everything the designer hat knows how to do goes in one plugin.”",
        },
        config: {
          touch: [
            { k: "manifest", v: "plugins/ui-skills/.claude-plugin/plugin.json" },
            { k: "content", v: "skills/ · agents/ · hooks/ · .mcp.json (optional bundled servers)" },
          ],
          example: "<code>plugins/ui-skills/skills/design-review/SKILL.md</code>",
        },
        engine: {
          backstage: "A plugin is the unit of toggling — every component inside rides together on enable/disable.",
          status: [{ k: "doc" }],
          acceptance: ["Plugin dir passes /plugin validation (or plugin-dev:plugin-validator)."],
        },
      },
    },
    {
      num: 2,
      title: "Register in the marketplace",
      tag: "plugins repo = marketplace",
      cells: {
        operator: {
          doing: "Adds the plugin to the plugins-repo-root marketplace manifest with a relative-path source.",
        },
        config: {
          touch: [{ k: "manifest", v: ".claude-plugin/marketplace.json (plugins-repo root)" }],
          example: "<code>{\"name\":\"ui-skills\",\"source\":\"./plugins/ui-skills\"}</code>",
        },
        engine: {
          backstage:
            "The plugins repo is the marketplace; plugin identity becomes <code>ui-skills@&lt;marketplace-name&gt;</code> — the key persona files will reference.",
          status: [{ k: "doc" }],
          gotcha: "The marketplace name chosen here is baked into every enabledPlugins key — pick it once, don't rename casually.",
          acceptance: ["/plugin marketplace add ~/dev/claude-code-plugins lists the plugin as installable."],
        },
      },
    },
    {
      num: 3,
      title: "Write the persona file",
      tag: "the settings JSON",
      cells: {
        operator: {
          doing: "Adds <code>~/.claude/personas/designer.json</code> (dotfiles-managed) flipping <code>enabledPlugins</code> on/off per plugin — ui-skills on, everything else explicitly off.",
          thinking: "“One JSON file IS the persona — and there's exactly one copy, for every repo.”",
        },
        config: {
          touch: [
            { k: "persona", v: "~/.claude/personas/designer.json (dotfiles)" },
            { k: "override", v: "repo-local .claude/personas/designer.json wins if present (rare)" },
          ],
          example:
            "<code>{\"enabledPlugins\":{\"ui-skills@mp\":true,\"dev-skills@mp\":false,\"copy-skills@mp\":false,\"product-skills@mp\":false}}</code>",
        },
        engine: {
          backstage: "One global persona file serves every project — only the MCP sidecars vary (capability vs context split).",
          status: [{ k: "doc" }],
          acceptance: ["The persona file is valid settings JSON (claude --settings accepts it)."],
        },
      },
    },
    {
      num: 4,
      title: "Add the MCP sidecars",
      tag: "base + per-hat",
      cells: {
        operator: {
          doing: "Ensures <code>base.mcp.json</code> (chrome-devtools — every hat gets it) exists, and adds a persona sidecar if this hat needs context: PostHog for product, the experimental servers for marketer. The designer may need none beyond base.",
          mot: {
            level: 1,
            text: "The capability/context split happens here — skills stay in plugins, connections stay in sidecars.",
          },
        },
        config: {
          touch: [
            { k: "base", v: "~/.claude/personas/base.mcp.json (all hats)" },
            { k: "per-hat", v: "~/.claude/personas/product.mcp.json · marketer.mcp.json" },
            { k: "secrets", v: "env-var placeholders, or gitignore the file entirely" },
          ],
          example: "<code>{\"mcpServers\":{\"posthog\":{…,\"env\":{\"POSTHOG_API_KEY\":\"${POSTHOG_API_KEY}\"}}}}</code>",
        },
        engine: {
          backstage: "Sidecars load via <code>--mcp-config</code> at launch, additively on top of user/repo servers; secret-bearing configs never enter git with credentials.",
          status: [{ k: "verified" }],
          acceptance: ["Sidecar files contain no literal secrets (grep for tokens before committing)."],
        },
      },
    },
    {
      num: 5,
      title: "Wire the global launcher",
      tag: "clau() in dotfiles",
      cells: {
        operator: {
          doing: "Adds a global <code>clau()</code> zsh function to dotfiles: persona name → settings flag (repo-local override, else global) + base and persona sidecars. No per-repo scripts.",
        },
        config: {
          touch: [{ k: "launcher", v: "clau() in ~/.zshrc (dotfiles, global)" }],
          example:
            "<code>(( ${#mcp} )) && args+=(--mcp-config \"${mcp[@]}\")</code>",
        },
        engine: {
          backstage: "Resolves the git root so it works from subdirectories; bare clau (or flags-first) passes straight through to plain claude; clau -h self-discovers personas, sidecars and marketplace health from the same files it launches with; unknown personas error.",
          status: [{ k: "verified" }],
          acceptance: ["clau <persona> launches from any repo; bare clau ≡ bare claude; clau -h lists every hat and flags unregistered marketplaces."],
        },
      },
    },
    {
      num: 6,
      title: "First live test",
      tag: "the proof",
      cells: {
        operator: {
          doing: "Launches <code>clau designer</code>, checks <code>/plugin</code>, <code>/mcp</code>, and runs one design skill end-to-end.",
          thinking: "“Does the documented behavior survive contact with reality?”",
          mot: {
            level: 2,
            text: "★★ enabledPlugins-via---settings is the one load-bearing claim taken from docs, not tested live. This step converts the design from paper to proven.",
          },
        },
        config: {
          touch: [{ k: "checks", v: "/plugin · /mcp · one skill invocation" }],
        },
        engine: {
          backstage: "If the toggle doesn't behave as documented, fallback is per-session /plugin toggling or settings.local.json swaps — the layout survives either way.",
          status: [{ k: "untested" }],
          acceptance: [
            "Designer session shows only ui-skills; /mcp shows chrome-devtools.",
            "Developer sessions unchanged by the new persona's existence.",
          ],
        },
      },
    },
  ],
});
