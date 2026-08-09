import {
  Action,
  ActionPanel,
  Form,
  popToRoot,
  showToast,
  Toast,
} from "@raycast/api";
import { homedir } from "node:os";
import { useEffect, useState } from "react";
import { loadPersonas, type Persona } from "./lib/personas";
import { clauPrelude, quoteForShell, zsh } from "./lib/shell";

type Values = {
  personas: string[];
  name: string;
  transport: string;
  target: string;
  env: string;
};

export default function Command() {
  const [personas, setPersonas] = useState<Persona[]>([]);
  const [loading, setLoading] = useState(true);
  const [transport, setTransport] = useState("http");

  useEffect(() => {
    loadPersonas(homedir())
      .then((state) => setPersonas(state.personas))
      .catch((error: unknown) => {
        showToast({
          style: Toast.Style.Failure,
          title: "Could not read personas",
          message: error instanceof Error ? error.message : String(error),
        });
      })
      .finally(() => setLoading(false));
  }, []);

  const submit = async (values: Values) => {
    if (
      values.personas.length === 0 ||
      !values.name.trim() ||
      !values.target.trim()
    ) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Persona, name and target are required",
      });
      return;
    }
    const envArgs = values.env
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .map((pair) => `--env ${quoteForShell(pair)}`)
      .join(" ");

    const tail =
      values.transport === "stdio"
        ? `${envArgs} -- ${values.target}`
        : `--transport ${values.transport} ${quoteForShell(values.target)}`;

    try {
      const prelude = clauPrelude(["clau.zsh", "clau-mcp.zsh"]);
      for (const persona of values.personas) {
        await zsh(
          `${prelude}; clau-mcp add ${quoteForShell(persona)} ${quoteForShell(values.name)} ${tail}`,
          homedir(),
        );
      }
      await showToast({
        style: Toast.Style.Success,
        title: `Added ${values.name}`,
        message: values.personas.join(", "),
      });
      await popToRoot();
    } catch (error: unknown) {
      await showToast({
        style: Toast.Style.Failure,
        title: "clau-mcp failed",
        message: error instanceof Error ? error.message : String(error),
      });
    }
  };

  return (
    <Form
      isLoading={loading}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Add Server" onSubmit={submit} />
        </ActionPanel>
      }
    >
      <Form.TagPicker id="personas" title="Personas">
        {personas.map((persona) => (
          <Form.TagPicker.Item
            key={persona.path}
            value={persona.path}
            title={persona.path}
          />
        ))}
      </Form.TagPicker>
      <Form.TextField id="name" title="Server name" placeholder="notion" />
      <Form.Dropdown
        id="transport"
        title="Transport"
        value={transport}
        onChange={setTransport}
      >
        <Form.Dropdown.Item value="http" title="http" />
        <Form.Dropdown.Item value="sse" title="sse" />
        <Form.Dropdown.Item value="stdio" title="stdio" />
      </Form.Dropdown>
      <Form.TextField
        id="target"
        title={transport === "stdio" ? "Command" : "URL"}
        placeholder={
          transport === "stdio"
            ? "npx -y @notionhq/notion-mcp-server"
            : "https://mcp.notion.com/mcp"
        }
      />
      <Form.TextArea
        id="env"
        title="Env"
        placeholder={"NOTION_TOKEN=${NOTION_TOKEN}"}
        info="One KEY=value per line. Use ${VAR} placeholders; clau resolves them from Keychain."
      />
    </Form>
  );
}
