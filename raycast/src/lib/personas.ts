import { clauJson } from "./shell";

export type Persona = {
  path: string;
  name: string;
  dir: string;
  group: string;
  color: string;
  origin: "repo" | "global";
  hasMcp: boolean;
  hasEnv: boolean;
  hasPrompt: boolean;
};

export type ClauState = {
  cwd: string;
  roots: { local: string; global: string };
  scratch: string;
  personas: Persona[];
};

export async function loadPersonas(cwd: string): Promise<ClauState> {
  const raw = await clauJson(cwd);
  return JSON.parse(raw) as ClauState;
}

const SGR_COLORS: Record<string, string> = {
  "41": "#e05252",
  "42": "#4caf50",
  "43": "#e0b552",
  "44": "#4a7fd0",
  "45": "#a05ad0",
  "46": "#3fa9a9",
};

export function personaTint(color: string): string | undefined {
  if (!color) return undefined;
  const parts = color.split(";");
  const background = parts.find((p) => SGR_COLORS[p]);
  if (background) return SGR_COLORS[background];
  const idx = parts.indexOf("48");
  if (idx >= 0 && parts[idx + 1] === "5" && parts[idx + 2])
    return xterm256(Number(parts[idx + 2]));
  const fg = parts.indexOf("38");
  if (fg >= 0 && parts[fg + 1] === "5" && parts[fg + 2])
    return xterm256(Number(parts[fg + 2]));
  return undefined;
}

function xterm256(n: number): string | undefined {
  if (Number.isNaN(n)) return undefined;
  if (n >= 232) {
    const v = 8 + (n - 232) * 10;
    return rgb(v, v, v);
  }
  if (n >= 16) {
    const c = n - 16;
    const steps = [0, 95, 135, 175, 215, 255];
    return rgb(
      steps[Math.floor(c / 36)],
      steps[Math.floor((c % 36) / 6)],
      steps[c % 6],
    );
  }
  const basic = [
    "#000000",
    "#cd3131",
    "#0dbc79",
    "#e5e510",
    "#2472c8",
    "#bc3fbc",
    "#11a8cd",
    "#e5e5e5",
    "#666666",
    "#f14c4c",
    "#23d18b",
    "#f5f543",
    "#3b8eea",
    "#d670d6",
    "#29b8db",
    "#ffffff",
  ];
  return basic[n];
}

function rgb(r: number, g: number, b: number): string {
  const hex = (v: number) => v.toString(16).padStart(2, "0");
  return `#${hex(r)}${hex(g)}${hex(b)}`;
}
