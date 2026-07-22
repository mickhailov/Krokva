// Neighbourhood risk module — rooming-house enforcement, vacant-property fire
// trend, rush-hour towing, paid parking, and graffiti reports around the subject.
// Ports fetchNeighbourhoodRisk (+ fetchRoomingHouse, fetchVacantFireTrend,
// fetchTowingNearby, fetchPaidParkingNearby, fetchGraffitiCount) from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { Coordinate, escaped, parseCoordinate, rowInt, rowString } from "../row";
import {
  NeighbourhoodRiskSummary,
  PropertyAssessment,
  RoomingHouseActivity,
  YearCount,
} from "../types";
import { distanceMeters, properCaseNeighbourhood, yearOffset } from "../util";

// Matches WinnipegProvider.nearbyRadiusMeters (paid parking); towing is a hard 500.
const NEARBY_RADIUS_METERS = 500;

export async function fetchNeighbourhoodRisk(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<NeighbourhoodRiskSummary | undefined> {
  if (!property) return undefined;

  // The vacant-property fire trend is the determining fetch: it is always attempted
  // (citywide, no gating) so a transport error there marks the module failed. The
  // rest are enrichment and degrade to empty on error.
  const [fireTrend, roomingActivity, towingCount, parkingInfo, graffitiCount] = await Promise.all([
    fetchVacantFireTrend(init),
    fetchRoomingHouse(property.neighbourhood, init).catch(() => undefined),
    fetchTowingNearby(property.coordinate, init).catch(() => 0),
    fetchPaidParkingNearby(property.coordinate, init).catch(() => ({ count: 0, nearest: undefined })),
    fetchGraffitiCount(property.neighbourhood, init).catch(() => undefined),
  ]);

  if (
    roomingActivity == null &&
    fireTrend.length === 0 &&
    towingCount === 0 &&
    parkingInfo.count === 0 &&
    (graffitiCount ?? 0) === 0
  ) {
    return undefined;
  }

  return {
    roomingHouse: roomingActivity,
    vacantFireTrend: fireTrend,
    towingNearby: towingCount,
    paidParkingNearby: parkingInfo.count,
    nearestPaidParking: parkingInfo.nearest,
    graffitiReports: graffitiCount,
  };
}

async function fetchRoomingHouse(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<RoomingHouseActivity | undefined> {
  if (!neighbourhood) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.roomingHouseEnforcement,
    {
      where: `upper(neighbourhood)='${escaped(neighbourhood.toUpperCase())}'`,
      order: "year DESC",
      limit: 1,
    },
    init,
  );
  const row = rows[0];
  if (!row) return undefined;
  const year = rowInt(row, "year");
  if (year == null) return undefined;
  return {
    year,
    complaintDriven: rowInt(row, "complaint_driven"),
    proactive: rowInt(row, "proactive_enforcement"),
    inProgress: rowInt(row, "in_progress"),
    completed: rowInt(row, "completed"),
  };
}

async function fetchVacantFireTrend(init?: { signal?: AbortSignal }): Promise<YearCount[]> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.vacantPropertyFires,
    { select: "month,value", limit: 2000 },
    init,
  );
  const byYear = new Map<number, number>();
  for (const row of rows) {
    const value = rowInt(row, "value");
    if (value == null) continue;
    // "month" is a YYYY-MM(-DD…) string; its leading four digits are the year in
    // both the parsed-date and raw-prefix branches of the Swift original.
    const raw = rowString(row, "month");
    const m = raw ? /^(\d{4})/.exec(raw) : null;
    if (!m) continue;
    const year = parseInt(m[1], 10);
    byYear.set(year, (byYear.get(year) ?? 0) + value);
  }
  const currentYear = yearOffset(0);
  return [...byYear.keys()]
    .sort((a, b) => a - b)
    .filter((year) => year >= currentYear - 6)
    .map((year) => ({ year, count: byYear.get(year) ?? 0, citywideAverage: 0 }) satisfies YearCount);
}

async function fetchTowingNearby(
  coordinate: Coordinate | undefined,
  init?: { signal?: AbortSignal },
): Promise<number> {
  if (!coordinate) return 0;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.rushHourTowing,
    {
      select: "count(*) as cnt",
      where: soql.withinCircle("gps_pickup", coordinate.latitude, coordinate.longitude, 500),
    },
    init,
  );
  return rowInt(rows[0] ?? {}, "cnt") ?? 0;
}

async function fetchPaidParkingNearby(
  coordinate: Coordinate | undefined,
  init?: { signal?: AbortSignal },
): Promise<{ count: number; nearest?: string }> {
  if (!coordinate) return { count: 0, nearest: undefined };
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.paidParking,
    {
      select: "restriction,time_limit,street,center_point",
      where: soql.withinCircle(
        "center_point",
        coordinate.latitude,
        coordinate.longitude,
        NEARBY_RADIUS_METERS,
      ),
      limit: 60,
    },
    init,
  );
  if (rows.length === 0) return { count: 0, nearest: undefined };

  let nearest: { label: string; distance: number } | undefined;
  for (const row of rows) {
    const coord = parseCoordinate(row);
    if (!coord) continue;
    const distance = distanceMeters(coord, coordinate);
    const parts = [rowString(row, "street"), rowString(row, "time_limit")].filter(
      (p): p is string => p != null,
    );
    const label = parts.join(" · ");
    const resolved = label.length ? label : (rowString(row, "restriction") ?? "Paid parking");
    if (!nearest || distance < nearest.distance) nearest = { label: resolved, distance };
  }
  return { count: rows.length, nearest: nearest?.label };
}

async function fetchGraffitiCount(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<number | undefined> {
  if (!neighbourhood) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.serviceRequests,
    {
      select: "count(*) as cnt",
      where: `${serviceNeighbourhoodClause(neighbourhood)} AND type LIKE 'Graffiti%'`,
    },
    init,
  );
  const count = rowInt(rows[0] ?? {}, "cnt");
  return count != null && count > 0 ? count : undefined;
}

/** Index-friendly Title-Case neighbourhood match (WinnipegProvider.serviceNeighbourhoodClause). */
function serviceNeighbourhoodClause(neighbourhood: string): string {
  const trimmed = neighbourhood.trim();
  return `neighbourhood='${escaped(properCaseNeighbourhood(trimmed))}'`;
}
