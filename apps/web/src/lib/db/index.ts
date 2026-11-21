import "@tanstack/react-start/server-only";
import { env as workerEnv } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/d1";

import * as schema from "#/lib/db/schema";

export const db = drizzle(workerEnv.DB, {
  schema,
  casing: "snake_case",
});
