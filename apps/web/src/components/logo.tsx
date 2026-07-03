/**
 * Battlify wordmark + mark. Monochrome (currentColor) so it reads on any
 * surface; the bolt picks up the blue accent when `accent` is set.
 */
export function BatteryMark({
  className,
  accent = false,
}: {
  className?: string;
  accent?: boolean;
}) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className={className}
      aria-hidden="true"
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* battery body */}
      <rect
        x="1.75"
        y="6.75"
        width="17"
        height="10.5"
        rx="3"
        stroke="currentColor"
        strokeWidth="1.5"
      />
      {/* terminal */}
      <path
        d="M21.25 10.25v3.5a1.75 1.75 0 0 0 0-3.5Z"
        fill="currentColor"
      />
      {/* bolt */}
      <path
        d="M11.4 8.5 7.9 12.7h2.4l-1 2.8 3.5-4.2h-2.4l1-2.8Z"
        fill={accent ? "var(--color-primary)" : "currentColor"}
      />
    </svg>
  );
}

export function Logo({ className }: { className?: string }) {
  return (
    <span className={"flex items-center gap-2 " + (className ?? "")}>
      <BatteryMark className="size-6 text-foreground" accent />
      <span className="font-display text-lg font-semibold tracking-tight">Battlify</span>
    </span>
  );
}
