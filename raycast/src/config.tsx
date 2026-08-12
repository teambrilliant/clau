import {
  Action,
  ActionPanel,
  Icon,
  List,
  showToast,
  Toast,
} from "@raycast/api";
import { useState } from "react";
import {
  installedTerminals,
  readTerminal,
  writeTerminal,
  type TerminalId,
} from "./lib/terminal";

export default function Command() {
  const [current, setCurrent] = useState<TerminalId>(readTerminal());
  const terminals = installedTerminals();

  const choose = async (id: TerminalId, name: string) => {
    writeTerminal(id);
    setCurrent(id);
    await showToast({
      style: Toast.Style.Success,
      title: `clau will launch in ${name}`,
    });
  };

  return (
    <List
      navigationTitle="Terminal app"
      searchBarPlaceholder="Filter terminals"
    >
      <List.Section title="Installed" subtitle="~/.config/clau/raycast.json">
        {terminals.map((terminal) => (
          <List.Item
            key={terminal.id}
            title={terminal.name}
            subtitle={terminal.appPath}
            icon={{ fileIcon: terminal.appPath }}
            accessories={
              terminal.id === current
                ? [{ icon: Icon.Check, text: "active" }]
                : []
            }
            actions={
              <ActionPanel>
                <Action
                  title="Use This Terminal"
                  icon={Icon.Terminal}
                  onAction={() => choose(terminal.id, terminal.name)}
                />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  );
}
