"use client";

import {
  CheckmarkCircle02Icon,
  DangerIcon,
  InformationCircleIcon,
  Loading03Icon,
  RemoveCircleIcon,
} from "@hugeicons/core-free-icons";
import { Toaster as Sonner, type ToasterProps } from "sonner";

import { Icon } from "#/components/icon";
import { useTheme } from "#/components/theme-provider";

const Toaster = ({ ...props }: ToasterProps) => {
  const { theme } = useTheme();

  return (
    <Sonner
      theme={theme as ToasterProps["theme"]}
      className="toaster group"
      icons={{
        success: <Icon icon={CheckmarkCircle02Icon} className="size-4" />,
        info: <Icon icon={InformationCircleIcon} className="size-4" />,
        warning: <Icon icon={DangerIcon} className="size-4" />,
        error: <Icon icon={RemoveCircleIcon} className="size-4" />,
        loading: <Icon icon={Loading03Icon} className="size-4 animate-spin" />,
      }}
      style={
        {
          "--normal-bg": "var(--popover)",
          "--normal-text": "var(--popover-foreground)",
          "--normal-border": "var(--border)",
          "--border-radius": "var(--radius)",
        } as React.CSSProperties
      }
      toastOptions={{
        classNames: {
          toast: "cn-toast",
        },
      }}
      {...props}
    />
  );
};

export { Toaster };
