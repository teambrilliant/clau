import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, basename } from "node:path";
import { zsh } from "./shell";

export type FolderSource = "zoxide" | "vscode" | "claude";

export type Folder = {
  path: string;
  name: string;
  sources: FolderSource[];
  rank: number;
};

async function fromZoxide(): Promise<Map<string, number>> {
  const out = new Map<string, number>();
  try {
    const stdout = await zsh("zoxide query -l");
    stdout
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean)
      .forEach((p, i) => out.set(p, i));
  } catch {
    return out;
  }
  return out;
}

function fromVsCode(): string[] {
  const file = join(
    homedir(),
    "Library/Application Support/Code/User/globalStorage/storage.json",
  );
  if (!existsSync(file)) return [];
  try {
    const parsed: unknown = JSON.parse(readFileSync(file, "utf8"));
    const uris: string[] = [];
    const walk = (node: unknown) => {
      if (Array.isArray(node)) {
        node.forEach(walk);
        return;
      }
      if (node && typeof node === "object") {
        for (const [key, value] of Object.entries(
          node as Record<string, unknown>,
        )) {
          if (key === "folderUri" && typeof value === "string")
            uris.push(value);
          else walk(value);
        }
      }
    };
    walk(parsed);
    return uris
      .filter((u) => u.startsWith("file://"))
      .map((u) => decodeURIComponent(u.replace("file://", "")));
  } catch {
    return [];
  }
}

function fromClaude(): string[] {
  const file = join(homedir(), ".claude.json");
  if (!existsSync(file)) return [];
  try {
    const parsed: unknown = JSON.parse(readFileSync(file, "utf8"));
    if (!parsed || typeof parsed !== "object") return [];
    const projects = (parsed as Record<string, unknown>).projects;
    if (!projects || typeof projects !== "object") return [];
    return Object.keys(projects as Record<string, unknown>);
  } catch {
    return [];
  }
}

export async function loadFolders(): Promise<Folder[]> {
  const zoxide = await fromZoxide();
  const merged = new Map<string, Folder>();

  const add = (path: string, source: FolderSource, rank: number) => {
    if (!path || !existsSync(path)) return;
    const found = merged.get(path);
    if (found) {
      if (!found.sources.includes(source)) found.sources.push(source);
      found.rank = Math.min(found.rank, rank);
      return;
    }
    merged.set(path, { path, name: basename(path), sources: [source], rank });
  };

  for (const [path, rank] of zoxide) add(path, "zoxide", rank);
  fromVsCode().forEach((p, i) => add(p, "vscode", i));
  fromClaude().forEach((p, i) => add(p, "claude", i + 1000));

  return [...merged.values()].sort((a, b) => {
    const weight = (f: Folder) =>
      (f.sources.includes("vscode") ? -500 : 0) + f.rank;
    return weight(a) - weight(b);
  });
}
