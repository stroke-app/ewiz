// Reference license minting for ewiz.app's checkout. Node 18+, no dependencies.
//
// The website signs; the app verifies offline against the public key in
// Sources/EWizKit/License.swift. Use the same private key the app's public key was made
// from (LICENSE_SIGNING_PRIVATE_KEY), or no key it mints will verify.
//
//   LICENSE_SIGNING_PRIVATE_KEY=<base64> \
//     node scripts/license-mint.mjs --email a@b.com --device 7F3A-92C1-D04B [--name "A B"] [--days 365]
//
// Check a token with:  swift run licensetool verify --token <token> [--device <code>]

import { createPrivateKey, sign } from "node:crypto";
import { pathToFileURL } from "node:url";

// DER header that wraps a raw 32-byte Ed25519 seed as PKCS#8, which is what node:crypto
// takes. CryptoKit's `Curve25519.Signing.PrivateKey(rawRepresentation:)` is the same seed.
const PKCS8_ED25519_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");

/**
 * Mint a license token: base64url(payload JSON) "." base64url(Ed25519 signature).
 *
 * `product` stays "battlify" until installs from before the rename have updated: every
 * version accepts it, while only eWiz builds accept "ewiz".
 */
export function mintLicense({ privateKeyBase64, email, name = "", device, days, product = "battlify", now = new Date() }) {
  const d = String(device).toUpperCase().replace(/[^0-9A-F]/g, "");
  if (d.length !== 12) throw new Error("device must be a 12-hex-digit code like 7F3A-92C1-D04B");
  const seed = Buffer.from(privateKeyBase64, "base64");
  if (seed.length !== 32) throw new Error("the private key must be 32 bytes, base64-encoded");
  if (!email) throw new Error("email is required");

  const key = createPrivateKey({ key: Buffer.concat([PKCS8_ED25519_PREFIX, seed]), format: "der", type: "pkcs8" });
  const iat = Math.floor(now.getTime() / 1000);
  // Field names are the app's LicenseInfo coding keys. `n` must be present, even empty.
  const payload = { d, e: email, iat, n: name, p: product };
  if (days) payload.exp = iat + Math.round(days * 86400);

  const bytes = Buffer.from(JSON.stringify(payload), "utf8");
  const signature = sign(null, bytes, key);
  return `${bytes.toString("base64url")}.${signature.toString("base64url")}`;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const arg = (flag) => {
    const i = process.argv.indexOf(flag);
    return i > 0 ? process.argv[i + 1] : undefined;
  };
  const privateKeyBase64 = process.env.LICENSE_SIGNING_PRIVATE_KEY ?? arg("--priv");
  if (!privateKeyBase64 || !arg("--email") || !arg("--device")) {
    console.error("usage: LICENSE_SIGNING_PRIVATE_KEY=<b64> node scripts/license-mint.mjs --email <e> --device <code> [--name <n>] [--days <n>] [--product battlify|ewiz]");
    process.exit(64);
  }
  console.log(mintLicense({
    privateKeyBase64,
    email: arg("--email"),
    name: arg("--name") ?? "",
    device: arg("--device"),
    days: arg("--days") ? Number(arg("--days")) : undefined,
    product: arg("--product") ?? "battlify",
  }));
}
