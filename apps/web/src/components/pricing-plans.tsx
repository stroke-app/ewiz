import { ArrowUpRightIcon, CheckIcon } from "lucide-react";

import { useCheckout } from "#/components/buy-button";
import { DownloadButton } from "#/components/download-button";
import { PRICE } from "#/components/landing/landing-data";
import { Button } from "#/components/ui/button";

function Included({ items }: { items: string[] }) {
  return (
    <div className="mt-4 px-1">
      <p className="text-[15px] font-medium">What&apos;s included</p>
      <ul className="mt-1.5 space-y-1">
        {items.map((f) => (
          <li key={f} className="flex items-center gap-2.5 text-[15px]">
            <CheckIcon className="size-3.5 text-success" />
            {f}
          </li>
        ))}
      </ul>
    </div>
  );
}

/** The free trial and the license, side by side. Shown on the home page and /pricing. */
export function PricingPlans() {
  const { buy, loading } = useCheckout();
  return (
    <>
      <div className="mx-auto grid max-w-3xl gap-6 sm:grid-cols-2">
        <div className="flex flex-col rounded-lg border border-border bg-surface-1 p-4">
          <h3 className="text-xl font-medium">Free trial</h3>
          <p className="mt-3 flex items-baseline gap-1">
            <span className="text-sm text-muted-foreground">$</span>
            <span className="text-2xl font-medium tabular-nums">0</span>
            <span className="ml-1 text-muted-foreground">for 30 days</span>
          </p>
          <Included items={["Every feature unlocked", "No account needed", "No card required"]} />
          <DownloadButton variant="outline" className="mt-8 w-full sm:mt-auto" />
        </div>

        <div className="flex flex-col rounded-lg border border-border bg-surface-1 p-4">
          <h3 className="text-xl font-medium">License - Single Mac</h3>
          <p className="mt-3 flex items-baseline gap-1">
            <span className="text-sm text-muted-foreground">$</span>
            <span className="text-2xl font-medium tabular-nums">{PRICE.slice(1)}</span>
            <span className="ml-1 text-muted-foreground">one-time</span>
          </p>
          <p className="mt-1 leading-relaxed text-pretty text-muted-foreground">
            Pay once and keep it forever. A replacement MacBook battery runs about $199.
          </p>
          <Included items={["Free updates for life", "No subscription", "Move it to a new Mac"]} />
          <Button
            type="button"
            onClick={buy}
            disabled={loading}
            className="mt-8 w-full text-[15px]"
          >
            Purchase
            <ArrowUpRightIcon />
          </Button>
        </div>
      </div>
      <p className="mt-4 text-center text-sm text-muted-foreground">
        Secure checkout via Dodo Payments. Taxes are handled at checkout.
      </p>
    </>
  );
}
