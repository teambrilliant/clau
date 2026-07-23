/* Capability sources — where skills & MCP servers come from, and what a persona can control. */
window.Atlas.register({
  id: "capability-sources",
  title: "Skill & MCP sources",
  type: "reference",
  status: "mapped",
  updated: "2026-07-15",
  summary:
    "Discovery order for skills and MCP servers by source, and the persona-control lever (or lack of one) for each.",
  lov: false,
  stepWord: "SOURCE",
  steps: [
    {
      num: 1,
      title: "Project .claude/",
      tag: "committed to the repo",
      cells: {
        ref: {
          carries: "Skills in <code>.claude/skills/</code> (high discovery precedence) · MCP servers in repo-root <code>.mcp.json</code>.",
          persona: "Skills: hide via <code>skillOverrides</code> in the persona file. MCP: suppress per-server via <code>disabledMcpjsonServers</code>.",
          caveat: "<span class='risk-text'>Loads for every persona by default — repo-level skills and servers are persona-blind unless explicitly overridden.</span>",
        },
      },
    },
    {
      num: 2,
      title: "User ~/.claude/",
      tag: "this machine, all projects",
      cells: {
        ref: {
          carries: "Loose skills in <code>~/.claude/skills/</code> · user-scope MCP servers · user-enabled plugins.",
          persona: "Weakest isolation point. Loose skills leak into ALL personas; only <code>skillOverrides</code> can hide them one by one.",
          caveat: "<span class='risk-text'>Doctrine: keep this layer nearly empty — migrate loose skills into plugins, keep experimental plugins disabled here.</span>",
        },
      },
    },
    {
      num: 3,
      title: "Plugins",
      tag: "★ the persona unit",
      cells: {
        ref: {
          carries: "Skills + agents + hooks + bundled MCP servers, all inside a plugin from a marketplace.",
          persona: "<strong>The lever personas are built on:</strong> <code>enabledPlugins</code> flips the whole bundle. Mid-session: <code>/plugin</code> + <code>/reload-plugins</code>.",
          caveat: "All-or-nothing: a plugin's bundled MCP can't be disabled without disabling the plugin — split MCP into its own plugin if a persona needs skills-without-servers.",
        },
      },
    },
    {
      num: 4,
      title: "--mcp-config sidecar",
      tag: "launch-time injection",
      cells: {
        ref: {
          carries: "MCP servers only, from JSON files passed at launch: the shared <code>base.mcp.json</code> (chrome-devtools, every hat) + one persona sidecar (repo-local wins over global).",
          persona: "The context slot: PostHog rides with product, experimental servers with marketer. Additive by default; <code>clau &lt;p&gt; --strict-mcp-config</code> for hermetic sessions.",
          caveat: "Sidecars ADD to inherited user/repo servers — they don't replace them. An empty repo sidecar (<code>{\"mcpServers\":{}}</code>) removes only the persona's own default.",
        },
      },
    },
    {
      num: 5,
      title: "Bundled",
      tag: "ships with CC",
      cells: {
        ref: {
          carries: "Built-in skills (<code>/code-review</code>, <code>/init</code>, …) and core tools.",
          persona: "Not persona-controllable; present everywhere.",
          caveat: "Lowest skill precedence — a same-named skill in any layer above shadows a bundled one.",
        },
      },
    },
  ],
});
