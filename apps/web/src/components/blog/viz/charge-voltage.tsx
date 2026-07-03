import { useEffect, useRef, useState } from "react";

import { fitCanvas, useThemeColors } from "./canvas-utils";
import { Figure, Slider } from "./figure";

/** Illustrative open-circuit voltage curve: steep at the ends, flatter in the middle. */
function voltageAt(socFraction: number): number {
  return 3.0 + 1.2 * Math.pow(socFraction, 0.55);
}

function stressWord(soc: number): string {
  if (soc <= 60) return "gentle";
  if (soc <= 80) return "easy";
  if (soc <= 90) return "stressful";
  return "hard on the cell";
}

export function ChargeVoltage() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [soc, setSoc] = useState(80);
  const palette = useThemeColors();

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const p = palette;

    const render = () => {
      const { ctx, w, h } = fitCanvas(canvas);
      if (!ctx) return;
      ctx.clearRect(0, 0, w, h);

      const ml = 46;
      const mr = 14;
      const mt = 40;
      const mb = 26;
      const plotW = w - ml - mr;
      const plotH = h - mt - mb;
      const vMin = 3.0;
      const vMax = 4.2;

      const xAt = (pct: number) => ml + (pct / 100) * plotW;
      const yAt = (v: number) => mt + (1 - (v - vMin) / (vMax - vMin)) * plotH;

      // high-stress zone (> 80%)
      ctx.fillStyle = p.danger;
      ctx.globalAlpha = 0.09;
      ctx.fillRect(xAt(80), mt, xAt(100) - xAt(80), plotH);
      ctx.globalAlpha = 1;
      ctx.fillStyle = p.danger;
      ctx.font = "600 10px Inter, system-ui, sans-serif";
      ctx.textAlign = "right";
      ctx.textBaseline = "top";
      ctx.globalAlpha = 0.8;
      ctx.fillText("high-stress zone", xAt(100) - 6, mt + 6);
      ctx.globalAlpha = 1;

      // grid + y labels (volts)
      ctx.strokeStyle = p.grid;
      ctx.fillStyle = p.muted;
      ctx.lineWidth = 1;
      ctx.font = "400 10px 'Geist Mono', ui-monospace, monospace";
      ctx.textAlign = "right";
      ctx.textBaseline = "middle";
      for (const v of [3.0, 3.6, 4.2]) {
        const y = yAt(v);
        ctx.beginPath();
        ctx.moveTo(ml, y);
        ctx.lineTo(w - mr, y);
        ctx.stroke();
        ctx.fillText(`${v.toFixed(1)}V`, ml - 6, y);
      }
      // x labels (%)
      ctx.textAlign = "center";
      ctx.textBaseline = "top";
      for (const pct of [0, 50, 80, 100]) {
        ctx.fillText(`${pct}%`, xAt(pct), h - mb + 6);
      }

      // curve
      ctx.strokeStyle = p.primary;
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      for (let i = 0; i <= 100; i++) {
        const x = xAt(i);
        const y = yAt(voltageAt(i / 100));
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.stroke();

      // marker
      const mx = xAt(soc);
      const my = yAt(voltageAt(soc / 100));
      ctx.strokeStyle = p.track;
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      ctx.moveTo(mx, mt);
      ctx.lineTo(mx, h - mb);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = soc > 80 ? p.danger : p.primary;
      ctx.beginPath();
      ctx.arc(mx, my, 5, 0, Math.PI * 2);
      ctx.fill();

      // readout
      ctx.textAlign = "left";
      ctx.textBaseline = "alphabetic";
      ctx.fillStyle = p.ink;
      ctx.font = "700 20px 'Bricolage Grotesque', system-ui, sans-serif";
      ctx.fillText(`${voltageAt(soc / 100).toFixed(2)} V`, ml, 26);
      ctx.fillStyle = soc > 80 ? p.danger : p.muted;
      ctx.font = "500 12px Inter, system-ui, sans-serif";
      ctx.textAlign = "right";
      ctx.fillText(`${soc}% · ${stressWord(soc)}`, w - mr, 26);
    };

    render();
    const ro = new ResizeObserver(render);
    ro.observe(canvas);
    return () => ro.disconnect();
  }, [soc, palette]);

  return (
    <Figure
      controls={
        <Slider
          label="Charge level"
          value={soc}
          display={`${soc}%`}
          min={0}
          max={100}
          onChange={setSoc}
        />
      }
      caption={
        <>
          Voltage is the dial that matters. Dragging past ~80% pushes the cell into the red zone
          above ~4.0&nbsp;V, where the electrolyte oxidizes fastest. Capping the charge at 80% gives
          up a sliver of runtime for a dramatically longer life.
        </>
      }
    >
      <canvas ref={canvasRef} className="block h-[240px] w-full" />
    </Figure>
  );
}
