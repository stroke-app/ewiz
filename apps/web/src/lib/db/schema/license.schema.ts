import { relations } from "drizzle-orm";
import { index, pgTable, text, timestamp } from "drizzle-orm/pg-core";

import { user } from "./auth.schema";

/**
 * One perpetual Battlify license per user, minted after a successful Dodo payment.
 * `key` is the signed Ed25519 token the desktop app verifies offline
 * (see battpie: Sources/BattlifyKit/License.swift).
 */
export const license = pgTable(
  "license",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .unique()
      .references(() => user.id, { onDelete: "cascade" }),
    email: text("email").notNull(),
    name: text("name").notNull(),
    product: text("product").notNull().default("battlify"),
    // The signed license token: base64url(payload) "." base64url(signature).
    key: text("key").notNull(),
    dodoPaymentId: text("dodo_payment_id"),
    dodoCustomerId: text("dodo_customer_id"),
    issuedAt: timestamp("issued_at").defaultNow().notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [index("license_userId_idx").on(table.userId)],
);

export const licenseRelations = relations(license, ({ one }) => ({
  user: one(user, {
    fields: [license.userId],
    references: [user.id],
  }),
}));
