import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import {
  CheckIcon,
  CopyIcon,
  LaptopIcon,
  LoaderCircleIcon,
  ShieldCheckIcon,
  SparklesIcon,
} from "lucide-react";
import { useEffect, useState } from "react";
import { toast } from "sonner";

import { useCheckout } from "#/components/buy-button";
import { Button } from "#/components/ui/button";
import { Input } from "#/components/ui/input";
import { useAuthSuspense } from "#/lib/auth/hooks";
import { formatDeviceCode, isValidDeviceCode } from "#/lib/license/device-code";
import { $bindDevice, $claimLicense, type LicenseDTO } from "#/lib/license/functions";
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
      toast.success("Payment confirmed — now link your Mac to get your key.");
      // Clean the checkout params out of the URL so a refresh doesn't re-claim.
      void navigate({ to: "/app", search: {}, replace: true });
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "Couldn't issue your license.");
    },
  });

  // Returning from a successful Dodo checkout: record the purchase exactly once.
  useEffect(() => {
    if (purchase === "success" && payment_id && !license && claimIsIdle) {
      claimLicense(payment_id);
    }
  }, [purchase, payment_id, license, claimIsIdle, claimLicense]);

  if (license?.key) {
    return <LicenseCard license={license} />;
  }

  if (license) {
    return <LinkMacCard />;
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

/**
 * Device-code form shared by first-time linking and moving to a new Mac.
 * Formats input as the app displays it (7F3A-92C1-D04B) while typing.
 */
function DeviceCodeForm({
  submitLabel,
  onSuccess,
}: {
  submitLabel: string;
  onSuccess?: () => void;
}) {
  const queryClient = useQueryClient();
  const [code, setCode] = useState("");

  const { mutate: bindDevice, isPending } = useMutation({
    mutationFn: (deviceCode: string) => $bindDevice({ data: { deviceCode } }),
    onSuccess: (data) => {
      queryClient.setQueryData(licenseQueryOptions().queryKey, data);
      toast.success(`License key ready — locked to ${data.deviceCode}.`);
      setCode("");
      onSuccess?.();
    },
    onError: (error) => {
      toast.error(error instanceof Error ? error.message : "Couldn't link that Mac.");
    },
  });

  return (
    <form
      className="flex items-center gap-2"
      onSubmit={(event) => {
        event.preventDefault();
        if (isValidDeviceCode(code)) bindDevice(code);
      }}
    >
      <Input
        value={code}
        onChange={(event) => setCode(formatDeviceCode(event.target.value))}
        placeholder="7F3A-92C1-D04B"
        className="font-mono tracking-wide uppercase"
        maxLength={14}
        autoComplete="off"
        spellCheck={false}
        disabled={isPending}
        aria-label="Device code"
      />
      <Button type="submit" disabled={isPending || !isValidDeviceCode(code)}>
        {isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
        {submitLabel}
      </Button>
    </form>
  );
}

/** Purchased, but no Mac linked yet — the key is minted against this code. */
function LinkMacCard() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col items-center gap-2 text-center">
        <div className="flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
          <LaptopIcon className="size-6" />
        </div>
        <h1 className="text-xl font-semibold">One step left — link your Mac</h1>
        <p className="max-w-sm text-sm text-muted-foreground">
          Your license is locked to a single Mac. Enter the device code from the app and your key
          appears here.
        </p>
      </div>

      <div className="flex flex-col gap-3 rounded-2xl border bg-card p-4">
        <h2 className="text-sm font-medium">Find your device code</h2>
        <ol className="flex flex-col gap-2 text-sm text-muted-foreground">
          <li>
            <span className="mr-2 text-foreground">1.</span>On your Mac, open Battlify → menu bar
            icon → <span className="text-foreground">Settings → License</span>.
          </li>
          <li>
            <span className="mr-2 text-foreground">2.</span>Copy the{" "}
            <span className="text-foreground">device code</span> shown there (like{" "}
            <code className="rounded bg-muted px-1 font-mono text-xs">7F3A-92C1-D04B</code>) and
            paste it below.
          </li>
        </ol>
        <DeviceCodeForm submitLabel="Get my key" />
      </div>
    </div>
  );
}

function LicenseCard({ license }: { license: LicenseDTO }) {
  const [copied, setCopied] = useState(false);
  const [moving, setMoving] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(license.key!);
      setCopied(true);
      toast.success("License key copied.");
      setTimeout(() => setCopied(false), 2000);
    } catch {
      toast.error("Couldn't copy — select the key and copy manually.");
    }
  };

  const rebindLockedUntil = license.canRebindAt
    ? new Date(license.canRebindAt).toLocaleDateString("en-US", {
        month: "long",
        day: "numeric",
        year: "numeric",
      })
    : null;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col items-center gap-2 text-center">
        <div className="flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
          <ShieldCheckIcon className="size-6" />
        </div>
        <h1 className="text-xl font-semibold">You own Battlify</h1>
        <p className="text-sm text-muted-foreground">
          Licensed to <span className="text-foreground">{license.email}</span> · perpetual
          {license.deviceCode ? (
            <>
              {" "}
              · locked to Mac{" "}
              <span className="font-mono text-foreground">{license.deviceCode}</span>
            </>
          ) : null}
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

      <div className="flex flex-col gap-3 rounded-2xl border bg-card p-4">
        {license.deviceCode ? (
          <>
            <div className="flex items-center justify-between">
              <div className="flex flex-col">
                <h2 className="text-sm font-medium">Moving to a new Mac?</h2>
                <p className="text-xs text-muted-foreground">
                  {rebindLockedUntil
                    ? `This license moved recently — you can move it again on ${rebindLockedUntil}.`
                    : "Re-mint your key with the new Mac's device code. Allowed once every 30 days."}
                </p>
              </div>
              {!rebindLockedUntil && !moving ? (
                <Button size="xs" variant="outline" type="button" onClick={() => setMoving(true)}>
                  <LaptopIcon />
                  Move license
                </Button>
              ) : null}
            </div>
            {!rebindLockedUntil && moving ? (
              <DeviceCodeForm submitLabel="Move" onSuccess={() => setMoving(false)} />
            ) : null}
          </>
        ) : (
          <>
            <h2 className="text-sm font-medium">Get an updated key for your Mac</h2>
            <p className="text-xs text-muted-foreground">
              Your key predates device locking and won't activate current versions of Battlify.
              Enter the device code from Battlify's license window to replace it with a key locked
              to your Mac.
            </p>
            <DeviceCodeForm submitLabel="Update my key" />
          </>
        )}
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
          One payment, yours forever. After checkout you'll link your Mac with the device code from
          the app, and your license key appears right here.
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
