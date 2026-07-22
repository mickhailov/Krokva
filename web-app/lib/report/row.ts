// Row accessors + coordinate parsing — ports of the `Dictionary` string/int/double
// helpers and `parseCoordinate`/`parseWKTPoint` in WinnipegProvider. Socrata
// returns everything as strings or nested geo objects, so every read is defensive.

import { SocrataRow } from "../socrata";

export interface Coordinate {
  latitude: number;
  longitude: number;
}

export function rowString(row: SocrataRow, key: string): string | undefined {
  const v = row[key];
  if (v == null) return undefined;
  if (typeof v === "string") return v.length ? v : undefined;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  return undefined;
}

export function rowDouble(row: SocrataRow, key: string): number | undefined {
  const v = row[key];
  if (v == null) return undefined;
  if (typeof v === "number") return Number.isFinite(v) ? v : undefined;
  if (typeof v === "string") {
    const n = parseFloat(v.replace(/[$,]/g, ""));
    return Number.isFinite(n) ? n : undefined;
  }
  return undefined;
}

export function rowInt(row: SocrataRow, key: string): number | undefined {
  const d = rowDouble(row, key);
  return d == null ? undefined : Math.trunc(d);
}

/** Escape a single-quoted SoQL string literal (WinnipegProvider.escaped). */
export function escaped(value: string): string {
  return value.replace(/'/g, "''");
}

function parseWKTPoint(value: string): Coordinate | undefined {
  const m = /POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)/i.exec(value);
  if (!m) return undefined;
  const lon = parseFloat(m[1]);
  const lat = parseFloat(m[2]);
  if (!Number.isFinite(lon) || !Number.isFinite(lat)) return undefined;
  return { latitude: lat, longitude: lon };
}

/** parseCoordinate — mirrors the key precedence in WinnipegProvider. */
export function parseCoordinate(row: SocrataRow): Coordinate | undefined {
  const geoKeys = ["geometry", "the_geom", "location", "point", "location_point", "location_1", "location_1_geom"];
  for (const key of geoKeys) {
    const point = row[key];
    if (point && typeof point === "object" && !Array.isArray(point)) {
      const coords = (point as any).coordinates;
      if (Array.isArray(coords) && coords.length >= 2 && typeof coords[0] === "number") {
        return { latitude: coords[1], longitude: coords[0] };
      }
      if (Array.isArray(coords) && Array.isArray(coords[0]) && coords[0].length >= 2) {
        return { latitude: coords[0][1], longitude: coords[0][0] };
      }
      const latS = (point as any).latitude;
      const lonS = (point as any).longitude;
      if (latS != null && lonS != null) {
        const lat = typeof latS === "number" ? latS : parseFloat(latS);
        const lon = typeof lonS === "number" ? lonS : parseFloat(lonS);
        if (Number.isFinite(lat) && Number.isFinite(lon)) return { latitude: lat, longitude: lon };
      }
    }
  }
  const lat = rowDouble(row, "latitude");
  const lon = rowDouble(row, "longitude");
  if (lat != null && lon != null) return { latitude: lat, longitude: lon };
  const clat = rowDouble(row, "centroid_lat");
  const clon = rowDouble(row, "centroid_lon");
  if (clat != null && clon != null) return { latitude: clat, longitude: clon };
  const loc = rowString(row, "location");
  if (loc) {
    const wkt = parseWKTPoint(loc);
    if (wkt) return wkt;
  }
  return undefined;
}
