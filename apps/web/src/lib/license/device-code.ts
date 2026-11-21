/**
 * Device codes identify one Mac: the desktop app derives a 12-hex-digit code
 * from the machine's hardware UUID (battpie: Sources/BattlifyKit/DeviceIdentity.swift)
 * and shows it as "7F3A-92C1-D04B". The license payload stores the normalized
 * form; the app compares codes dash- and case-insensitively.
 *
 * Isomorphic — imported by both the bind form (client) and signing (server).
 */

export const DEVICE_CODE_HEX_LENGTH = 12;

/** Canonical form: uppercase hex digits only, e.g. "7F3A92C1D04B". */
export function normalizeDeviceCode(input: string): string {
  return input.toUpperCase().replaceAll(/[^0-9A-F]/g, "");
}

export function isValidDeviceCode(input: string): boolean {
  return normalizeDeviceCode(input).length === DEVICE_CODE_HEX_LENGTH;
}

/** Display form: "7F3A-92C1-D04B". */
export function formatDeviceCode(input: string): string {
  return normalizeDeviceCode(input).replaceAll(/(.{4})(?=.)/g, "$1-");
}
