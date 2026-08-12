import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export type Session = {
  id: string;
  file: string;
  modified: Date;
  preview: string;
};

function slugFor(cwd: string): string {
  return cwd.replaceAll("/", "-").replaceAll(".", "-");
}

function firstUserMessage(file: string): string {
  try {
    const head = readFileSync(file, "utf8").slice(0, 200_000);
    for (const line of head.split("\n")) {
      if (!line.trim()) continue;
      const entry: unknown = JSON.parse(line);
      if (!entry || typeof entry !== "object") continue;
      const record = entry as Record<string, unknown>;
      if (record.type !== "user") continue;
      const message = record.message;
      if (!message || typeof message !== "object") continue;
      const content = (message as Record<string, unknown>).content;
      if (typeof content === "string") return content.slice(0, 120);
      if (Array.isArray(content)) {
        for (const part of content) {
          if (part && typeof part === "object") {
            const text = (part as Record<string, unknown>).text;
            if (typeof text === "string") return text.slice(0, 120);
          }
        }
      }
    }
  } catch {
    return "";
  }
  return "";
}

export function loadSessions(cwd: string): Session[] {
  const dir = join(homedir(), ".claude/projects", slugFor(cwd));
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith(".jsonl"))
    .map((f) => {
      const file = join(dir, f);
      return {
        id: f.replace(/\.jsonl$/, ""),
        file,
        modified: statSync(file).mtime,
        preview: firstUserMessage(file),
      };
    })
    .sort((a, b) => b.modified.getTime() - a.modified.getTime())
    .slice(0, 40);
}
