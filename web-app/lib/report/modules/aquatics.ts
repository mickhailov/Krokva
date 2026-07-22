// Aquatics & amenities module — nearest indoor/outdoor/wading/spray-pad pool,
// nearby walkway count, and nearest public Wi-Fi site. Port of fetchAquatics,
// fetchNearestPool, fetchWalkwayCount, fetchNearestWifi from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, SocrataRow, soql } from "../../socrata";
import { Coordinate, parseCoordinate, rowInt, rowString } from "../row";
import {
  AquaticsAmenitiesSummary,
  NamedAmenity,
  PoolAmenity,
  PropertyAssessment,
} from "../types";
import { distanceDescription, distanceMeters } from "../util";

const NEARBY_RADIUS_METERS = 500;

/** row.bool — Socrata booleans arrive as bool/string/int (OpenDataClient.bool). */
function rowBool(row: SocrataRow, key: string): boolean {
  const v = row[key];
  if (typeof v === "boolean") return v;
  if (typeof v === "string") return ["true", "yes", "1"].includes(v.toLowerCase());
  if (typeof v === "number") return v !== 0;
  return false;
}

async function fetchNearestPool(
  datasetID: string,
  kind: string,
  subject: Coordinate,
  featureKeys: [label: string, key: string][],
  init?: { signal?: AbortSignal },
): Promise<{ pool: PoolAmenity; distance: number } | undefined> {
  const rows = await fetchDataset(
    datasetID,
    {
      where: soql.withinCircle("point", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
      limit: 60,
    },
    init,
  );
  let nearest: { pool: PoolAmenity; distance: number } | undefined;
  for (const row of rows) {
    const name = rowString(row, "name");
    const coordinate = parseCoordinate(row);
    if (!name || !coordinate) continue;
    const distance = distanceMeters(coordinate, subject);
    const features = featureKeys.filter(([, key]) => rowBool(row, key)).map(([label]) => label);
    const pool: PoolAmenity = {
      name,
      kind,
      address: rowString(row, "address"),
      isOpen: rowBool(row, "is_open"),
      distanceDescription: distanceDescription(distance),
      features,
      website: rowString(row, "website"),
      coordinate,
    };
    if (!nearest || distance < nearest.distance) nearest = { pool, distance };
  }
  return nearest;
}

async function fetchWalkwayCount(
  subject: Coordinate,
  init?: { signal?: AbortSignal },
): Promise<number> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.walkways,
    {
      select: "count(*) as cnt",
      where: soql.withinCircle("location", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
    },
    init,
  ).catch(() => []);
  return rows.length ? rowInt(rows[0], "cnt") ?? 0 : 0;
}

async function fetchNearestWifi(
  subject: Coordinate,
  init?: { signal?: AbortSignal },
): Promise<NamedAmenity | undefined> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.publicWifi,
    {
      select: "site_name_english,location",
      where: soql.withinCircle("location", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
      limit: 40,
    },
    init,
  ).catch(() => []);
  let nearest: { amenity: NamedAmenity; distance: number } | undefined;
  for (const row of rows) {
    const name = rowString(row, "site_name_english");
    const coordinate = parseCoordinate(row);
    if (!name || !coordinate) continue;
    const distance = distanceMeters(coordinate, subject);
    const amenity: NamedAmenity = {
      name,
      distanceDescription: distanceDescription(distance),
      coordinate,
    };
    if (!nearest || distance < nearest.distance) nearest = { amenity, distance };
  }
  return nearest?.amenity;
}

export async function fetchAquatics(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<AquaticsAmenitiesSummary | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  // Indoor pool is the primary/determining fetch — if the data source is down
  // it throws so the orchestrator marks the module failed. The remaining pool
  // kinds and the walkway/wifi enrichments degrade with .catch.
  const [indoor, outdoor, wading, spray, walkwayCount, nearestWifi] = await Promise.all([
    fetchNearestPool(WINNIPEG_DATASETS.poolsIndoor, "Indoor", subject, [
      ["Lap swim", "lap_swim"],
      ["Sauna", "sauna"],
      ["Whirlpool", "whirlpool"],
      ["Slide", "pool_slide"],
      ["Diving board", "diving_board"],
    ], init),
    fetchNearestPool(WINNIPEG_DATASETS.poolsOutdoor, "Outdoor", subject, [
      ["Lap swim", "lap_swim"],
      ["Slide", "pool_slide"],
      ["Diving board", "diving_board"],
      ["Spray features", "spray_features"],
    ], init).catch(() => undefined),
    fetchNearestPool(WINNIPEG_DATASETS.poolsWading, "Wading", subject, [
      ["Sprayer", "sprayer"],
      ["Playground", "playground"],
      ["Slide", "pool_slide"],
    ], init).catch(() => undefined),
    fetchNearestPool(WINNIPEG_DATASETS.poolsSprayPad, "Spray pad", subject, [
      ["Playground", "playground"],
      ["Waterslide", "waterslide"],
    ], init).catch(() => undefined),
    fetchWalkwayCount(subject, init),
    fetchNearestWifi(subject, init),
  ]);

  const pools = [indoor, outdoor, wading, spray]
    .filter((p): p is { pool: PoolAmenity; distance: number } => p != null)
    .sort((a, b) => a.distance - b.distance)
    .map((p) => p.pool);

  if (pools.length === 0 && walkwayCount === 0 && nearestWifi == null) return undefined;
  return { pools, walkwaysNearby: walkwayCount, nearestWifi };
}
