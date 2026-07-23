/* Environments as personas — staging/production, prod-ro/prod-rw. Designed in the
   guide (index.html § "the blast radius"); not yet exercised → stub. */
window.Atlas.register({
  id: "environment-personas",
  title: "Environments as personas",
  type: "flow",
  status: "stub",
  updated: "2026-07-16",
  summary:
    "debug-staging / debug-production / prod-ro / prod-rw: same debug skills, different sidecars (${VAR} credentials) and different permission postures. prod-rw is treated like sudo.",
  cell: { rows: ["operator"], cols: ["operate"] },
  wouldAnswer: [
    "Does ${VAR} expansion work in --mcp-config files the same as in .mcp.json? (documented for .mcp.json; unverified for sidecars)",
    "Do persona-level permissions.deny rules actually block MCP write tools in a live session?",
    "What's the cleanest secrets flow — direnv, gitignored sidecars, or op run — for each environment?",
    "Does the prod-ro deny-list + read-only DB role layering hold up end-to-end?",
  ],
});
