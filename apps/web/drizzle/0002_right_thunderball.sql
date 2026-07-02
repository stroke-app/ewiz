ALTER TABLE "license" ALTER COLUMN "key" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "license" ADD COLUMN "device_code" text;--> statement-breakpoint
ALTER TABLE "license" ADD COLUMN "device_bound_at" timestamp;--> statement-breakpoint
ALTER TABLE "license" ADD COLUMN "rebind_count" integer DEFAULT 0 NOT NULL;