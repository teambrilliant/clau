import {
  Action,
  ActionPanel,
  Color,
  Icon,
  List,
  closeMainWindow,
  showToast,
  Toast,
} from "@raycast/api";
import { useEffect, useState } from "react";
import { loadPersonas, personaTint, type Persona } from "../lib/personas";
import { launch, readTerminal, terminalName } from "../lib/terminal";
import { quoteForShell } from "../lib/shell";

type Props = {
  cwd: string;
  extraArgs?: string[];
  navigationTitle?: string;
};

export function PersonaList({ cwd, extraArgs = [], navigationTitle }: Props) {
  const [personas, setPersonas] = useState<Persona[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<string[]>([]);

  useEffect(() => {
    loadPersonas(cwd)
      .then((state) => setPersonas(state.personas))
      .catch((error: unknown) => {
        showToast({
          style: Toast.Style.Failure,
          title: "Could not read personas",
          message: error instanceof Error ? error.message : String(error),
        });
      })
      .finally(() => setLoading(false));
  }, [cwd]);

  const toggle = (path: string) =>
    setSelected((current) =>
      current.includes(path)
        ? current.filter((p) => p !== path)
        : [...current, path],
    );

  const run = async (paths: string[]) => {
    if (paths.length === 0) return;
    const terminal = readTerminal();
    const args = [...paths, ...extraArgs].map(quoteForShell).join(" ");
    await launch(cwd, `clau ${args}`, terminal);
    await closeMainWindow();
    await showToast({
      style: Toast.Style.Success,
      title: `Launched ${paths.join(" + ")}`,
      message: terminalName(terminal),
    });
  };

  return (
    <List
      isLoading={loading}
      navigationTitle={
        selected.length > 0
          ? `${navigationTitle ?? cwd} · ${selected.length} selected`
          : (navigationTitle ?? cwd)
      }
      searchBarPlaceholder="Filter personas"
    >
      {personas.map((persona) => {
        const checked = selected.includes(persona.path);
        const tint = personaTint(persona.color);
        return (
          <List.Item
            key={persona.path}
            title={persona.name}
            subtitle={persona.group}
            icon={{
              source: checked ? Icon.CheckCircle : Icon.Circle,
              tintColor: tint ?? Color.SecondaryText,
            }}
            accessories={[
              persona.hasMcp ? { tag: "mcp" } : {},
              persona.hasEnv ? { tag: "env" } : {},
              persona.hasPrompt ? { tag: "prompt" } : {},
            ]}
            actions={
              <ActionPanel>
                <Action
                  title={
                    selected.length > 0
                      ? `Launch Selected (${selected.length})`
                      : "Launch"
                  }
                  icon={selected.length > 0 ? Icon.Rocket : Icon.Terminal}
                  onAction={() =>
                    run(selected.length > 0 ? selected : [persona.path])
                  }
                />
                <Action
                  title={checked ? "Unselect" : "Select"}
                  icon={Icon.Circle}
                  shortcut={{ modifiers: ["cmd"], key: "t" }}
                  onAction={() => toggle(persona.path)}
                />
                <Action
                  title="Launch This One Only"
                  icon={Icon.Terminal}
                  shortcut={{ modifiers: ["cmd"], key: "return" }}
                  onAction={() => run([persona.path])}
                />
                <Action
                  title="Clear Selection"
                  icon={Icon.XMarkCircle}
                  shortcut={{ modifiers: ["cmd"], key: "backspace" }}
                  onAction={() => setSelected([])}
                />
                <Action.ShowInFinder
                  path={persona.dir}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "f" }}
                />
                <Action.CopyToClipboard
                  title="Copy Launch Command"
                  content={`clau ${[persona.path, ...extraArgs].join(" ")}`}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
