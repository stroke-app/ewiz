import { useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";

import { startCheckout } from "#/lib/auth/auth-client";
import { useAuth } from "#/lib/auth/hooks";

/**
 * Shared Dodo Payments checkout action. Checkout is `authenticatedUsersOnly`,
 * so signed-out visitors are sent to log in first, then can buy.
 */
export function useCheckout() {
  const { user, isPending } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);

  const buy = async () => {
    if (isPending || loading) return;

    if (!user) {
      toast.info("Sign in to buy Battlify — it only takes a second.");
      navigate({ to: "/login" });
      return;
    }

    setLoading(true);
    try {
      await startCheckout(`battlify-${user.id}-${Date.now()}`);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Couldn't open checkout. Try again.");
      setLoading(false);
    }
  };

  return { buy, loading };
}
