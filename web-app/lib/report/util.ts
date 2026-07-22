// Shared provider helpers — ports of the small utilities WinnipegProvider reuses
// across modules (dates, distances, neighbourhood casing, street-core limiting).

import { Coordinate } from "./row";

/** Current year + offset (WinnipegProvider.yearOffset). */
export function yearOffset(offset: number): number {
  return new Date().getUTCFullYear() + offset;
}

/** Parse a Socrata timestamp to an ISO string, or undefined if unparseable. */
export function parseDate(value?: string): string | undefined {
  if (!value) return undefined;
  const t = Date.parse(value);
  return Number.isNaN(t) ? undefined : new Date(t).toISOString();
}

/** A permit is "adjacent" when its civic number is within 20 of the subject's. */
export function isAdjacent(permitAddress: string, civicNumber?: number): boolean {
  if (civicNumber == null) return false;
  const first = permitAddress.trim().split(/\s+/)[0];
  const n = /^\d+$/.test(first) ? parseInt(first, 10) : NaN;
  return Number.isFinite(n) ? Math.abs(n - civicNumber) <= 20 : false;
}

/** Great-circle distance in metres (matches CLLocation.distance closely enough). */
export function distanceMeters(a: Coordinate, b: Coordinate): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** WinnipegProvider.distanceDescription(meters:) */
export function distanceDescription(meters: number): string {
  if (meters < 1000) return `${Math.round(meters)} m`;
  return `${(meters / 1000).toFixed(1)} km`;
}

/**
 * Title-case a neighbourhood, preserving apostrophes ("ST. JOHN'S" → "St. John's").
 * The assessment feed uses UPPERCASE; most other feeds use Title Case, and matching
 * against the indexed Title-Case column avoids a full table scan.
 */
export function properCaseNeighbourhood(name: string): string {
  const lower = name.toLowerCase();
  let result = "";
  let capitalizeNext = true;
  for (const ch of lower) {
    if (ch === " " || ch === "-" || ch === "/") {
      capitalizeNext = true;
      result += ch;
    } else if (capitalizeNext) {
      result += ch.toUpperCase();
      capitalizeNext = false;
    } else {
      result += ch;
    }
  }
  return result;
}

/** Dedupe, drop empties, sort, cap — WinnipegProvider.limitedStreetCores. */
export function limitedStreetCores(cores: string[], limit = 18): string[] {
  return Array.from(new Set(cores.filter((c) => c.length > 0)))
    .sort()
    .slice(0, limit);
}

const HTML_ENTITIES: Record<string, string> = {
  "&nbsp;": " ",
  "&#160;": " ",
  "&amp;": "&",
  "&quot;": '"',
  "&#39;": "'",
  "&apos;": "'",
  "&lt;": "<",
  "&gt;": ">",
};

export function htmlDecoded(value: string): string {
  return value.replace(/&nbsp;|&#160;|&amp;|&quot;|&#39;|&apos;|&lt;|&gt;/g, (m) => HTML_ENTITIES[m] ?? m);
}

/** Strip HTML tags and collapse whitespace (WinnipegProvider.plainText). */
export function plainText(value?: string): string | undefined {
  if (!value) return undefined;
  const collapsed = value
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return collapsed.length ? collapsed : undefined;
}
