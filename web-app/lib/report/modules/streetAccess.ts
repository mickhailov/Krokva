// Street access module — pavement condition, school speed limit, nearby cycling
// routes, active accessibility disruptions, and active lane closures. Ports
// fetchStreetAccess and its helpers (fetchPavementCondition, fetchSchoolSpeedLimit,
// fetchCyclingRoutes, fetchAccessibilityDisruptions, fetchLaneClosures) from
// WinnipegProvider.

import { NormalizedAddress, streetCore } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { escaped, parseCoordinate, rowInt, rowString } from "../row";
import { PropertyAssessment, SchoolSpeedLimit, StreetAccessSummary, StreetDisruption } from "../types";
import { distanceDescription, distanceMeters, parseDate, plainText } from "../util";

const NEARBY_RADIUS_METERS = 500;

/**
 * WinnipegProvider.repairedFrenchCivicName — reconstructs French letters mangled
 * into the Unicode replacement character (U+FFFD) in Winnipeg school names.
 */
function repairedFrenchCivicName(value: string): string {
  if (!value.includes("�")) return value;
  let result = value;
  // A word-initial replacement is, for Winnipeg schools, always "École".
  if (result.startsWith("�cole")) {
    result = "É" + result.slice(1);
  }
  // "Rivière"/"Frontière" etc. — the destroyed letter before "re" is "è".
  result = result.replace(/�re/g, "ère");
  // Any remaining replacement character is a lowercase "é" in these names.
  result = result.replace(/�/g, "é");
  return result;
}

/** Pavement general condition / surface type for the address's street. */
async function fetchPavementCondition(
  address: NormalizedAddress,
  init?: { signal?: AbortSignal },
): Promise<{ condition?: string; surface?: string; roadType?: string }> {
  const token = escaped(streetCore(address.streetName));
  if (!token) return {};
  // Primary determining fetch — let it throw so the module is marked failed.
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.pavementCondition,
    {
      select: "general_condition,surface_type",
      where: `upper(street_name) like '${token}%'`,
      limit: 1,
    },
    init,
  );
  const first = rows[0];
  return {
    condition: first ? rowString(first, "general_condition") : undefined,
    surface: first ? rowString(first, "surface_type") : undefined,
    roadType: undefined,
  };
}

/** School speed-limit zone for the address's street. */
async function fetchSchoolSpeedLimit(
  address: NormalizedAddress,
  init?: { signal?: AbortSignal },
): Promise<SchoolSpeedLimit | undefined> {
  const token = escaped(streetCore(address.streetName));
  if (!token) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.schoolSpeedLimits,
    {
      select: "school,speed_limit,effective_days,effective_time",
      where: `upper(street_name) like '${token}%'`,
      limit: 1,
    },
    init,
  ).catch(() => []);
  const row = rows[0];
  if (!row) return undefined;
  const rawSchool = rowString(row, "school");
  if (!rawSchool) return undefined;
  const school = repairedFrenchCivicName(rawSchool);
  const speed = rowString(row, "speed_limit") ?? rowInt(row, "speed_limit")?.toString() ?? "30";
  return {
    school,
    speedLimit: `${speed} km/h`,
    effectiveDays: rowString(row, "effective_days"),
    effectiveTime: rowString(row, "effective_time"),
  };
}

/** Count of cycling-network segments within the nearby radius. */
async function fetchCyclingRoutes(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<number> {
  const subject = property?.coordinate;
  if (!subject) return 0;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.cyclingNetwork,
    {
      select: "count(*) as cnt",
      where: soql.withinCircle("location", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
    },
    init,
  ).catch(() => []);
  return (rows[0] ? rowInt(rows[0], "cnt") : undefined) ?? 0;
}

/** Active accessibility disruptions within the nearby radius, nearest first. */
async function fetchAccessibilityDisruptions(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<StreetDisruption[]> {
  const subject = property?.coordinate;
  if (!subject) return [];
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.accessibilityDisruptions,
    {
      select: "title,description,category,subcategory,status,start_date,end_date,location_point",
      where: `${soql.withinCircle("location_point", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS)} AND (status IS NULL OR upper(status) != 'CLOSED')`,
      order: "start_date DESC",
      limit: 10,
    },
    init,
  ).catch(() => []);

  const withDistance = rows.flatMap((row) => {
    const title = rowString(row, "title");
    if (!title) return [];
    const coordinate = parseCoordinate(row);
    if (!coordinate) return [];
    const distance = distanceMeters(coordinate, subject);
    const detail = [
      rowString(row, "category"),
      rowString(row, "subcategory"),
      rowString(row, "description"),
    ]
      .map((v) => plainText(v))
      .filter((v): v is string => v != null && v.length > 0)
      .join(" · ");
    const disruption: StreetDisruption = {
      title,
      detail: detail.length ? detail : undefined,
      status: rowString(row, "status"),
      startDate: parseDate(rowString(row, "start_date")),
      endDate: parseDate(rowString(row, "end_date")),
      distanceDescription: distanceDescription(distance),
      coordinate,
    };
    return [{ disruption, distance }];
  });

  return withDistance.sort((a, b) => a.distance - b.distance).map((x) => x.disruption);
}

/** Active lane closures on the address's street. */
async function fetchLaneClosures(
  address: NormalizedAddress,
  init?: { signal?: AbortSignal },
): Promise<StreetDisruption[]> {
  const token = escaped(streetCore(address.streetName));
  if (!token) return [];
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.laneClosures,
    {
      select:
        "primary_street,cross_street,boundaries,direction,date_closed_from,date_closed_to,traffic_effect,status,complete_closure,latitude,longitude",
      where: `upper(primary_street) like '${token}%' AND (status IS NULL OR upper(status) != 'CLOSED')`,
      order: "date_closed_from DESC",
      limit: 10,
    },
    init,
  ).catch(() => []);

  const closures = rows.flatMap((row) => {
    const street = rowString(row, "primary_street");
    if (!street) return [];
    const title = [street, rowString(row, "cross_street")]
      .filter((v): v is string => v != null)
      .join(" at ");
    const detail = [
      rowString(row, "traffic_effect"),
      rowString(row, "boundaries"),
      rowString(row, "direction"),
    ]
      .filter((v): v is string => v != null)
      .join(" · ");
    const disruption: StreetDisruption = {
      title,
      detail: detail.length ? detail : undefined,
      status: rowString(row, "status") ?? rowString(row, "complete_closure"),
      startDate: parseDate(rowString(row, "date_closed_from")),
      endDate: parseDate(rowString(row, "date_closed_to")),
      distanceDescription: undefined,
      coordinate: parseCoordinate(row),
    };
    return [disruption];
  });

  // The feed repeats one physical closure across several rows (per-day status
  // entries); collapse to one card row per closure span.
  const seen = new Set<string>();
  return closures.filter((c) => {
    const key = [c.title, c.detail ?? "", c.startDate ?? "", c.endDate ?? ""].join("|");
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export async function fetchStreetAccess(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<StreetAccessSummary | undefined> {
  const [pavement, schoolSpeedLimit, cyclingRoutesNearby, activeDisruptions, activeLaneClosures] =
    await Promise.all([
      fetchPavementCondition(address, init),
      fetchSchoolSpeedLimit(address, init),
      fetchCyclingRoutes(property, init),
      fetchAccessibilityDisruptions(property, init),
      fetchLaneClosures(address, init),
    ]);

  if (
    pavement.condition == null &&
    pavement.surface == null &&
    pavement.roadType == null &&
    schoolSpeedLimit == null &&
    cyclingRoutesNearby === 0 &&
    activeDisruptions.length === 0 &&
    activeLaneClosures.length === 0
  ) {
    return undefined;
  }

  return {
    pavementCondition: pavement.condition,
    pavementSurface: pavement.surface,
    roadType: pavement.roadType,
    schoolSpeedLimit,
    cyclingRoutesNearby,
    activeDisruptions,
    activeLaneClosures,
  };
}
