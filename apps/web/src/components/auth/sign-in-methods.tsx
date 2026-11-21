import { SiGithub, SiGoogle } from "@icons-pack/react-simple-icons";
import { useMutation, useQuery } from "@tanstack/react-query";
import { CheckIcon, MailIcon } from "lucide-react";
import { toast } from "sonner";

import { Button } from "#/components/ui/button";
import { authClient } from "#/lib/auth/auth-client";
import { $getSocialProviders } from "#/lib/auth/functions";

const PROVIDERS = [
  { id: "github", label: "GitHub", icon: SiGithub },
  { id: "google", label: "Google", icon: SiGoogle },
] as const;

/**
 * Lists how this account can sign in and lets the user connect the other
 * provider, so GitHub and Google both open the same account and license.
 */
export function SignInMethods() {
  const { data: accounts } = useQuery({
    queryKey: ["auth", "accounts"],
    queryFn: async () => {
      const { data, error } = await authClient.listAccounts();
      if (error) throw new Error(error.message);
      return data;
    },
  });
  const { data: configured } = useQuery({
    queryKey: ["auth", "providers"],
    queryFn: () => $getSocialProviders(),
    staleTime: Infinity,
  });
  const linked = new Set(accounts?.map((a) => a.providerId));
  const providers = PROVIDERS.filter((p) => configured?.[p.id] || linked.has(p.id));

  const {
    mutate: connect,
    isPending,
    variables,
  } = useMutation({
    mutationFn: async (provider: (typeof PROVIDERS)[number]["id"]) => {
      const { error } = await authClient.linkSocial({ provider, callbackURL: "/app" });
      if (error) throw new Error(error.message);
    },
    onError: (error) => toast.error(error.message || "Couldn't connect that account."),
  });

  return (
    <section className="mt-6 rounded-lg border border-border bg-surface-1 p-4">
      <h2 className="text-sm font-medium">Sign-in methods</h2>
      <p className="mt-0.5 text-xs text-muted-foreground">
        Connect both so either one opens this account and your license.
      </p>
      <ul className="mt-3 divide-y divide-border">
        {providers.map((p) => (
          <li key={p.id} className="flex items-center justify-between py-2">
            <span className="flex items-center gap-2.5 text-sm">
              <p.icon className="size-4" aria-hidden />
              {p.label}
            </span>
            {linked.has(p.id) ? (
              <span className="flex items-center gap-1 text-xs text-success">
                <CheckIcon className="size-3.5" />
                Connected
              </span>
            ) : (
              <Button
                size="xs"
                variant="outline"
                type="button"
                disabled={!accounts || (isPending && variables === p.id)}
                onClick={() => connect(p.id)}
              >
                Connect
              </Button>
            )}
          </li>
        ))}
        <li className="flex items-center justify-between py-2">
          <span className="flex items-center gap-2.5 text-sm">
            <MailIcon className="size-4" aria-hidden />
            Email and password
          </span>
          <span className="text-xs text-muted-foreground">
            {linked.has("credential") ? "Set" : "Not set"}
          </span>
        </li>
      </ul>
    </section>
  );
}
