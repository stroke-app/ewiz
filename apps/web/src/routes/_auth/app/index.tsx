import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { CheckIcon, CopyIcon, LoaderCircleIcon, ShieldCheckIcon, SparklesIcon } from "lucide-react";
import { useEffect, useState } from "react";
import { toast } from "sonner";

import { useCheckout } from "#/components/buy-button";
import { Button } from "#/components/ui/button";
import { useAuthSuspense } from "#/lib/auth/hooks";
import { $claimLicense, type LicenseDTO } from "#/lib/license/functions";
import { licenseQueryOptions } from "#/lib/license/queries";

interface AppSearch {
  purchase?: string;
  payment_id?: string;
}

export const Route = createFileRoute("/_auth/app/")({
  validateSearch: (search: Record<string, unknown>): AppSearch => ({
    purchase: typeof search.purchase === "string" ? search.purchase : undefined,
    payment_id: typeof search.payment_id === "string" ? search.payment_id : undefined,
  }),
  loader: ({ context }) => context.queryClient.ensureQueryData(licenseQueryOptions()),
  component: AppIndex,
});

function AppIndex() {
  const { user } = useAuthSuspense();
  const { purchase, payment_id } = Route.useSearch();
  const navigate = Route.useNavigate();
  const queryClient = useQueryClient();

  const { data: license } = useQuery(licenseQueryOptions());

  const {
    mutate: claimLicense,
    isIdle: claimIsIdle,
    isPending: claimIsPending,
  } = useMutation({
    mutationFn: (paymentId: string) => $claimLicense({ data: { paymentId } }),
    onSuccess: (data) => {
      queryClient.setQueryData(licenseQueryOptions().queryKey, data);
      toast.success("Payment confirmed — your license is ready.");
      // Clean the checkout params out of the URL so a refresh doesn't re-claim.
      void navigate({ to: "/app", search: {}, replace: true });
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "Couldn't issue your license.");
    },
  });

  // Returning from a successful Dodo checkout: mint the license exactly once.
  useEffect(() => {
    if (purchase === "success" && payment_id && !license && claimIsIdle) {
      claimLicense(payment_id);
    }
  }, [purchase, payment_id, license, claimIsIdle, claimLicense]);

  if (license) {
    return <LicenseCard license={license} />;
  }

  if (claimIsPending || (purchase === "success" && payment_id)) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-2xl border bg-card p-10 text-center">
        <LoaderCircleIcon className="size-6 animate-spin text-muted-foreground" />
        <p className="text-sm text-muted-foreground">Confirming your payment…</p>
      </div>
    );
  }

  return <PurchaseCard name={user?.name} />;
}

function LicenseCard({ license }: { license: LicenseDTO }) {
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(license.key);
      setCopied(true);
      toast.success("License key copied.");
      setTimeout(() => setCopied(false), 2000);
    } catch {
      toast.error("Couldn't copy — select the key and copy manually.");
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col items-center gap-2 text-center">
        <div className="flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
          <ShieldCheckIcon className="size-6" />
        </div>
        <h1 className="text-xl font-semibold">You own Battlify</h1>
        <p className="text-sm text-muted-foreground">
          Licensed to <span className="text-foreground">{license.email}</span> · perpetual
        </p>
      </div>

      <div className="flex flex-col gap-2 rounded-2xl border bg-card p-4">
        <div className="flex items-center justify-between">
          <span className="text-xs font-medium tracking-wide text-muted-foreground uppercase">
            License key
          </span>
          <Button size="xs" variant="outline" onClick={copy} type="button">
            {copied ? <CheckIcon /> : <CopyIcon />}
            {copied ? "Copied" : "Copy"}
          </Button>
        </div>
        <code className="block max-h-32 overflow-auto rounded-lg bg-muted p-3 font-mono text-xs break-all text-foreground">
          {license.key}
        </code>
      </div>

      <div className="flex flex-col gap-3 rounded-2xl border bg-card p-4">
        <h2 className="text-sm font-medium">Activate the desktop app</h2>
        <ol className="flex flex-col gap-2 text-sm text-muted-foreground">
          <li>
            <span className="mr-2 text-foreground">1.</span>Open Battlify → menu bar icon →{" "}
            <span className="text-foreground">Settings → License</span>.
          </li>
          <li>
            <span className="mr-2 text-foreground">2.</span>Paste the license key above.
          </li>
          <li>
            <span className="mr-2 text-foreground">3.</span>Click{" "}
            <span className="text-foreground">Activate</span> — it verifies offline, no internet
            needed.
          </li>
        </ol>
      </div>
    </div>
  );
}

function PurchaseCard({ name }: { name?: string }) {
  const { buy, loading } = useCheckout();

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col items-center gap-2 text-center">
        <div className="flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
          <SparklesIcon className="size-6" />
        </div>
        <h1 className="text-xl font-semibold">Unlock Battlify{name ? `, ${name}` : ""}</h1>
        <p className="max-w-sm text-sm text-muted-foreground">
          One payment, yours forever. After checkout your license key appears right here, ready to
          paste into the desktop app.
        </p>
      </div>

      <div className="flex flex-col items-center gap-4 rounded-2xl border bg-card p-6">
        <div className="flex items-baseline gap-1">
          <span className="text-3xl font-semibold">$2.99</span>
          <span className="text-sm text-muted-foreground">· one-time</span>
        </div>
        <Button size="lg" className="w-full" onClick={buy} disabled={loading} type="button">
          {loading ? <LoaderCircleIcon className="animate-spin" /> : null}
          {loading ? "Opening checkout…" : "Buy Battlify"}
        </Button>
        <p className="text-xs text-muted-foreground">Secure checkout via Dodo Payments.</p>
      </div>
    </div>
  );
}
