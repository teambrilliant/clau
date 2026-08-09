import { execFile } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { promisify } from "node:util";
import { quoteForShell } from "./shell";

const run = promisify(execFile);

export type TerminalId = "ghostty" | "iterm" | "terminal" | "wezterm" | "kitty";

export type TerminalApp = {
  id: TerminalId;
  name: string;
  appPath: string;
};

const APPS: TerminalApp[] = [
  { id: "ghostty", name: "Ghostty", appPath: "/Applications/Ghostty.app" },
  { id: "iterm", name: "iTerm", appPath: "/Applications/iTerm.app" },
  {
    id: "terminal",
    name: "Terminal",
    appPath: "/System/Applications/Utilities/Terminal.app",
  },
  { id: "wezterm", name: "WezTerm", appPath: "/Applications/WezTerm.app" },
  { id: "kitty", name: "kitty", appPath: "/Applications/kitty.app" },
];

const CONFIG = join(homedir(), ".config/clau/raycast.json");

export function installedTerminals(): TerminalApp[] {
  return APPS.filter((a) => existsSync(a.appPath));
}

export function readTerminal(): TerminalId {
  try {
    const parsed: unknown = JSON.parse(readFileSync(CONFIG, "utf8"));
    if (parsed && typeof parsed === "object") {
      const value = (parsed as Record<string, unknown>).terminal;
      const known = APPS.find((a) => a.id === value);
      if (known) return known.id;
    }
  } catch {
    /* fall through to default */
  }
  const first = installedTerminals()[0];
  return first ? first.id : "terminal";
}

export function writeTerminal(id: TerminalId): void {
  mkdirSync(dirname(CONFIG), { recursive: true });
  writeFileSync(CONFIG, `${JSON.stringify({ terminal: id }, null, 2)}\n`);
}

export function terminalName(id: TerminalId): string {
  return APPS.find((a) => a.id === id)?.name ?? id;
}

const ITERM_SCRIPT = `on run argv
  set cmd to item 1 of argv
  tell application "iTerm"
    activate
    set newWindow to (create window with default profile)
    tell current session of newWindow
      write text cmd
    end tell
  end tell
end run`;

const TERMINAL_SCRIPT = `on run argv
  set cmd to item 1 of argv
  tell application "Terminal"
    activate
    do script cmd
  end tell
end run`;

export async function launch(
  cwd: string,
  command: string,
  id: TerminalId,
): Promise<void> {
  const inner = `cd ${quoteForShell(cwd)} && ${command}`;

  if (id === "ghostty") {
    await run("/usr/bin/open", [
      "-na",
      "Ghostty.app",
      "--args",
      "-e",
      "zsh",
      "-ilc",
      inner,
    ]);
    return;
  }
  if (id === "wezterm") {
    await run("/usr/bin/open", [
      "-na",
      "WezTerm.app",
      "--args",
      "start",
      "--",
      "zsh",
      "-ilc",
      inner,
    ]);
    return;
  }
  if (id === "kitty") {
    await run("/usr/bin/open", [
      "-na",
      "kitty.app",
      "--args",
      "zsh",
      "-ilc",
      inner,
    ]);
    return;
  }
  const script = id === "iterm" ? ITERM_SCRIPT : TERMINAL_SCRIPT;
  await run("/usr/bin/osascript", ["-e", script, inner]);
}
