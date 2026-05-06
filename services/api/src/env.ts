import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.string().url(),
  HMAC_SERVER_SECRET: z.string().min(32),
  PORT: z.coerce.number().int().positive().default(3000),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
});

export const env = schema.parse(process.env);
export type Env = z.infer<typeof schema>;
