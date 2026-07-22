// Parks module — nearby parks (with amenity tallies), nearest off-leash dog park,
// and neighbourhood park count/hectares. Ports fetchParks + fetchNearbyParks,
// fetchNearestDogPark, fetchNeighbourhoodParks from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, parseCoordinate, rowDouble, rowInt, rowString, Coordinate } from "../row";
import { DogParkAmenity, ParkAmenity, ParksSummary, PropertyAssessment } from "../types";
import { distanceDescription, distanceMeters } from "../util";

const NEARBY_LIMIT = 20;
const DOG_PARK_RADIUS_METERS = 3000;

/** Title-case a string (Swift's String.capitalized on each word). */
function capitalizedWords(value: string): string {
  return value.toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
}

export async function fetchParks(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<ParksSummary | undefined> {
  if (!property) return undefined;

  const [nearbyParks, nearestDogPark, neighbourhoodStats] = await Promise.all([
    fetchNearbyParks(property, init),
    fetchNearestDogPark(property, init),
    fetchNeighbourhoodParks(property.neighbourhood, init),
  ]);

  const nearestPark = nearbyParks[0];
  if (!nearestPark && !nearestDogPark && neighbourhoodStats.count === 0) return undefined;

  return {
    nearestPark,
    nearbyParks,
    neighbourhoodParkCount: neighbourhoodStats.count,
    neighbourhoodHectares: neighbourhoodStats.hectares,
    nearestDogPark,
  };
}

interface ParkAccumulator {
  parkID: string;
  name: string;
  distance: number;
  coordinate?: Coordinate;
  playgrounds: number;
  fields: number;
  courts: number;
  washrooms: number;
  benches: number;
}

async function fetchNearbyParks(
  property: PropertyAssessment,
  init?: { signal?: AbortSignal },
): Promise<ParkAmenity[]> {
  const subject = property.coordinate;
  if (!subject) return [];

  // Primary determining fetch — allowed to throw so the module is marked failed.
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.parkAssets,
    {
      select: "park_id,park_name,asset_class,asset_type,point",
      where: `within_circle(point,${subject.latitude},${subject.longitude},500)`,
      limit: 500,
    },
    init,
  );

  const parksByID = new Map<string, ParkAccumulator>();
  for (const row of rows) {
    const parkID = rowString(row, "park_id");
    const name = rowString(row, "park_name");
    const coordinate = parseCoordinate(row);
    if (!parkID || !name || !coordinate) continue;
    const distance = distanceMeters(coordinate, subject);

    let item = parksByID.get(parkID);
    if (!item) {
      item = {
        parkID,
        name,
        distance,
        coordinate,
        playgrounds: 0,
        fields: 0,
        courts: 0,
        washrooms: 0,
        benches: 0,
      };
      parksByID.set(parkID, item);
    }
    if (distance < item.distance) {
      item.distance = distance;
      item.coordinate = coordinate;
    }
    const tokens = [rowString(row, "asset_class"), rowString(row, "asset_type")]
      .filter((t): t is string => t != null)
      .map((t) => t.toLowerCase())
      .join(" ");
    if (tokens.includes("play")) item.playgrounds += 1;
    if (tokens.includes("field") || tokens.includes("diamond") || tokens.includes("soccer")) item.fields += 1;
    if (tokens.includes("court") || tokens.includes("tennis") || tokens.includes("basketball")) item.courts += 1;
    if (tokens.includes("washroom") || tokens.includes("toilet")) item.washrooms += 1;
    if (tokens.includes("bench")) item.benches += 1;
  }

  return [...parksByID.values()]
    .sort((a, b) => a.distance - b.distance)
    .slice(0, NEARBY_LIMIT)
    .map((park) => ({
      parkID: park.parkID,
      name: park.name,
      distanceDescription: distanceDescription(park.distance),
      coordinate: park.coordinate,
      playgrounds: park.playgrounds,
      fields: park.fields,
      courts: park.courts,
      washrooms: park.washrooms,
      benches: park.benches,
    }));
}

async function fetchNeighbourhoodParks(
  neighbourhood: string,
  init?: { signal?: AbortSignal },
): Promise<{ count: number; hectares?: number }> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.parksOpenSpace,
    {
      select: "count(*) as cnt, sum(total_area_in_hectares) as hectares",
      where: `upper(neighbourhood)='${escaped(neighbourhood.toUpperCase())}'`,
    },
    init,
  ).catch(() => []);
  const first = rows[0];
  return {
    count: (first ? rowInt(first, "cnt") : undefined) ?? 0,
    hectares: first ? rowDouble(first, "hectares") : undefined,
  };
}

async function fetchNearestDogPark(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<DogParkAmenity | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.parkAssets,
    {
      select: "park_id,park_name,asset_type,point",
      where: `within_circle(point,${subject.latitude},${subject.longitude},${DOG_PARK_RADIUS_METERS}) AND asset_class='OFF-LEASH DOG AREA'`,
      limit: 100,
    },
    init,
  ).catch(() => []);

  const candidates = rows
    .flatMap((row) => {
      const parkID = rowString(row, "park_id");
      const name = rowString(row, "park_name");
      const coordinate = parseCoordinate(row);
      if (!parkID || !name || !coordinate) return [];
      const assetType = rowString(row, "asset_type");
      const dogPark: DogParkAmenity = {
        parkID,
        name,
        distanceDescription: distanceDescription(distanceMeters(coordinate, subject)),
        classification: assetType ? capitalizedWords(assetType) : undefined,
        coordinate,
      };
      return [{ dogPark, distance: distanceMeters(coordinate, subject) }];
    })
    .sort((a, b) => a.distance - b.distance);

  return candidates[0]?.dogPark;
}
