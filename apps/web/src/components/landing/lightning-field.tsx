import { useEffect, useRef } from "react";

type Pt = { x: number; y: number };
type Seg = { a: Pt; b: Pt; w: number };

/**
 * Midpoint-displacement lightning: split every segment, nudge its midpoint
 * sideways, halve the nudge, repeat. Some midpoints sprout a thinner branch.
 */
function makeBolt(from: Pt, to: Pt, rand: () => number): Seg[] {
  let segs: Seg[] = [{ a: from, b: to, w: 1 }];
  let offset = Math.hypot(to.x - from.x, to.y - from.y) * 0.22;
  for (let gen = 0; gen < 6; gen++) {
    const next: Seg[] = [];
    for (const s of segs) {
      const dx = s.b.x - s.a.x;
      const dy = s.b.y - s.a.y;
      const len = Math.hypot(dx, dy) || 1;
      const k = (rand() * 2 - 1) * offset;
      const mid = {
        x: (s.a.x + s.b.x) / 2 - (dy / len) * k,
        y: (s.a.y + s.b.y) / 2 + (dx / len) * k,
      };
      next.push({ a: s.a, b: mid, w: s.w }, { a: mid, b: s.b, w: s.w });
      if (gen < 4 && s.w > 0.45 && rand() < 0.28) {
        const turn = (rand() < 0.5 ? -1 : 1) * (0.35 + rand() * 0.4);
        const bx = mid.x - s.a.x;
        const by = mid.y - s.a.y;
        const reach = 0.7 + rand() * 0.5;
        next.push({
          a: mid,
          b: {
            x: mid.x + (bx * Math.cos(turn) - by * Math.sin(turn)) * reach,
            y: mid.y + (bx * Math.sin(turn) + by * Math.cos(turn)) * reach,
          },
          w: s.w * 0.5,
        });
      }
    }
    segs = next;
    offset /= 2;
  }
  return segs;
}

// Bright hit, a dip, a second flicker, then a long fade. Runs on the compositor.
const FLASH: Keyframe[] = [
  { opacity: 0 },
  { opacity: 1, offset: 0.06 },
  { opacity: 0.3, offset: 0.13 },
  { opacity: 0.9, offset: 0.21 },
  { opacity: 0 },
];

/**
 * Hero backdrop: an occasional branching lightning strike along the edges of
 * the hero. Each bolt is drawn once (no canvas blur), then flashed with a CSS
 * opacity animation, so a strike costs one cheap draw and no per-frame work.
 * Idle between strikes, paused off-screen or in a hidden tab, and off for
 * prefers-reduced-motion.
 */
export function LightningField({ className }: { className?: string }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let visible = true;
    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting;
    });
    io.observe(canvas);

    const rand = Math.random;
    let side = rand() < 0.5 ? -1 : 1;
    let timer = 0;
    let flash: Animation | undefined;

    const strike = () => {
      timer = window.setTimeout(strike, 3200 + rand() * 3800);
      const width = canvas.clientWidth;
      const height = canvas.clientHeight;
      if (!visible || document.hidden || width === 0) return;

      // Size the backing store only when a strike is drawn; DPR capped for cost.
      const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      if (canvas.width !== Math.round(width * dpr)) canvas.width = Math.round(width * dpr);
      if (canvas.height !== Math.round(height * dpr)) canvas.height = Math.round(height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, width, height);

      // Alternate sides so strikes frame the headline instead of crossing it.
      side = -side;
      const edge = side < 0 ? 0.06 + rand() * 0.2 : 0.74 + rand() * 0.2;
      const from = { x: width * edge, y: -10 };
      const to = { x: from.x - side * (40 + rand() * 120), y: height * (0.55 + rand() * 0.3) };
      const segs = makeBolt(from, to, rand);
      const dark = document.documentElement.classList.contains("dark");
      const glow = dark ? "76, 195, 255" : "0, 132, 209";
      const core = dark ? "235, 250, 255" : "30, 110, 200";

      const wash = ctx.createRadialGradient(from.x, 0, 0, from.x, 0, height * 0.9);
      wash.addColorStop(0, `rgba(${glow}, ${dark ? 0.12 : 0.08})`);
      wash.addColorStop(1, `rgba(${glow}, 0)`);
      ctx.fillStyle = wash;
      ctx.fillRect(0, 0, width, height);

      // Glow from stacked translucent strokes instead of shadowBlur.
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      for (const [lw, rgb, alpha] of [
        [12, glow, 0.05],
        [6, glow, 0.12],
        [2.6, glow, 0.5],
        [1.1, core, 0.95],
      ] as const) {
        for (const s of segs) {
          ctx.strokeStyle = `rgba(${rgb}, ${alpha * s.w})`;
          ctx.lineWidth = lw * Math.max(0.35, s.w);
          ctx.beginPath();
          ctx.moveTo(s.a.x, s.a.y);
          ctx.lineTo(s.b.x, s.b.y);
          ctx.stroke();
        }
      }

      flash?.cancel();
      flash = canvas.animate(FLASH, { duration: 950, easing: "ease-out", fill: "forwards" });
    };
    timer = window.setTimeout(strike, 900);

    return () => {
      window.clearTimeout(timer);
      flash?.cancel();
      io.disconnect();
    };
  }, []);

  return <canvas ref={ref} aria-hidden className={className} style={{ opacity: 0 }} />;
}
