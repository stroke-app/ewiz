CREATE TABLE "license" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"email" text NOT NULL,
	"name" text NOT NULL,
	"product" text DEFAULT 'battlify' NOT NULL,
	"key" text NOT NULL,
	"dodo_payment_id" text,
	"dodo_customer_id" text,
	"issued_at" timestamp DEFAULT now() NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "license_user_id_unique" UNIQUE("user_id")
);
--> statement-breakpoint
ALTER TABLE "license" ADD CONSTRAINT "license_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "license_userId_idx" ON "license" USING btree ("user_id");