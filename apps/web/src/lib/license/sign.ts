import "@tanstack/react-start/server-only";
import crypto from "node:crypto";

/**
 * PKCS#8 DER prefix for an Ed25519 private key (RFC 8410). Node's crypto can't
 * import a bare 32-byte Ed25519 seed, so we prepend this fixed header to the seed
 * (what CryptoKit exposes as `rawRepresentation`) to build a full PKCS#8 key.
 */
const PKCS8_ED25519_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");

function base64url(buf: Buffer): string {
  return buf.toString("base64").replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export interface LicensePayload {
  email: string;
  name: string;
  issuedAt: Date;
  /** null / undefined = perpetual (the `exp` field is omitted, matching battpie). */
  expiresAt?: Date | null;
  product: string;
}

/**
 * Mint a Battlify license token:  base64url(payloadJSON) "." base64url(ed25519 sig).
 *
 * Byte-compatible with the offline verifier in battpie
 * (Sources/BattlifyKit/License.swift): payload keys are {e, n, iat, exp?, p},
 * dates are unix seconds, and `exp` is omitted for a perpetual license. The
 * signature is Ed25519 over the exact payload bytes, which is what the app
 * base64url-decodes and verifies before JSON-decoding.
 */
export function signLicense(payload: LicensePayload, privateKeyBase64: string): string {
  const seed = Buffer.from(privateKeyBase64, "base64");
  if (seed.length !== 32) {
    throw new Error("LICENSE_SIGNING_PRIVATE_KEY must be a base64-encoded 32-byte Ed25519 seed.");
  }
  const key = crypto.createPrivateKey({
    key: Buffer.concat([PKCS8_ED25519_PREFIX, seed]),
    format: "der",
    type: "pkcs8",
  });

  const body: Record<string, string | number> = {
    e: payload.email,
    n: payload.name,
    iat: Math.floor(payload.issuedAt.getTime() / 1000),
    p: payload.product,
  };
  if (payload.expiresAt) {
    body.exp = Math.floor(payload.expiresAt.getTime() / 1000);
  }

  const payloadBytes = Buffer.from(JSON.stringify(body), "utf8");
  const signature = crypto.sign(null, payloadBytes, key);
  return `${base64url(payloadBytes)}.${base64url(signature)}`;
}
