import "@tanstack/react-start/server-only";
import { drizzleAdapter } from "@better-auth/drizzle-adapter";
import { checkout, dodopayments, portal, webhooks } from "@dodopayments/better-auth";
import { betterAuth } from "better-auth/minimal";
import { tanstackStartCookies } from "better-auth/tanstack-start";
import { eq } from "drizzle-orm";

import { env } from "#/env/server";
import { db } from "#/lib/db";
import * as schema from "#/lib/db/schema";
import { issueLicenseForUser } from "#/lib/license/service";
// https://better-auth.com/docs/plugins/dodopayments
// Dodo Payments is Battlify's Merchant of Record — it runs the hosted checkout,
// tax handling, and license webhooks. Paste real values into your `.env` to go live;
// with placeholders the plugin still mounts but checkout calls will error until keys exist.
import { dodoClient } from "#/lib/payments/dodo";

// Slug used by the client checkout call. See `auth-client.ts` -> `startCheckout`.
export const BATTLIFY_PRODUCT_SLUG = "battlify";

export const auth = betterAuth({
  baseURL: env.VITE_BASE_URL,
  telemetry: {
    enabled: false,
  },
  database: drizzleAdapter(db, {
    provider: "pg",
    schema,
  }),

  // https://better-auth.com/docs/integrations/tanstack#usage-tips
  plugins: [
    tanstackStartCookies(),

    // https://better-auth.com/docs/plugins/dodopayments
    dodopayments({
      client: dodoClient,
      // Create a Dodo customer the first time someone signs up, so checkout
      // and the customer portal can attach to an existing record.
      // Only when a real API key is present — otherwise the Dodo API returns
      // 401 and turns an otherwise-successful signup into a 500.
      createCustomerOnSignUp: Boolean(env.DODO_PAYMENTS_API_KEY),
      use: [
        checkout({
          products: [
            {
              // TODO: replace with your real Dodo product id (Dashboard -> Products).
              productId: env.DODO_BATTLIFY_PRODUCT_ID ?? "pdt_REPLACE_ME_BATTLIFY_LICENSE",
              slug: BATTLIFY_PRODUCT_SLUG,
            },
          ],
          // Where Dodo returns the buyer after a successful payment.
          successUrl: "/app?purchase=success",
          authenticatedUsersOnly: true,
        }),
        // Lets a customer manage/refund their purchase from inside the app.
        portal(),
        webhooks({
          webhookKey: env.DODO_PAYMENTS_WEBHOOK_SECRET ?? "",
          onPayload: async (payload) => {
            console.log("[dodo] webhook received:", payload.type);
          },
          // Production entitlement path: when a payment succeeds, mint the
          // buyer's perpetual license. Matched to the user by the paid email.
          // (The checkout-success page also claims it, so this is a backstop
          // for buyers who close the tab before the redirect completes.)
          onPaymentSucceeded: async (payload) => {
            const data = payload.data as {
              payment_id?: string;
              customer?: { email?: string; name?: string; customer_id?: string };
            };
            const email = data.customer?.email?.toLowerCase();
            if (!email) return;

            const owner = await db.query.user.findFirst({
              where: eq(schema.user.email, email),
            });
            if (!owner) {
              console.warn("[dodo] payment.succeeded for unknown user:", email);
              return;
            }

            await issueLicenseForUser({
              userId: owner.id,
              email: owner.email,
              name: owner.name,
              dodoPaymentId: data.payment_id,
              dodoCustomerId: data.customer?.customer_id,
            });
            console.log("[dodo] license issued for", owner.email);
          },
        }),
      ],
    }),
  ],

  // https://better-auth.com/docs/concepts/session-management#session-caching
  session: {
    cookieCache: {
      enabled: true,
      maxAge: 5 * 60, // 5 minutes
    },
  },

  // https://better-auth.com/docs/concepts/oauth
  socialProviders: {
    github: {
      clientId: env.GITHUB_CLIENT_ID!,
      clientSecret: env.GITHUB_CLIENT_SECRET!,
    },
    google: {
      clientId: env.GOOGLE_CLIENT_ID!,
      clientSecret: env.GOOGLE_CLIENT_SECRET!,
    },
  },

  // https://better-auth.com/docs/authentication/email-password
  emailAndPassword: {
    enabled: true,
  },

  experimental: {
    // https://better-auth.com/docs/adapters/drizzle#joins-experimental
    joins: true,
  },
});
