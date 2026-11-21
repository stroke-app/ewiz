import { ContrastIcon } from "@hugeicons/core-free-icons";

import { Icon } from "#/components/icon";
import { useTheme } from "#/components/theme-provider";
import { Button } from "#/components/ui/button";

/**
 * One-tap light/dark toggle. Reads the class the ThemeProvider applied to
 * <html> so it flips relative to what's actually on screen (even under
 * `system`). Deliberately a plain button — no dropdown/menu dependency.
 */
export function ThemeToggle() {
  const { setTheme } = useTheme();

  return (
    <Button
      variant="outline"
      size="icon"
      aria-label="Toggle theme"
      onClick={() => {
        const isDark = document.documentElement.classList.contains("dark");
        setTheme(isDark ? "light" : "dark");
      }}
    >
      <Icon icon={ContrastIcon} className="size-[1.1rem]" />
      <span className="sr-only">Toggle theme</span>
    </Button>
  );
}
