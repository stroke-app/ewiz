import { relations, sql } from "drizzle-orm";
import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

import { user } from "./auth.schema";

/**
 * One perpetual Battlify license per user, minted after a successful Dodo payment.
 * `key` is the signed Ed25519 token the desktop app verifies offline
 * (see battpie: Sources/BattlifyKit/License.swift).
 */
export const license = sqliteTable(
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
    issuedAt: integer("issued_at", { mode: "timestamp_ms" })
      .default(sql`(cast(unixepoch('subsecond') * 1000 as integer))`)
      .notNull(),
    createdAt: integer("created_at", { mode: "timestamp_ms" })
      .default(sql`(cast(unixepoch('subsecond') * 1000 as integer))`)
      .notNull(),
  },
  (table) => [index("license_userId_idx").on(table.userId)],
);

export const licenseRelations = relations(license, ({ one }) => ({
  user: one(user, {
    fields: [license.userId],
    references: [user.id],
  }),
}));
