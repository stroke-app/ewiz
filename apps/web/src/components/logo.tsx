import { cn } from "#/lib/utils";

/** Bump when the icon files in /public change so browsers and the CDN fetch the new art. */
export const ICON_VERSION = "8";

/** The eWiz app icon: the silver volt wizard hat on a graphite squircle (public/ewiz-icon.svg). */
export function AppIcon({ className }: { className?: string }) {
  return (
    <img
      src={`/ewiz-icon.svg?v=${ICON_VERSION}`}
      alt=""
      width={1024}
      height={1024}
      draggable={false}
      className={cn("size-7 select-none", className)}
    />
  );
}

export function Logo({ className }: { className?: string }) {
  return (
    <span className={cn("flex items-center gap-2", className)}>
      <AppIcon className="size-7" />
      <span className="text-lg font-semibold tracking-tight">eWiz</span>
    </span>
  );
}
