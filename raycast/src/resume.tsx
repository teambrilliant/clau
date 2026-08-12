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
import { loadSessions, type Session } from "./lib/sessions";
import { PersonaList } from "./components/persona-list";

function SessionList({ cwd, name }: { cwd: string; name: string }) {
  const sessions = loadSessions(cwd);
  return (
    <List
      navigationTitle={`Sessions · ${name}`}
      searchBarPlaceholder="Filter sessions"
    >
      {sessions.length === 0 && (
        <List.EmptyView
          title="No sessions recorded for this folder"
          icon={Icon.Clock}
        />
      )}
      {sessions.map((session: Session) => (
        <List.Item
          key={session.id}
          title={session.preview || session.id}
          subtitle={session.preview ? session.id.slice(0, 8) : undefined}
          icon={Icon.Clock}
          accessories={[{ date: session.modified }]}
          actions={
            <ActionPanel>
              <Action.Push
                title="Choose Persona"
                icon={Icon.Person}
                target={
                  <PersonaList
                    cwd={cwd}
                    extraArgs={["--resume", session.id]}
                    navigationTitle={`Resume ${session.id.slice(0, 8)}`}
                  />
                }
              />
              <Action.Push
                title="Choose Persona and Fork"
                icon={Icon.Duplicate}
                target={
                  <PersonaList
                    cwd={cwd}
                    extraArgs={["--resume", session.id, "--fork-session"]}
                    navigationTitle={`Fork ${session.id.slice(0, 8)}`}
                  />
                }
              />
              <Action.CopyToClipboard
                title="Copy Session ID"
                content={session.id}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

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
          actions={
            <ActionPanel>
              <Action.Push
                title="Show Sessions"
                icon={Icon.Clock}
                target={<SessionList cwd={folder.path} name={folder.name} />}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
