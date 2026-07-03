import { useEffect, useRef, useState } from "react";

import { fitCanvas, useThemeColors } from "./canvas-utils";
import { Figure, Slider } from "./figure";

/** Illustrative aging model (directionally right, not a spec):
 *  voltage stress doubles ~every 12% of ceiling above 80%, and heat doubles
 *  reaction rate ~every 10 °C (Arrhenius). The two multiply. */
function agingRate(ceiling: number, temp: number): number {
  const fV = Math.pow(2, (ceiling - 80) / 12);
  const fT = Math.pow(2, (temp - 25) / 10);
  return fV * fT;
}

const LAMBDA = 0.005325; // baseline (rate 1) → ~88% health after 24 months

function healthAt(months: number, rate: number): number {
  return 100 * Math.exp(-LAMBDA * rate * months);
}

export function AgingExplorer() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [ceiling, setCeiling] = useState(100);
  const [temp, setTemp] = useState(35);
  const palette = useThemeColors();

  const rate = agingRate(ceiling, temp);
  const health2y = healthAt(24, rate);
  const healthColor =
    health2y >= 85 ? palette.green : health2y >= 70 ? palette.orange : palette.danger;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const p = palette;

    const render = () => {
      const { ctx, w, h } = fitCanvas(canvas);
      if (!ctx) return;
      ctx.clearRect(0, 0, w, h);

      const ml = 42;
      const mr = 14;
      const mt = 16;
      const mb = 26;
      const plotW = w - ml - mr;
      const plotH = h - mt - mb;
      const months = 24;

      const xAt = (m: number) => ml + (m / months) * plotW;
      const yAt = (pct: number) => mt + (1 - (pct - 60) / 40) * plotH; // show 60–100%

      // grid + labels
      ctx.strokeStyle = p.grid;
      ctx.fillStyle = p.muted;
      ctx.lineWidth = 1;
      ctx.font = "400 10px 'Geist Mono', ui-monospace, monospace";
      ctx.textAlign = "right";
      ctx.textBaseline = "middle";
      for (const pct of [100, 90, 80, 70, 60]) {
        const y = yAt(pct);
        ctx.beginPath();
        ctx.moveTo(ml, y);
        ctx.lineTo(w - mr, y);
        ctx.stroke();
        ctx.fillText(`${pct}%`, ml - 6, y);
      }
      ctx.textAlign = "center";
      ctx.textBaseline = "top";
      for (const m of [0, 12, 24]) {
        ctx.fillText(m === 0 ? "now" : `${m}mo`, xAt(m), h - mb + 6);
      }

      const plotCurve = (r: number, color: string, dashed: boolean) => {
        ctx.strokeStyle = color;
        ctx.lineWidth = dashed ? 1.5 : 2.5;
        ctx.setLineDash(dashed ? [4, 4] : []);
        ctx.beginPath();
        for (let m = 0; m <= months; m++) {
          const x = xAt(m);
          const y = yAt(Math.max(60, healthAt(m, r)));
          if (m === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.stroke();
        ctx.setLineDash([]);
      };

      // ideal reference (80% / 25°C) then current
      plotCurve(1, p.muted, true);
      plotCurve(rate, healthColor, false);

      // endpoint dot on current curve
      const ey = yAt(Math.max(60, health2y));
      ctx.fillStyle = healthColor;
      ctx.beginPath();
      ctx.arc(xAt(24), ey, 4.5, 0, Math.PI * 2);
      ctx.fill();

      // legend
      ctx.font = "500 10px Inter, system-ui, sans-serif";
      ctx.textAlign = "left";
      ctx.textBaseline = "top";
      ctx.fillStyle = p.muted;
      ctx.fillText("– – ideal (80% · 25°C)", ml + 4, mt + 4);
    };

    render();
    const ro = new ResizeObserver(render);
    ro.observe(canvas);
    return () => ro.disconnect();
  }, [ceiling, temp, palette, rate, health2y, healthColor]);

  return (
    <Figure
      controls={
        <div className="flex flex-col gap-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <Slider
              label="Charge ceiling"
              value={ceiling}
              display={`${ceiling}%`}
              min={60}
              max={100}
              step={5}
              onChange={setCeiling}
            />
            <Slider
              label="Temperature"
              value={temp}
              display={`${temp}°C`}
              min={10}
              max={45}
              onChange={setTemp}
            />
          </div>
          <div className="flex items-center justify-between border-t border-border/60 pt-3">
            <div>
              <p className="text-xs text-muted-foreground">Aging rate</p>
              <p className="font-mono text-lg font-semibold tabular-nums">
                {rate < 1 ? rate.toFixed(2) : rate.toFixed(1)}× baseline
              </p>
            </div>
            <div className="text-right">
              <p className="text-xs text-muted-foreground">Health after 2 years</p>
              <p
                className="font-display text-2xl font-bold tabular-nums"
                style={{ color: healthColor }}
              >
                {Math.round(health2y)}%
              </p>
            </div>
          </div>
        </div>
      }
      caption={
        <>
          The two killers <strong className="text-foreground">multiply</strong>. Push the ceiling to
          100% <em>and</em> let it run hot and the aging rate compounds — the curve nose-dives. Pull
          both back toward the dashed ideal and the same battery is still near-full years later.
          (Illustrative model, but the direction is real.)
        </>
      }
    >
      <canvas ref={canvasRef} className="block h-[220px] w-full" />
    </Figure>
  );
}
