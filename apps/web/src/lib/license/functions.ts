import { createServerFn } from "@tanstack/react-start";
import * as z from "zod";

import { authMiddleware } from "#/lib/auth/middleware";
import { dodoClient } from "#/lib/payments/dodo";

import { formatDeviceCode } from "./device-code";
import {
  bindDeviceForUser,
  getLicenseForUser,
  issueLicenseForUser,
  nextRebindDate,
} from "./service";

export interface LicenseDTO {
  /** Signed token, or null while no Mac is linked yet. */
  key: string | null;
  email: string;
  name: string;
  issuedAt: string;
  /** Formatted device code ("7F3A-92C1-D04B") the key is locked to, or null. */
  deviceCode: string | null;
  /** When the license may move to a different Mac; null = movable now / not bound. */
  canRebindAt: string | null;
}

interface LicenseRow {
  key: string | null;
  email: string;
  name: string;
  issuedAt: Date;
  deviceCode: string | null;
  deviceBoundAt: Date | null;
}

function toDTO(row: LicenseRow): LicenseDTO {
  const next = nextRebindDate(row);
  return {
    key: row.key,
    email: row.email,
    name: row.name,
    issuedAt: row.issuedAt.toISOString(),
    deviceCode: row.deviceCode ? formatDeviceCode(row.deviceCode) : null,
    canRebindAt: next && next > new Date() ? next.toISOString() : null,
  };
}

/** Current user's license, or null if they haven't purchased. */
export const $getLicense = createServerFn({ method: "GET" })
  .middleware([authMiddleware])
  .handler(async ({ context }): Promise<LicenseDTO | null> => {
    const row = await getLicenseForUser(context.user.id);
    return row ? toDTO(row) : null;
  });

/**
 * Called when the buyer returns from Dodo checkout. Verifies the payment really
 * succeeded AND belongs to this signed-in user (so nobody can mint a license by
 * guessing a payment id), then records the purchase. Idempotent. The signed key
 * is minted afterwards by $bindDevice, once the buyer enters their device code.
 */
export const $claimLicense = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(z.object({ paymentId: z.string().min(1) }))
  .handler(async ({ data, context }): Promise<LicenseDTO> => {
    const user = context.user;

    // Already licensed → return it without re-checking the payment.
    const existing = await getLicenseForUser(user.id);
    if (existing) return toDTO(existing);

    const payment = await dodoClient.payments.retrieve(data.paymentId);
    if (payment.status !== "succeeded") {
      throw new Error("That payment hasn't completed yet. Try again in a moment.");
    }
    const paidEmail = payment.customer?.email?.toLowerCase();
    if (!paidEmail || paidEmail !== user.email.toLowerCase()) {
      throw new Error("This payment doesn't match your account.");
    }

    const row = await issueLicenseForUser({
      userId: user.id,
      email: user.email,
      name: user.name,
      dodoPaymentId: payment.payment_id,
      dodoCustomerId: payment.customer?.customer_id,
    });
    return toDTO(row);
  });

/**
 * Link the license to one Mac: signs a key with the device code embedded, so
 * the desktop app rejects it on any other machine. Same code → idempotent;
 * a different code re-mints the key, rate-limited by REBIND_COOLDOWN_DAYS.
 */
export const $bindDevice = createServerFn({ method: "POST" })
  .middleware([authMiddleware])
  .validator(z.object({ deviceCode: z.string().trim().min(1).max(64) }))
  .handler(async ({ data, context }): Promise<LicenseDTO> => {
    const row = await bindDeviceForUser(context.user.id, data.deviceCode);
    return toDTO(row);
  });
