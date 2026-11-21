/** Shared frame for an interactive visualization: canvas surface, an optional
 *  controls strip, and a caption. Keeps the article's figures visually uniform. */
export function Figure({
  children,
  controls,
  caption,
}: {
  children: React.ReactNode;
  controls?: React.ReactNode;
  caption?: React.ReactNode;
}) {
  return (
    <figure className="my-10 overflow-hidden rounded-2xl border border-border bg-card">
      <div className="relative">{children}</div>
      {controls ? (
        <div className="border-t border-border/60 px-4 py-3 sm:px-5">{controls}</div>
      ) : null}
      {caption ? (
        <figcaption className="border-t border-border/60 px-4 py-3 text-[13px] leading-relaxed text-muted-foreground sm:px-5">
          {caption}
        </figcaption>
      ) : null}
    </figure>
  );
}

/** A labeled range slider used across the visualizations. */
export function Slider({
  label,
  value,
  display,
  min,
  max,
  step = 1,
  onChange,
}: {
  label: string;
  value: number;
  display: string;
  min: number;
  max: number;
  step?: number;
  onChange: (v: number) => void;
}) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="flex items-center justify-between text-sm">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-mono text-foreground tabular-nums">{display}</span>
      </span>
      <input
        type="range"
        aria-label={label}
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="w-full accent-primary"
      />
    </label>
  );
}
