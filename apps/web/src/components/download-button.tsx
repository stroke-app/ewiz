import { Link } from "@tanstack/react-router";
import { DownloadIcon } from "lucide-react";

import { Button } from "#/components/ui/button";
import { cn } from "#/lib/utils";

export function DownloadButton({
  variant = "default",
  className,
}: {
  variant?: "default" | "outline";
  className?: string;
}) {
  return (
    <Button
      render={<Link to="/download" />}
      nativeButton={false}
      variant={variant}
      className={cn("text-[15px]", className)}
    >
      Download
      <DownloadIcon />
    </Button>
  );
}
