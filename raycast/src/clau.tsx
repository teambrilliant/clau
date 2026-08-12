import {
  Action,
  ActionPanel,
  Icon,
  List,
  showToast,
  Toast,
} from "@raycast/api";
import { useEffect, useState } from "react";
import { loadFolders, type Folder } from "./lib/folders";
import { PersonaList } from "./components/persona-list";

export default function Command() {
  const [folders, setFolders] = useState<Folder[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadFolders()
      .then(setFolders)
      .catch((error: unknown) => {
        showToast({
          style: Toast.Style.Failure,
          title: "Could not read folders",
          message: error instanceof Error ? error.message : String(error),
        });
      })
      .finally(() => setLoading(false));
  }, []);

  return (
    <List isLoading={loading} searchBarPlaceholder="Filter folders">
      {folders.map((folder) => (
        <List.Item
          key={folder.path}
          title={folder.name}
          subtitle={folder.path.replace(process.env.HOME ?? "", "~")}
          icon={Icon.Folder}
          accessories={folder.sources.map((source) => ({ tag: source }))}
          actions={
            <ActionPanel>
              <Action.Push
                title="Choose Persona"
                icon={Icon.Person}
                target={
                  <PersonaList
                    cwd={folder.path}
                    navigationTitle={folder.name}
                  />
                }
              />
              <Action.ShowInFinder path={folder.path} />
              <Action.CopyToClipboard title="Copy Path" content={folder.path} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
