// Transit module — nearby stops/routes from Transit on-time performance, plus
// pass-ups and estimated daily boardings. Ports fetchTransit,
// fetchTransitPassUps, fetchPassengerActivity from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { Coordinate, escaped, parseCoordinate, rowDouble, rowInt, rowString } from "../row";
import { PropertyAssessment, TransitAccessSummary, TransitRouteSummary } from "../types";
import { distanceMeters, distanceDescription, yearOffset } from "../util";

const NEARBY_RADIUS_METERS = 500;

/** Pass-ups (full buses that skipped a nearby stop) counted over the last year. */
async function fetchTransitPassUps(subject: Coordinate, init?: { signal?: AbortSignal }): Promise<number> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.transitPassUps,
    {
      select: "count(*) as cnt",
      where: `${soql.withinCircle("location", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS)} AND time >= '${yearOffset(-1)}-01-01T00:00:00'`,
    },
    init,
  ).catch(() => []);
  return rowInt(rows[0], "cnt") ?? 0;
}

/** Estimated weekday boardings summed across the nearby stops (first 12). */
async function fetchPassengerActivity(stopNumbers: string[], init?: { signal?: AbortSignal }): Promise<number | undefined> {
  const stops = stopNumbers.slice(0, 12);
  if (stops.length === 0) return undefined;
  const stopList = stops.map((s) => `'${escaped(s)}'`).join(",");
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.transitPassengerActivity,
    {
      select: "sum(average_boardings) as boardings",
      where: `stop_number in (${stopList}) AND day_type='Weekday'`,
    },
    init,
  ).catch(() => []);
  return rowDouble(rows[0], "boardings");
}

export async function fetchTransit(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<TransitAccessSummary | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  // Primary determining fetch — let it throw so the orchestrator marks failed.
  const nearbyRows = await fetchDataset(
    WINNIPEG_DATASETS.transitOnTime,
    {
      select: "stop_number,route_number,route_name,deviation,location",
      where: soql.withinCircle("location", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
      limit: 800,
    },
    init,
  );
  if (nearbyRows.length === 0) return undefined;

  let nearestStop: { stop: string; distance: number } | undefined;
  const routesByNumber = new Map<string, TransitRouteSummary>();
  const deviations: number[] = [];
  let onTimeCount = 0;
  const stopNumbers = new Set<string>();

  for (const row of nearbyRows) {
    const stop = rowString(row, "stop_number");
    if (stop) {
      stopNumbers.add(stop);
      const coord = parseCoordinate(row);
      if (coord) {
        const distance = distanceMeters(coord, subject);
        if (!nearestStop || distance < nearestStop.distance) {
          nearestStop = { stop, distance };
        }
      }
    }
    const route = rowString(row, "route_number");
    if (route) {
      routesByNumber.set(route, {
        routeNumber: route,
        routeName: rowString(row, "route_name") ?? `Route ${route}`,
      });
    }
    const deviation = rowDouble(row, "deviation");
    if (deviation != null) {
      deviations.push(deviation);
      if (deviation >= -180 && deviation <= 60) onTimeCount += 1;
    }
  }

  const nearbyStopNumbers = [...stopNumbers];
  const [passUps, passengerActivity] = await Promise.all([
    fetchTransitPassUps(subject, init),
    fetchPassengerActivity(nearbyStopNumbers, init),
  ]);

  const averageDeviation = deviations.length
    ? deviations.reduce((a, b) => a + b, 0) / deviations.length
    : undefined;
  const onTimePercent = deviations.length ? (onTimeCount / deviations.length) * 100 : undefined;

  return {
    nearestStop: nearestStop
      ? { stopNumber: nearestStop.stop, distanceDescription: distanceDescription(nearestStop.distance) }
      : undefined,
    routes: [...routesByNumber.values()].sort((a, b) =>
      a.routeNumber.localeCompare(b.routeNumber, undefined, { numeric: true }),
    ),
    averageDeviationSeconds: averageDeviation,
    onTimePercentage: onTimePercent,
    passUpsLastYear: passUps,
    averageDailyBoardings: passengerActivity,
  };
}
