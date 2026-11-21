import "@tanstack/react-start/server-only";
import { importPKCS8, SignJWT } from "jose";

import { env } from "#/env/server";

export const appleConfigured = Boolean(
  env.APPLE_CLIENT_ID && env.APPLE_TEAM_ID && env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY,
);

/**
 * Apple wants the OAuth client secret as an ES256 JWT signed with the .p8 key,
 * valid for at most six months. https://better-auth.com/docs/authentication/apple
 *
 * The key may be stored with literal "\n"s (one-line secrets), so restore them.
 */
export async function appleClientSecret(): Promise<string> {
  const pem = env.APPLE_PRIVATE_KEY!.replace(/\\n/g, "\n").trim();
  const key = await importPKCS8(pem, "ES256");
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_KEY_ID! })
    .setIssuer(env.APPLE_TEAM_ID!)
    .setSubject(env.APPLE_CLIENT_ID!)
    .setAudience("https://appleid.apple.com")
    .setIssuedAt(now)
    .setExpirationTime(now + 180 * 24 * 60 * 60)
    .sign(key);
}
