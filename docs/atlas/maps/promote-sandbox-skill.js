/* Sandbox → promote — trying new skills without polluting working personas. */
window.Atlas.register({
  id: "promote-sandbox-skill",
  title: "Sandbox → promote a skill",
  type: "flow",
  status: "mapped",
  updated: "2026-07-15",
  summary:
    "Experimental skills live in a sandbox plugin visible only to the play persona; survivors get promoted into a real plugin, the rest get deleted.",
  cell: { rows: ["operator"], cols: ["evolve"] },
  goal: {
    kind: "containment",
    text: "Play freely with new skills while developer, designer and marketer sessions stay exactly as they were.",
  },
  steps: [
    {
      num: 1,
      title: "Capture in the sandbox",
      tag: "quarantine by default",
      cells: {
        operator: {
          doing: "Drops the experimental skill into <code>plugins/sandbox-skills/skills/</code> — written by hand, or pulled from the ecosystem: <code>npx skills add owner/repo --copy</code> then <code>git mv</code> into the sandbox. Never into ~/.claude/skills/. (Zero-commitment alternative: <code>npx skills use owner/repo@skill</code> runs it once without installing.)",
          thinking: "“This might not live longer than a week — it doesn't get to touch my working setup.”",
        },
        config: {
          touch: [
            { k: "sandbox", v: "plugins/sandbox-skills/ (in the marketplace repo)" },
            { k: "default", v: "disabled in user settings & all working personas" },
          ],
        },
        engine: {
          backstage: "Disabled plugin = fully unloaded; no skill list pollution, no context cost anywhere.",
          status: [{ k: "doc" }],
          gotcha:
            "<span class='risk-text'>The tempting shortcut — dropping it in ~/.claude/skills/ — leaks it into EVERY persona. Loose skills bypass the whole isolation model.</span>",
          acceptance: ["Developer/designer/marketer sessions show no trace of the sandbox skill."],
        },
      },
    },
    {
      num: 2,
      title: "Enable only in play",
      tag: "one flag flip",
      cells: {
        operator: {
          doing: "Sets <code>\"sandbox-skills@mp\": true</code> in <code>play.json</code> — and only there.",
        },
        config: {
          touch: [{ k: "persona", v: ".claude/personas/play.json" }],
          example: "<code>{\"enabledPlugins\":{\"sandbox-skills@mp\":true}}</code>",
        },
        engine: {
          backstage: "Play persona = working baseline + sandbox; nothing else diverges.",
          status: [{ k: "untested" }],
          acceptance: ["clau play lists the sandbox skill; clau developer does not."],
        },
      },
    },
    {
      num: 3,
      title: "Trial it",
      tag: "real use, contained blast radius",
      cells: {
        operator: {
          doing: "Uses the skill on real tasks inside <code>clau play</code> sessions; iterates on SKILL.md in place.",
          thinking: "“Does this earn a permanent slot?”",
          mot: {
            level: 1,
            text: "Mid-session iteration works: edit the skill, /reload-plugins, retry — no restart, no persona rebuild.",
          },
        },
        config: {
          touch: [{ k: "iterate", v: "edit SKILL.md → /reload-plugins" }],
        },
        engine: {
          backstage: "Plugin reload re-reads the plugin directory; the sandbox stays a normal plugin throughout — no special mechanics.",
          status: [{ k: "doc" }],
          acceptance: ["A SKILL.md edit is visible after /reload-plugins without restarting."],
        },
      },
    },
    {
      num: 4,
      title: "Promote or delete",
      tag: "the verdict",
      cells: {
        operator: {
          doing: "Survivor → moves the skill dir into the real plugin (dev-skills / ui-skills / copy-skills / product-skills). Failure → deletes the dir.",
          thinking: "“Promotion is a `git mv`, not a migration.”",
          mot: {
            level: 2,
            text: "★★ The whole system's value is decided here: promotion must be trivial (one move + commit) or the sandbox becomes a graveyard nobody drains.",
          },
        },
        config: {
          touch: [
            { k: "promote", v: "git mv plugins/sandbox-skills/skills/X plugins/ui-skills/skills/X" },
            { k: "cleanup", v: "sandbox stays lean; play.json unchanged" },
          ],
        },
        engine: {
          backstage: "The promoted skill now loads wherever its new plugin is enabled — instantly part of the working persona, gone from the sandbox.",
          status: [{ k: "doc" }],
          acceptance: [
            "After promotion, clau developer sees the skill and clau play no longer duplicates it.",
            { text: "Sandbox plugin is periodically empty — the drain works.", optional: true },
          ],
        },
      },
    },
  ],
});
