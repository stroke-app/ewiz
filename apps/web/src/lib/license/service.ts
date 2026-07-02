import "@tanstack/react-start/server-only";
import { randomUUID } from "node:crypto";

import { eq } from "drizzle-orm";

import { env } from "#/env/server";
import { db } from "#/lib/db";
import { license } from "#/lib/db/schema";

import { formatDeviceCode, isValidDeviceCode, normalizeDeviceCode } from "./device-code";
import { signLicense } from "./sign";

export const LICENSE_PRODUCT = "battlify";

/**
 * How long a license stays locked to a Mac before it can be moved to another.
 * Signed keys verify offline and can't be revoked, so each rebind mints a key
 * that works forever on that Mac — the cooldown is what keeps "rebind for every
 * friend" from being a sharing loophole.
 */
export const REBIND_COOLDOWN_DAYS = 30;

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

/** When the license may next move to a different Mac, or null if not bound. */
export function nextRebindDate(row: { deviceCode: string | null; deviceBoundAt: Date | null }) {
  if (!row.deviceCode || !row.deviceBoundAt) return null;
  return new Date(row.deviceBoundAt.getTime() + REBIND_COOLDOWN_DAYS * 86_400_000);
}

/**
 * Idempotent: returns the user's existing license row, or records the purchase.
 * Safe to call from both the checkout-success flow and the Dodo webhook — the
 * unique `user_id` constraint keeps it to a single license.
 *
 * No key is signed here: the buyer still has to link a Mac by entering the
 * device code the desktop app shows, and `bindDeviceForUser` mints the key.
 */
export async function issueLicenseForUser(args: IssueLicenseArgs) {
  const existing = await getLicenseForUser(args.userId);
  if (existing) return existing;

  const [row] = await db
    .insert(license)
    .values({
      id: randomUUID(),
      userId: args.userId,
      email: args.email,
      name: args.name,
      product: LICENSE_PRODUCT,
      key: null,
      issuedAt: new Date(),
      dodoPaymentId: args.dodoPaymentId ?? null,
      dodoCustomerId: args.dodoCustomerId ?? null,
    })
    .onConflictDoNothing({ target: license.userId })
    .returning();

  // If a concurrent request won the insert race, read the row it wrote.
  return row ?? (await getLicenseForUser(args.userId))!;
}

/**
 * Mint (or re-mint) the user's key bound to one Mac. Idempotent for the same
 * device code; moving to a different Mac is allowed once per
 * REBIND_COOLDOWN_DAYS. Error messages are user-facing.
 */
export async function bindDeviceForUser(userId: string, rawDeviceCode: string) {
  const row = await getLicenseForUser(userId);
  if (!row) {
    throw new Error("Buy Battlify first — then you can link your Mac here.");
  }

  if (!isValidDeviceCode(rawDeviceCode)) {
    throw new Error(
      "That doesn't look like a device code. It's 12 characters like 7F3A-92C1-D04B, shown in Battlify's license window on your Mac.",
    );
  }
  const deviceCode = normalizeDeviceCode(rawDeviceCode);

  // Same Mac, key already minted — nothing to do.
  if (row.key && row.deviceCode === deviceCode) return row;

  const isRebind = row.deviceCode !== null && row.deviceCode !== deviceCode;
  if (isRebind) {
    const next = nextRebindDate(row);
    if (next && next > new Date()) {
      const when = next.toLocaleDateString("en-US", {
        month: "long",
        day: "numeric",
        year: "numeric",
      });
      throw new Error(
        `This license moved to a Mac (${formatDeviceCode(row.deviceCode!)}) recently. You can move it to a different one on ${when}.`,
      );
    }
  }

  const now = new Date();
  const key = signLicense(
    {
      email: row.email,
      name: row.name,
      issuedAt: now,
      expiresAt: null, // perpetual — "own it forever"
      product: LICENSE_PRODUCT,
      deviceCode,
    },
    env.LICENSE_SIGNING_PRIVATE_KEY,
  );

  const [updated] = await db
    .update(license)
    .set({
      key,
      deviceCode,
      deviceBoundAt: now,
      rebindCount: isRebind ? row.rebindCount + 1 : row.rebindCount,
    })
    .where(eq(license.id, row.id))
    .returning();
  return updated!;
}
