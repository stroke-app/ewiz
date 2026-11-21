import "@tanstack/react-start/server-only";
import DodoPayments from "dodopayments";

import { env } from "#/env/server";

/**
 * Shared Dodo Payments SDK client. Lives here (rather than in auth.ts) so both
 * the auth plugin and license issuance can use it without a circular import.
 */
export const dodoClient = new DodoPayments({
  bearerToken: env.DODO_PAYMENTS_API_KEY ?? "",
  environment: env.DODO_PAYMENTS_ENVIRONMENT,
});
