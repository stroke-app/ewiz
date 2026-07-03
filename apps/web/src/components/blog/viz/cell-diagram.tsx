import { useEffect, useRef, useState } from "react";

import { Button } from "#/components/ui/button";

import { clamp, fitCanvas, type Palette, prefersReducedMotion, roundRect, useThemeColors } from "./canvas-utils";
import { Figure } from "./figure";

interface Ion {
  x: number; // 0..1 across the electrolyte gap
  lane: number; // 0..1 vertical position
}

export function CellDiagram() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [charging, setCharging] = useState(true);
  const chargingRef = useRef(true);
  const palette = useThemeColors();
  const paletteRef = useRef<Palette>(palette);
  useEffect(() => {
    paletteRef.current = palette;
  }, [palette]);

  const setMode = (c: boolean) => {
    chargingRef.current = c;
    setCharging(c);
  };

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const reduced = prefersReducedMotion();
    let dims = fitCanvas(canvas);
    const ro = new ResizeObserver(() => {
      dims = fitCanvas(canvas);
    });
    ro.observe(canvas);

    const ions: Ion[] = Array.from({ length: 9 }, (_, i) => ({
      x: i / 9,
      lane: 0.14 + 0.72 * ((i * 0.37) % 1),
    }));

    let soc = 0.35;
    let raf = 0;
    let last = performance.now();

    const draw = (dt: number) => {
      const { ctx, w, h } = dims;
      if (!ctx) return;
      const p = paletteRef.current;
      const target = chargingRef.current ? 1 : 0;
      const rate = reduced ? 10 : 0.34; // per second
      soc += clamp(target - soc, -rate * dt, rate * dt);
      soc = clamp(soc, 0, 1);
      const activity = clamp(Math.abs(target - soc) * 3.2, 0, 1);
      const dir = chargingRef.current ? -1 : 1; // ions drift toward anode (left) when charging

      ctx.clearRect(0, 0, w, h);

      const pad = 18;
      const wireY = 24;
      const eTop = 50;
      const eBot = h - 42;
      const eH = eBot - eTop;
      const ew = clamp(w * 0.2, 50, 84);
      const anodeX = pad;
      const cathodeX = w - pad - ew;
      const gapL = anodeX + ew;
      const gapR = cathodeX;
      const anodeMid = anodeX + ew / 2;
      const cathodeMid = cathodeX + ew / 2;

      // ---- external circuit (top wire + load) ----
      ctx.strokeStyle = p.track;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(anodeMid, eTop);
      ctx.lineTo(anodeMid, wireY);
      ctx.lineTo(cathodeMid, wireY);
      ctx.lineTo(cathodeMid, eTop);
      ctx.stroke();
      // load box
      const boxW = 40;
      const boxH = 18;
      const boxX = (anodeMid + cathodeMid) / 2 - boxW / 2;
      ctx.fillStyle = p.track;
      roundRect(ctx, boxX, wireY - boxH / 2, boxW, boxH, 5);
      ctx.fill();
      ctx.fillStyle = p.muted;
      ctx.font = "500 10px Inter, system-ui, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("your Mac", (anodeMid + cathodeMid) / 2, wireY);

      // electrons on the top run: discharge -> left→right, charge -> right→left
      const eStart = anodeMid + 4;
      const eEnd = cathodeMid - 4;
      const eLen = eEnd - eStart;
      const eDir = chargingRef.current ? -1 : 1;
      ctx.fillStyle = p.electron;
      for (let i = 0; i < 7; i++) {
        const phase = (soc * 60 * eDir + i / 7) % 1;
        const t = (phase + 1) % 1;
        const x = eStart + t * eLen;
        if (Math.abs(x - (anodeMid + cathodeMid) / 2) < boxW / 2 + 3) continue;
        ctx.globalAlpha = 0.25 + 0.75 * activity;
        ctx.beginPath();
        ctx.arc(x, wireY, 2.2, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalAlpha = 1;

      // ---- electrodes ----
      const layers = 8;
      const layerGap = 3;
      const layerH = (eH - layerGap * (layers - 1)) / layers;

      const drawElectrode = (x: number, filled: number, fill: string, outline: string) => {
        ctx.strokeStyle = outline;
        ctx.lineWidth = 1.5;
        roundRect(ctx, x, eTop, ew, eH, 8);
        ctx.stroke();
        for (let i = 0; i < layers; i++) {
          const ly = eBot - (i + 1) * layerH - i * layerGap;
          const on = i < filled;
          if (on) {
            ctx.fillStyle = fill;
            roundRect(ctx, x + 6, ly, ew - 12, layerH, 2);
            ctx.fill();
          } else {
            ctx.strokeStyle = p.grid;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x + 6, ly + layerH / 2);
            ctx.lineTo(x + ew - 6, ly + layerH / 2);
            ctx.stroke();
          }
        }
      };

      drawElectrode(anodeX, Math.round(layers * soc), p.anodeFill, p.anode);
      drawElectrode(cathodeX, Math.round(layers * (1 - soc)), p.cathodeFill, p.cathode);

      // ---- lithium ions crossing the electrolyte ----
      const speed = (0.12 + activity * 0.9) * dt;
      ctx.fillStyle = p.ion;
      for (const ion of ions) {
        ion.x += dir * speed;
        if (ion.x > 1) ion.x -= 1;
        if (ion.x < 0) ion.x += 1;
        const x = gapL + 10 + ion.x * (gapR - gapL - 20);
        const y = eTop + 10 + ion.lane * (eH - 20);
        ctx.globalAlpha = 0.2 + 0.8 * activity;
        ctx.beginPath();
        ctx.arc(x, y, 3.2, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalAlpha = 1;

      // ---- labels ----
      ctx.fillStyle = p.muted;
      ctx.font = "600 11px Inter, system-ui, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "top";
      ctx.fillText("Anode", anodeMid, eBot + 8);
      ctx.fillText("Cathode", cathodeMid, eBot + 8);
      ctx.font = "400 10px Inter, system-ui, sans-serif";
      ctx.fillText("graphite", anodeMid, eBot + 22);
      ctx.fillText("metal oxide", cathodeMid, eBot + 22);
      ctx.fillText("electrolyte", (gapL + gapR) / 2, eBot + 8);

      // ---- readout ----
      const voltage = 3.0 + 1.2 * soc;
      ctx.textAlign = "left";
      ctx.textBaseline = "alphabetic";
      ctx.fillStyle = p.ink;
      ctx.font = "700 24px 'Bricolage Grotesque', system-ui, sans-serif";
      ctx.fillText(`${Math.round(soc * 100)}%`, gapL + 8, eTop + 26);
      ctx.fillStyle = p.muted;
      ctx.font = "500 12px 'Geist Mono', ui-monospace, monospace";
      ctx.fillText(`≈ ${voltage.toFixed(2)} V`, gapL + 8, eTop + 44);

      if (!reduced) raf = requestAnimationFrame(step);
    };

    const step = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      draw(dt);
    };

    raf = requestAnimationFrame(step);
    return () => {
      ro.disconnect();
      cancelAnimationFrame(raf);
    };
  }, []);

  return (
    <Figure
      controls={
        <div className="flex items-center gap-2">
          <span className="mr-1 text-sm text-muted-foreground">Direction</span>
          <Button
            size="sm"
            variant={charging ? "default" : "outline"}
            type="button"
            onClick={() => setMode(true)}
          >
            Charge
          </Button>
          <Button
            size="sm"
            variant={!charging ? "default" : "outline"}
            type="button"
            onClick={() => setMode(false)}
          >
            Discharge
          </Button>
        </div>
      }
      caption={
        <>
          A lithium-ion cell, simplified. Hit <strong className="text-foreground">Charge</strong>{" "}
          and lithium ions drift left into the graphite anode; hit{" "}
          <strong className="text-foreground">Discharge</strong> and they flow back to the cathode,
          pushing electrons through your Mac. The percentage is how full the anode is; the voltage
          climbs as it fills.
        </>
      }
    >
      <canvas ref={canvasRef} className="block h-[280px] w-full" />
    </Figure>
  );
}
