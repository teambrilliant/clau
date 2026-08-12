import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const run = promisify(execFile);

const PATH_PREFIX =
  "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";

const SOURCE_DIRS = [
  process.env.CLAU_HOME,
  join(homedir(), ".zshrc.d"),
  join(homedir(), ".claude"),
  join(homedir(), ".config/clau"),
];

export async function zsh(script: string, cwd?: string): Promise<string> {
  const { stdout } = await run("/bin/zsh", ["-c", script], {
    cwd,
    env: { ...process.env, PATH: `${PATH_PREFIX}:${process.env.PATH ?? ""}` },
    maxBuffer: 16 * 1024 * 1024,
  });
  return stdout;
}

function sourceDir(): string {
  for (const dir of SOURCE_DIRS) {
    if (dir && existsSync(join(dir, "clau.zsh"))) return dir;
  }
  throw new Error(
    "clau.zsh not found — set CLAU_HOME to the directory holding it",
  );
}

export function clauPrelude(files: string[]): string {
  const dir = sourceDir();
  return files
    .map((file) => `source ${quoteForShell(join(dir, file))}`)
    .join("; ");
}

export async function clauJson(cwd: string): Promise<string> {
  return zsh(`${clauPrelude(["clau.zsh"])}; clau --json`, cwd);
}

export function quoteForShell(value: string): string {
  return `'${value.replaceAll("'", `'\\''`)}'`;
}
