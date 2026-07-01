import { createEnv } from "@t3-oss/env-core";
import * as z from "zod";

export const env = createEnv({
  server: {
    DATABASE_URL: z.url(),
    VITE_BASE_URL: z.url().default("http://localhost:3000"),
    BETTER_AUTH_SECRET: z.string().min(1),

    // OAuth2 providers, optional, update as needed
    GITHUB_CLIENT_ID: z.string().optional(),
    GITHUB_CLIENT_SECRET: z.string().optional(),
    GOOGLE_CLIENT_ID: z.string().optional(),
    GOOGLE_CLIENT_SECRET: z.string().optional(),

    // Dodo Payments — https://better-auth.com/docs/plugins/dodopayments
    // Optional so the app still boots before you paste real values in.
    DODO_PAYMENTS_API_KEY: z.string().optional(),
    DODO_PAYMENTS_WEBHOOK_SECRET: z.string().optional(),
    DODO_PAYMENTS_ENVIRONMENT: z.enum(["test_mode", "live_mode"]).default("test_mode"),
    // The Dodo product id that backs the "Own it forever" license.
    DODO_BATTLIFY_PRODUCT_ID: z.string().optional(),

    // Ed25519 private key (base64, 32-byte seed) used to sign Battlify license
    // tokens after checkout. The Battlify app embeds only the matching public key.
    LICENSE_SIGNING_PRIVATE_KEY: z.string().min(1),
  },
  runtimeEnv: process.env,
});
