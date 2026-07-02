import { relations } from "drizzle-orm";
import { index, integer, pgTable, text, timestamp } from "drizzle-orm/pg-core";

import { user } from "./auth.schema";

/**
 * One perpetual Battlify license per user, created after a successful Dodo
 * payment. The signed key is only minted once the buyer links a Mac: `key` is
 * null until they enter their device code, and the token embeds that code so
 * the desktop app rejects it on any other machine
 * (see battpie: Sources/BattlifyKit/License.swift + DeviceIdentity.swift).
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
    // null = purchased but no Mac linked yet. Legacy rows (pre device locking)
    // hold a key with no deviceCode — those keys work on any Mac.
    key: text("key"),
    // Normalized 12-hex device code the key is bound to (e.g. "7F3A92C1D04B").
    deviceCode: text("device_code"),
    deviceBoundAt: timestamp("device_bound_at"),
    // Times the license moved to a different Mac (rebinds are rate-limited).
    rebindCount: integer("rebind_count").notNull().default(0),
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
