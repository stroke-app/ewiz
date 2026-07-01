import { createServerFn } from "@tanstack/react-start";
import * as z from "zod";

import { authMiddleware } from "#/lib/auth/middleware";
import { dodoClient } from "#/lib/payments/dodo";

import { getLicenseForUser, issueLicenseForUser } from "./service";

export interface LicenseDTO {
  key: string;
  email: string;
  name: string;
  issuedAt: string;
}

function toDTO(row: { key: string; email: string; name: string; issuedAt: Date }): LicenseDTO {
  return { key: row.key, email: row.email, name: row.name, issuedAt: row.issuedAt.toISOString() };
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
 * guessing a payment id), then issues the perpetual license. Idempotent.
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
