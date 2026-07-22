// Local business module — licensed businesses within 500 m + seasonal patios.
// Port of fetchLocalBusiness / cleanBusinessCategory from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { titleCase } from "../../format";
import { parseCoordinate, rowString } from "../row";
import { IncidentBreakdown, LocalBusinessRecord, LocalBusinessSummary, PropertyAssessment } from "../types";
import { distanceDescription, distanceMeters } from "../util";

const NEARBY_RADIUS_METERS = 500;

/** WinnipegProvider.cleanBusinessCategory */
function cleanBusinessCategory(raw?: string): string | undefined {
  if (!raw) return undefined;
  const cleaned = raw
    .replace(/License - /g, "")
    .replace(/Licence - /g, "")
    .trim();
  return cleaned.length ? cleaned : undefined;
}

export async function fetchLocalBusiness(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<LocalBusinessSummary | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  // Primary determining fetch — let it throw so the module is marked failed.
  const businesses = await fetchDataset(
    WINNIPEG_DATASETS.businessLicenses,
    {
      select: "trade_name,folder_description,subdescription,status,location",
      where: `${soql.withinCircle("location", subject.latitude, subject.longitude, 500)} AND upper(status) not like '%CLOSED%' AND upper(status) not like '%CANCEL%'`,
      limit: 300,
    },
    init,
  );

  // Auxiliary enrichment — degrade quietly on failure.
  const patioData = await fetchDataset(
    WINNIPEG_DATASETS.seasonalPatios,
    {
      select: "name,address,operational_dates,location",
      where: soql.withinCircle("location", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
      limit: 20,
    },
    init,
  ).catch(() => []);

  const categoryCounts = new Map<string, number>();
  const records: { record: LocalBusinessRecord; distance: number }[] = [];
  for (const row of businesses) {
    const name = rowString(row, "trade_name");
    if (!name) continue;
    const category = cleanBusinessCategory(rowString(row, "folder_description") ?? rowString(row, "subdescription"));
    if (category) categoryCounts.set(category, (categoryCounts.get(category) ?? 0) + 1);
    const coordinate = parseCoordinate(row);
    const distance = coordinate ? distanceMeters(coordinate, subject) : Number.MAX_VALUE;
    records.push({
      record: {
        name: titleCase(name) ?? name,
        category,
        distanceDescription: coordinate ? distanceDescription(distance) : undefined,
        coordinate,
      },
      distance,
    });
  }

  const topCategories: IncidentBreakdown[] = [...categoryCounts.entries()]
    .map(([incidentType, count]) => ({ incidentType, count, citywideAverage: 0 }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 6);

  const recent = [...records]
    .sort((a, b) => a.distance - b.distance)
    .slice(0, 8)
    .map((r) => r.record);

  // A single venue registers one row per patio section, so the raw feed repeats
  // the same name many times — keep only the nearest instance of each venue.
  const patiosByName = new Map<string, { record: LocalBusinessRecord; distance: number }>();
  for (const row of patioData) {
    const name = rowString(row, "name");
    const coordinate = parseCoordinate(row);
    if (!name || !coordinate) continue;
    const distance = distanceMeters(coordinate, subject);
    const key = name.trim().toLowerCase();
    const existing = patiosByName.get(key);
    if (existing && existing.distance <= distance) continue;
    patiosByName.set(key, {
      record: {
        name,
        category: rowString(row, "operational_dates"),
        distanceDescription: distanceDescription(distance),
        coordinate,
      },
      distance,
    });
  }
  const patios = [...patiosByName.values()]
    .sort((a, b) => a.distance - b.distance)
    .map((r) => r.record);

  if (records.length === 0 && patios.length === 0) return undefined;

  return {
    totalNearby: records.length,
    topCategories,
    recent,
    patios: patios.slice(0, 6),
  };
}
