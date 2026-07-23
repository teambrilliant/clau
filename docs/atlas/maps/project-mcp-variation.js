/* Same skills, different context — one product persona, a different PostHog project per repo. */
window.Atlas.register({
  id: "project-mcp-variation",
  title: "Per-project MCP variation",
  type: "flow",
  status: "mapped",
  updated: "2026-07-15",
  summary:
    "One product-skills plugin + one global PostHog sidecar everywhere; a repo-local sidecar rebinds or removes it per project. Only sidecars ever vary.",
  cell: { rows: ["operator"], cols: ["operate"] },
  goal: {
    kind: "no cross-pollution",
    text: "Capability (skills) and context (analytics/MCP) never travel together — swapping projects swaps context without touching the persona.",
  },
  steps: [
    {
      num: 1,
      title: "Share the persona",
      tag: "capability is global",
      cells: {
        operator: {
          doing: "Uses the one global <code>~/.claude/personas/product.json</code> (+ global <code>product.mcp.json</code> with PostHog) from every project repo — clau resolves them wherever it's called.",
          thinking: "“One product brain, everywhere I work.”",
        },
        config: {
          touch: [
            { k: "single copy", v: "~/.claude/personas/product.json + product.mcp.json (dotfiles)" },
          ],
          example: "The persona JSON has NO servers in it — context lives in sidecars, deliberately.",
        },
        engine: {
          backstage: "Skills/plugins resolve from the marketplace identically per repo; the global PostHog sidecar is the default context.",
          status: [{ k: "doc" }],
          acceptance: ["There is exactly one product.json on the machine — nothing to drift between repos."],
        },
      },
    },
    {
      num: 2,
      title: "Bind a repo to its PostHog project",
      tag: "repo sidecar wins",
      cells: {
        operator: {
          doing: "Drops <code>.claude/personas/product.mcp.json</code> into the app repo — same server, this project's analytics key.",
          mot: {
            level: 2,
            text: "★★ This is where the capability/context split pays off: the repo-local sidecar REPLACES the global one for this persona, so each project is measured by its own PostHog — never someone else's.",
          },
        },
        config: {
          touch: [
            { k: "app-repo", v: ".claude/personas/product.mcp.json → this repo's PostHog project" },
            { k: "secrets", v: "${POSTHOG_KEY_APP} env placeholder or gitignored file" },
          ],
        },
        engine: {
          backstage: "clau's first-found rule (repo → global) means no merge ambiguity: exactly one product sidecar loads, plus base (chrome-devtools).",
          status: [{ k: "verified" }],
          acceptance: ["/mcp in the app repo's product session shows posthog bound to this project."],
        },
      },
    },
    {
      num: 3,
      title: "Knock analytics out for a repo",
      tag: "deliberately none",
      cells: {
        operator: {
          doing: "In a client repo that must stay unmeasured, commits an EMPTY repo-local sidecar.",
          thinking: "“Client work gets no analytics — but I still want chrome-devtools.”",
        },
        config: {
          touch: [{ k: "empty sidecar", v: "{\"mcpServers\":{}} — replaces the global PostHog default" }],
          example: "<code>echo '{\"mcpServers\":{}}' &gt; .claude/personas/product.mcp.json</code>",
        },
        engine: {
          backstage: "The empty repo sidecar wins the persona slot (no PostHog); base still loads chrome-devtools; inherited user/repo servers still apply.",
          status: [{ k: "doc" }],
          gotcha:
            "<span class='risk-text'>Sidecars add, they don't replace inherited servers: user-level and repo .mcp.json still load. Suppress via disabledMcpjsonServers, or go hermetic (step 4).</span>",
          acceptance: ["/mcp in the client repo's product session shows chrome-devtools but no posthog."],
        },
      },
    },
    {
      num: 4,
      title: "Go hermetic when needed",
      tag: "strict pass-through",
      cells: {
        operator: {
          doing: "For a session that must see ONLY the sidecars — nothing inherited — passes the strict flag straight through clau.",
        },
        config: {
          touch: [{ k: "pass-through", v: "clau product --strict-mcp-config" }],
          example: "clau forwards unknown args to <code>claude</code>, so any flag works ad hoc.",
        },
        engine: {
          backstage: "<code>--strict-mcp-config</code> restricts MCP to the files given via <code>--mcp-config</code> — user-level and repo <code>.mcp.json</code> servers are ignored for this session only.",
          status: [{ k: "verified" }],
          acceptance: ["/mcp lists only base + persona sidecar servers in a strict session."],
        },
      },
    },
  ],
});
