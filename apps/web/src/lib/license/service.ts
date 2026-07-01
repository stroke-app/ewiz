import "@tanstack/react-start/server-only";
import { randomUUID } from "node:crypto";

import { eq } from "drizzle-orm";

import { env } from "#/env/server";
import { db } from "#/lib/db";
import { license } from "#/lib/db/schema";

import { signLicense } from "./sign";

export const LICENSE_PRODUCT = "battlify";

export interface IssueLicenseArgs {
  userId: string;
  email: string;
  name: string;
  dodoPaymentId?: string | null;
  dodoCustomerId?: string | null;
}

export async function getLicenseForUser(userId: string) {
  const [row] = await db.select().from(license).where(eq(license.userId, userId)).limit(1);
  return row ?? null;
}

/**
 * Idempotent: returns the user's existing license, or mints + persists a new
 * perpetual one. Safe to call from both the checkout-success flow and the Dodo
 * webhook — the unique `user_id` constraint keeps it to a single license.
 */
export async function issueLicenseForUser(args: IssueLicenseArgs) {
  const existing = await getLicenseForUser(args.userId);
  if (existing) return existing;

  const issuedAt = new Date();
  const key = signLicense(
    {
      email: args.email,
      name: args.name,
      issuedAt,
      expiresAt: null, // perpetual — "own it forever"
      product: LICENSE_PRODUCT,
    },
    env.LICENSE_SIGNING_PRIVATE_KEY,
  );

  const [row] = await db
    .insert(license)
    .values({
      id: randomUUID(),
      userId: args.userId,
      email: args.email,
      name: args.name,
      product: LICENSE_PRODUCT,
      key,
      issuedAt,
      dodoPaymentId: args.dodoPaymentId ?? null,
      dodoCustomerId: args.dodoCustomerId ?? null,
    })
    .onConflictDoNothing({ target: license.userId })
    .returning();

  // If a concurrent request won the insert race, read the row it wrote.
  return row ?? (await getLicenseForUser(args.userId))!;
}
