CREATE EXTENSION IF NOT EXISTS "citext";--> statement-breakpoint
CREATE TABLE "devices" (
	"id" uuid PRIMARY KEY NOT NULL,
	"nickname" "citext" NOT NULL,
	"secret" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "nonces" (
	"nonce" text PRIMARY KEY NOT NULL,
	"device_id" uuid NOT NULL,
	"expires_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "scores" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"device_id" uuid NOT NULL,
	"level" text NOT NULL,
	"score" integer NOT NULL,
	"time_ms" integer NOT NULL,
	"coins" integer DEFAULT 0 NOT NULL,
	"world_completed" boolean DEFAULT false NOT NULL,
	"submitted_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "nonces" ADD CONSTRAINT "nonces_device_id_devices_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "scores" ADD CONSTRAINT "scores_device_id_devices_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "devices_nickname_unique" ON "devices" USING btree ("nickname");--> statement-breakpoint
CREATE INDEX "scores_level_score_idx" ON "scores" USING btree ("level","score","time_ms");--> statement-breakpoint
CREATE INDEX "scores_global_idx" ON "scores" USING btree ("score","time_ms") WHERE "scores"."world_completed" = true;--> statement-breakpoint
CREATE INDEX "scores_device_idx" ON "scores" USING btree ("device_id","submitted_at");