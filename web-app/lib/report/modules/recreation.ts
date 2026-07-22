// Recreation module — nearby recreation complexes (within 5 km), community
// centres (within 3 km), and leisure activities registered at those complexes.
// Ports fetchRecreation / fetchNearbyRecreationComplexes /
// fetchNearbyCommunityCentres / fetchLeisureActivities from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql, SocrataRow } from "../../socrata";
import { escaped, parseCoordinate, rowString } from "../row";
import {
  CommunityCentre,
  PropertyAssessment,
  RecreationActivity,
  RecreationComplex,
  RecreationSummary,
} from "../types";
import { distanceDescription, distanceMeters, parseDate, yearOffset } from "../util";

const COMPLEX_LIMIT = 8;
const CENTRE_LIMIT = 5;

/** OpenDataClient.bool — Socrata booleans arrive as true / "true"/"yes"/"1" / 1. */
function rowBool(row: SocrataRow, key: string): boolean {
  const v = row[key];
  if (typeof v === "boolean") return v;
  if (typeof v === "string") return ["true", "yes", "1"].includes(v.toLowerCase());
  if (typeof v === "number") return v !== 0;
  return false;
}

const COMPLEX_AMENITIES: [label: string, key: string][] = [
  ["Arena", "arena"],
  ["Community centre", "community_centre"],
  ["Fitness", "fitness_leisure_centre"],
  ["Indoor pool", "indoor_pool"],
  ["Outdoor pool", "outdoor_pool"],
  ["Wading pool", "wading_pool"],
  ["Spray pad", "spray_pad"],
  ["Skate park", "skate_park"],
  ["Indoor soccer", "indoor_soccer"],
  ["Library", "library"],
];

export async function fetchRecreation(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<RecreationSummary | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  // Primary determining fetch: nearby recreation complexes. Let it throw so the
  // orchestrator can distinguish a genuine backend failure from an empty result.
  const complexRows = await fetchDataset(
    WINNIPEG_DATASETS.recreationComplexes,
    {
      select:
        "complex_name,address,location_1_geom,skate_park,fitness_leisure_centre,outdoor_pool,indoor_pool,arena,community_centre,wading_pool,library,indoor_soccer,spray_pad",
      where: soql.withinCircle("location_1_geom", subject.latitude, subject.longitude, 5000),
      limit: 80,
    },
    init,
  );

  const complexes: RecreationComplex[] = complexRows
    .flatMap((row) => {
      const name = rowString(row, "complex_name");
      const coordinate = parseCoordinate(row);
      if (!name || !coordinate) return [];
      const distance = distanceMeters(coordinate, subject);
      const amenities = COMPLEX_AMENITIES.filter(([, key]) => rowBool(row, key)).map(([label]) => label);
      return [
        {
          complex: {
            name,
            address: rowString(row, "address"),
            distanceDescription: distanceDescription(distance),
            amenities,
            coordinate,
          } satisfies RecreationComplex,
          distance,
        },
      ];
    })
    .sort((a, b) => a.distance - b.distance)
    .slice(0, COMPLEX_LIMIT)
    .map((x) => x.complex);

  // Auxiliary fetches degrade gracefully.
  const communityCentres = await fetchNearbyCommunityCentres(subject, init).catch(() => []);
  const activities = await fetchLeisureActivities(complexes, init).catch(() => []);

  if (complexes.length === 0 && activities.length === 0 && communityCentres.length === 0) {
    return undefined;
  }
  return {
    nearestComplex: complexes[0],
    complexes,
    activities,
    communityCentres,
  };
}

async function fetchNearbyCommunityCentres(
  subject: { latitude: number; longitude: number },
  init?: { signal?: AbortSignal },
): Promise<CommunityCentre[]> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.recreationComplexes,
    {
      select: "complex_name,address,location_1_geom",
      where: `${soql.withinCircle("location_1_geom", subject.latitude, subject.longitude, 3000)} AND community_centre=true`,
      limit: 80,
    },
    init,
  );

  return rows
    .flatMap((row) => {
      const name = rowString(row, "complex_name");
      const coordinate = parseCoordinate(row);
      if (!name || !coordinate) return [];
      const distance = distanceMeters(coordinate, subject);
      return [
        {
          centre: {
            name,
            address: rowString(row, "address"),
            distanceDescription: distanceDescription(distance),
            coordinate,
          } satisfies CommunityCentre,
          distance,
        },
      ];
    })
    .sort((a, b) => a.distance - b.distance)
    .slice(0, CENTRE_LIMIT)
    .map((x) => x.centre);
}

async function fetchLeisureActivities(
  complexes: RecreationComplex[],
  init?: { signal?: AbortSignal },
): Promise<RecreationActivity[]> {
  const placeNames = [...new Set(complexes.map((c) => c.name).filter((n) => n.length))].slice(0, 6);
  if (placeNames.length === 0) return [];
  const placeList = placeNames.map((n) => `'${escaped(n.toUpperCase())}'`).join(",");
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.leisureActivities,
    {
      select:
        "activity_name,place_name,category,activity_type,activity_status,default_beginning_date,default_ending_date,open_spaces,public_url",
      where: `upper(place_name) in (${placeList}) AND default_beginning_date >= '${yearOffset(0)}-01-01T00:00:00'`,
      order: "default_beginning_date ASC",
      limit: 24,
    },
    init,
  );

  return rows.flatMap((row) => {
    const name = rowString(row, "activity_name");
    if (!name) return [];
    return [
      {
        name,
        placeName: rowString(row, "place_name"),
        category: rowString(row, "category"),
        activityType: rowString(row, "activity_type"),
        status: rowString(row, "activity_status"),
        startDate: parseDate(rowString(row, "default_beginning_date")),
        endDate: parseDate(rowString(row, "default_ending_date")),
        openSpaces: rowString(row, "open_spaces"),
        publicURL: rowString(row, "public_url"),
      } satisfies RecreationActivity,
    ];
  });
}
