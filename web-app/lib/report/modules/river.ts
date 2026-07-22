// River gauge module — nearest river-level gauge within 7 km of the subject
// property. Port of WinnipegProvider.fetchRiverGauge.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { parseCoordinate, rowDouble, rowString } from "../row";
import { PropertyAssessment, RiverGaugeSummary } from "../types";
import { distanceDescription, distanceMeters, parseDate } from "../util";

export async function fetchRiverGauge(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<RiverGaugeSummary | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.riverWaterLevels,
    {
      select:
        "river_name,location,james_feet,geodetic_feet,geodetic_metric,reading_date,notes,coordinate",
      where: soql.withinCircle("coordinate", subject.latitude, subject.longitude, 7000),
      limit: 60,
    },
    init,
  );

  let nearest: { row: (typeof rows)[number]; distance: number } | undefined;
  for (const row of rows) {
    const coordinate = parseCoordinate(row);
    if (!coordinate) continue;
    const distance = distanceMeters(coordinate, subject);
    if (!nearest || distance < nearest.distance) nearest = { row, distance };
  }
  if (!nearest) return undefined;

  return {
    riverName: rowString(nearest.row, "river_name") ?? "River",
    location: rowString(nearest.row, "location") ?? "Gauge",
    distanceDescription: distanceDescription(nearest.distance),
    jamesFeet: rowDouble(nearest.row, "james_feet"),
    geodeticFeet: rowDouble(nearest.row, "geodetic_feet"),
    geodeticMetric: rowDouble(nearest.row, "geodetic_metric"),
    readingDate: parseDate(rowString(nearest.row, "reading_date")),
    notes: rowString(nearest.row, "notes"),
    coordinate: parseCoordinate(nearest.row),
  };
}
