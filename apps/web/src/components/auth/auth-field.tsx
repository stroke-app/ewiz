import { EyeIcon, EyeOffIcon } from "lucide-react";
import * as React from "react";

import { Input } from "#/components/ui/input";
import { Label } from "#/components/ui/label";

/**
 * Labeled input with a leading icon (and, for passwords, a trailing show/hide
 * toggle). Matches the auth-screen field style: taller control, red required
 * asterisk, muted inline icon.
 */
export function AuthField({
  id,
  label,
  icon,
  type = "text",
  required,
  rightSlot,
  ...props
}: React.ComponentProps<"input"> & {
  label: string;
  icon: React.ReactNode;
  /** Optional element rendered to the right of the label (e.g. "Forgot password?"). */
  rightSlot?: React.ReactNode;
}) {
  const [show, setShow] = React.useState(false);
  const isPassword = type === "password";
  const inputType = isPassword ? (show ? "text" : "password") : type;

  return (
    <div className="grid gap-2">
      <div className="flex items-center justify-between">
        <Label htmlFor={id}>
          {label}
          {required ? <span className="ml-0.5 text-destructive">*</span> : null}
        </Label>
        {rightSlot}
      </div>
      <div className="relative">
        <span className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-muted-foreground [&_svg]:size-4">
          {icon}
        </span>
        <Input
          id={id}
          type={inputType}
          className={"h-10 pl-9" + (isPassword ? " pr-9" : "")}
          {...props}
        />
        {isPassword ? (
          <button
            type="button"
            onClick={() => setShow((s) => !s)}
            aria-label={show ? "Hide password" : "Show password"}
            className="absolute top-1/2 right-2.5 -translate-y-1/2 text-muted-foreground transition-colors hover:text-foreground"
          >
            {show ? <EyeOffIcon className="size-4" /> : <EyeIcon className="size-4" />}
          </button>
        ) : null}
      </div>
    </div>
  );
}
