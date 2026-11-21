import { HugeiconsIcon, type IconSvgElement } from "@hugeicons/react";

import { cn } from "#/lib/utils";

/**
 * Thin wrapper over Hugeicons so call sites read like the old lucide ones:
 * `<Icon icon={SomeIcon} className="size-4 text-primary" />`. Defaults to a
 * 16px stroke icon that inherits `currentColor`.
 */
export function Icon({
  icon,
  className,
  strokeWidth = 1.8,
  ...props
}: {
  icon: IconSvgElement;
  className?: string;
  strokeWidth?: number;
} & Omit<React.ComponentProps<typeof HugeiconsIcon>, "icon" | "className" | "strokeWidth">) {
  return (
    <HugeiconsIcon
      icon={icon}
      strokeWidth={strokeWidth}
      className={cn("size-4 shrink-0", className)}
      {...props}
    />
  );
}
