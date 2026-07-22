// Traffic module — midblock street traffic study (address street-core match) +
// nearest permanent count station within the default radius. Ports fetchTraffic,
// fetchStreetTrafficStudy, fetchNearestPermanentCount, trafficCountDay from
// WinnipegProvider.

import { NormalizedAddress, streetCore } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { escaped, parseCoordinate, rowInt, rowString } from "../row";
import { PropertyAssessment, TrafficStudy, TrafficSummary } from "../types";
import { distanceDescription, distanceMeters, parseDate } from "../util";

const NEARBY_RADIUS_METERS = 500;

/** First 10 chars of a Socrata timestamp — the calendar day. */
function trafficCountDay(value: string): string {
  return value.slice(0, 10);
}

export async function fetchTraffic(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<TrafficSummary | undefined> {
  const [streetStudy, nearestPermanentStation] = await Promise.all([
    fetchStreetTrafficStudy(address, init),
    fetchNearestPermanentCount(property, init),
  ]);
  if (!streetStudy && !nearestPermanentStation) return undefined;
  return { streetStudy, nearestPermanentStation };
}

/**
 * Primary determining fetch — lets the dataset request throw so the orchestrator
 * marks the module failed on transport/DB error.
 */
async function fetchStreetTrafficStudy(
  address: NormalizedAddress,
  init?: { signal?: AbortSignal },
): Promise<TrafficStudy | undefined> {
  const core = escaped(streetCore(address.streetName));
  if (!core) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.midblockTrafficCounts,
    {
      select: "count_date,location_description,count_15_minutes,count_direction",
      where: `upper(street) like '${core}%'`,
      order: "count_date DESC",
      limit: 400,
    },
    init,
  );
  if (!rows.length) return undefined;

  const latestDate = rowString(rows[0], "count_date");
  const latestDay = latestDate ? trafficCountDay(latestDate) : undefined;
  const latestLocation = rowString(rows[0], "location_description");
  const sameStudy = rows.filter((row) => {
    const d = rowString(row, "count_date");
    if ((d ? trafficCountDay(d) : undefined) !== latestDay) return false;
    if (latestLocation != null) return rowString(row, "location_description") === latestLocation;
    return true;
  });

  const grouped = new Map<string, number>();
  for (const row of sameStudy) {
    const key = rowString(row, "count_date") ?? "";
    const count = rowInt(row, "count_15_minutes");
    if (count == null) continue;
    grouped.set(key, (grouped.get(key) ?? 0) + count);
  }
  const intervalTotals = [...grouped.values()].filter((t) => t > 0);
  const hourlyAverage = intervalTotals.length
    ? Math.round((intervalTotals.reduce((a, b) => a + b, 0) / intervalTotals.length) * 4)
    : undefined;

  const directions = new Set(
    sameStudy.map((row) => rowString(row, "count_direction")).filter((d): d is string => !!d),
  );

  return {
    locationDescription: latestLocation ?? address.streetName,
    vehiclesCounted: hourlyAverage,
    countDate: parseDate(latestDate),
    direction: directions.size > 1 ? "Both directions" : [...directions][0],
    distanceDescription: undefined,
    countMetricLabel: "Avg. vehicles / hour",
    countSummaryUnit: "vehicles/hr avg",
    countNote:
      "Midblock traffic data is recorded in 15-minute intervals. This hourly figure is the average 15-minute count for the latest study day multiplied by four.",
  };
}

/** Enrichment fetch — degrades to no station on error. */
async function fetchNearestPermanentCount(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<TrafficStudy | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.permanentTrafficCounts,
    {
      select: "site,total,timestamp,latitude,longitude",
      where: soql.withinCircle("location", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
      order: "timestamp DESC",
      limit: 200,
    },
    init,
  ).catch(() => []);

  let nearest: TrafficStudy | undefined;
  let nearestDistance = Infinity;
  for (const row of rows) {
    const site = rowString(row, "site");
    const coordinate = parseCoordinate(row);
    if (!site || !coordinate) continue;
    const distance = distanceMeters(coordinate, subject);
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearest = {
        locationDescription: site,
        vehiclesCounted: rowInt(row, "total"),
        countDate: parseDate(rowString(row, "timestamp")),
        direction: undefined,
        distanceDescription: distanceDescription(distance),
        countMetricLabel: "Vehicles (latest count)",
        countSummaryUnit: "vehicles",
        countNote: undefined,
      };
    }
  }
  return nearest;
}
