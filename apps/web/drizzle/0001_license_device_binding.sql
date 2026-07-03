PRAGMA foreign_keys=OFF;--> statement-breakpoint
CREATE TABLE `__new_license` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`email` text NOT NULL,
	`name` text NOT NULL,
	`product` text DEFAULT 'battlify' NOT NULL,
	`key` text,
	`device_code` text,
	`device_bound_at` integer,
	`rebind_count` integer DEFAULT 0 NOT NULL,
	`dodo_payment_id` text,
	`dodo_customer_id` text,
	`issued_at` integer DEFAULT (cast(unixepoch('subsecond') * 1000 as integer)) NOT NULL,
	`created_at` integer DEFAULT (cast(unixepoch('subsecond') * 1000 as integer)) NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
INSERT INTO `__new_license`("id", "user_id", "email", "name", "product", "key", "dodo_payment_id", "dodo_customer_id", "issued_at", "created_at") SELECT "id", "user_id", "email", "name", "product", "key", "dodo_payment_id", "dodo_customer_id", "issued_at", "created_at" FROM `license`;--> statement-breakpoint
DROP TABLE `license`;--> statement-breakpoint
ALTER TABLE `__new_license` RENAME TO `license`;--> statement-breakpoint
PRAGMA foreign_keys=ON;--> statement-breakpoint
CREATE UNIQUE INDEX `license_user_id_unique` ON `license` (`user_id`);--> statement-breakpoint
CREATE INDEX `license_userId_idx` ON `license` (`user_id`);