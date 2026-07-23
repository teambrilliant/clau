/* Settings precedence stack — where the persona file sits and what it can win. */
window.Atlas.register({
  id: "config-precedence",
  title: "Settings precedence",
  type: "reference",
  status: "mapped",
  updated: "2026-07-15",
  summary:
    "The merge stack, highest to lowest. The persona file (--settings) outranks everything except live CLI flags and managed policy.",
  lov: false,
  stepWord: "LAYER",
  steps: [
    {
      num: 1,
      title: "CLI flags",
      tag: "highest",
      cells: {
        ref: {
          carries: "Per-invocation overrides: <code>--model</code>, <code>--mcp-config</code>, <code>--strict-mcp-config</code>, <code>--plugin-dir</code>…",
          persona: "The launcher's MCP sidecar flags live here — they beat everything below.",
          caveat: "Single-invocation only; nothing persists.",
        },
      },
    },
    {
      num: 2,
      title: "Managed",
      tag: "org policy",
      cells: {
        ref: {
          carries: "Organization-enforced settings.",
          persona: "Not used in a solo setup.",
          caveat: "Would outrank persona files if ever present.",
        },
      },
    },
    {
      num: 3,
      title: "--settings file",
      tag: "★ the persona slot",
      cells: {
        ref: {
          carries: "<code>enabledPlugins</code> · <code>permissions</code> · <code>hooks</code> · <code>model</code> · <code>env</code> · <code>disabledMcpjsonServers</code> · <code>skillOverrides</code>",
          persona: "<strong>This is the persona.</strong> One committed JSON per hat: <code>.claude/personas/&lt;name&gt;.json</code>.",
          caveat: "Cannot override on-disk content: CLAUDE.md, .claude/skills/, project .mcp.json all still load from disk.",
        },
      },
    },
    {
      num: 4,
      title: "settings.local.json",
      tag: "project · gitignored",
      cells: {
        ref: {
          carries: "Personal per-project overrides.",
          persona: "Machine-local tweaks that apply to ALL personas in this repo.",
          caveat: "Silently outranked by any persona file — don't put persona-specific things here.",
        },
      },
    },
    {
      num: 5,
      title: "settings.json",
      tag: "project · committed",
      cells: {
        ref: {
          carries: "Team-shared baseline: default plugins, permissions, hooks.",
          persona: "The implicit “developer default” persona when launching bare <code>claude</code>.",
          caveat: "Everything here loads for every persona unless a persona file overrides it.",
        },
      },
    },
    {
      num: 6,
      title: "~/.claude/settings.json",
      tag: "user · lowest",
      cells: {
        ref: {
          carries: "Cross-project personal defaults.",
          persona: "Keep experimental plugins DISABLED here; personas opt in.",
          caveat: "User-scope plugins/skills enabled here appear in every project and every persona by default.",
        },
      },
    },
  ],
});
