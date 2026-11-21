import { useEffect, useState } from "react";

/** Canvas-safe palettes (hex/rgba — no oklch, for cross-browser fillStyle). */
export interface Palette {
  ink: string;
  muted: string;
  grid: string;
  track: string;
  primary: string;
  primaryDim: string;
  green: string;
  orange: string;
  danger: string;
  anode: string;
  anodeFill: string;
  cathode: string;
  cathodeFill: string;
  ion: string;
  electron: string;
}

const DARK: Palette = {
  ink: "#e6e6e9",
  muted: "#8b8b93",
  grid: "rgba(255,255,255,0.07)",
  track: "rgba(255,255,255,0.10)",
  primary: "#3b82f6",
  primaryDim: "rgba(59,130,246,0.16)",
  green: "#34d399",
  orange: "#fbbf24",
  danger: "#f87171",
  anode: "#3f3f46",
  anodeFill: "#60a5fa",
  cathode: "#4b5563",
  cathodeFill: "#a78bfa",
  ion: "#93c5fd",
  electron: "#fcd34d",
};

const LIGHT: Palette = {
  ink: "#1f2937",
  muted: "#6b7280",
  grid: "rgba(0,0,0,0.07)",
  track: "rgba(0,0,0,0.09)",
  primary: "#2563eb",
  primaryDim: "rgba(37,99,235,0.12)",
  green: "#059669",
  orange: "#d97706",
  danger: "#dc2626",
  anode: "#d4d4d8",
  anodeFill: "#3b82f6",
  cathode: "#9ca3af",
  cathodeFill: "#7c3aed",
  ion: "#2563eb",
  electron: "#b45309",
};

/** Tracks the app's light/dark class on <html> and returns the matching palette. */
export function useThemeColors(): Palette {
  const [dark, setDark] = useState(true);
  useEffect(() => {
    const el = document.documentElement;
    const update = () => setDark(el.classList.contains("dark"));
    update();
    const obs = new MutationObserver(update);
    obs.observe(el, { attributes: true, attributeFilter: ["class"] });
    return () => obs.disconnect();
  }, []);
  return dark ? DARK : LIGHT;
}

export function prefersReducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

/** HiDPI-fit a canvas to its CSS box; returns the 2D context and CSS w/h. */
export function fitCanvas(c: HTMLCanvasElement): {
  ctx: CanvasRenderingContext2D | null;
  w: number;
  h: number;
} {
  const ctx = c.getContext("2d");
  const dpr = Math.min(typeof window !== "undefined" ? window.devicePixelRatio || 1 : 1, 2);
  const r = c.getBoundingClientRect();
  const w = Math.max(1, Math.round(r.width));
  const h = Math.max(1, Math.round(r.height));
  c.width = w * dpr;
  c.height = h * dpr;
  if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, w, h };
}

export function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
): void {
  const rr = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

export const clamp = (v: number, lo: number, hi: number): number =>
  Math.max(lo, Math.min(hi, v));
