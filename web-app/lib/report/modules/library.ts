// Library module — nearest public library within 7 km of the subject property.
// Ports fetchLibrary from WinnipegProvider: pull candidate libraries within a
// wide circle, then pick the single closest by great-circle distance.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql, SocrataRow } from "../../socrata";
import { parseCoordinate, rowInt, rowString } from "../row";
import { PropertyAssessment, LibraryAmenity } from "../types";
import { distanceDescription, distanceMeters } from "../util";

const SEARCH_RADIUS_METERS = 7000;

/** Dictionary.bool — treats "true"/"yes"/"1" (and truthy numbers) as true, else false. */
function rowBool(row: SocrataRow, key: string): boolean {
  const v = row[key];
  if (typeof v === "boolean") return v;
  if (typeof v === "string") return ["true", "yes", "1"].includes(v.toLowerCase());
  if (typeof v === "number") return v !== 0;
  return false;
}

export async function fetchLibrary(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<LibraryAmenity | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.libraries,
    {
      select: "name,address,wifi,accessibilty,room_rentals,parking_lot,parkng_stalls,notes,point",
      where: soql.withinCircle("point", subject.latitude, subject.longitude, SEARCH_RADIUS_METERS),
      limit: 30,
    },
    init,
  );

  let nearest: { row: SocrataRow; distance: number } | undefined;
  for (const row of rows) {
    const coordinate = parseCoordinate(row);
    if (!coordinate) continue;
    const distance = distanceMeters(coordinate, subject);
    if (!nearest || distance < nearest.distance) nearest = { row, distance };
  }
  if (!nearest) return undefined;

  const { row, distance } = nearest;
  return {
    name: rowString(row, "name") ?? "Library",
    address: rowString(row, "address") ?? "Address unavailable",
    distanceDescription: distanceDescription(distance),
    wifi: rowBool(row, "wifi"),
    accessibility: rowBool(row, "accessibilty"),
    parkingLot: rowBool(row, "parking_lot"),
    parkingStalls: rowInt(row, "parkng_stalls"),
    roomRentals: rowBool(row, "room_rentals"),
    notes: rowString(row, "notes"),
    coordinate: parseCoordinate(row),
  } satisfies LibraryAmenity;
}
