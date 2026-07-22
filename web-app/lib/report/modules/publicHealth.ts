// Public health module — naloxone/opioid-response overdose events and substance
// use per neighbourhood (vs. citywide average), plus nearby public AEDs. Port of
// WinnipegProvider.fetchPublicHealth (+ fetchNearbyAEDs / ER / walk-in helpers).
//
// PARITY GAP: the app's nearest-ER, nearest-walk-in, and WRHA emergency wait-time
// enrichment come from MapKit MKLocalSearch (nearestER/nearestWalkIn) — an on-device
// Apple service with no server-fetchable equivalent — and the WRHA wait-time match
// keys off that ER's name. There is no faithful web port, so those fields stay
// undefined here. Everything else (overdose events, substances, AEDs) is CDS-backed
// and ported 1:1.

import { WINNIPEG_DATASETS } from "../../datasets";
import { SocrataRow, fetchDataset, soql } from "../../socrata";
import { Coordinate, parseCoordinate, rowInt, rowString } from "../row";
import {
  DefibrillatorAccess,
  IncidentBreakdown,
  PublicHealthSummary,
  PublicHealthYear,
} from "../types";
import { distanceDescription, distanceMeters, yearOffset } from "../util";

/** OpenDataClient.bool — "true"/"yes"/"1" (case-insensitive) or a non-zero number. */
function rowBool(row: SocrataRow, key: string): boolean {
  const v = row[key];
  if (typeof v === "boolean") return v;
  if (typeof v === "string") return ["true", "yes", "1"].includes(v.toLowerCase());
  if (typeof v === "number") return v !== 0;
  return false;
}

export async function fetchPublicHealth(
  neighbourhood: string | undefined,
  coordinate: Coordinate | undefined,
  init?: { signal?: AbortSignal },
): Promise<PublicHealthSummary | undefined> {
  const naloxone = WINNIPEG_DATASETS.naloxone;
  const substanceDataset = WINNIPEG_DATASETS.substanceUse;
  const sixYearFloor = `${yearOffset(-6)}-01-01T00:00:00`;

  // PRIMARY determining fetch — citywide overdose events by year/neighbourhood.
  // Not wrapped in .catch so a transport/HTTP failure marks the module failed.
  const citywideNeighbourhoodYears = await fetchDataset(
    naloxone,
    {
      select: "date_extract_y(dispatch_date) as year, neighbourhood, count(*) as cnt",
      where: `dispatch_date >= '${sixYearFloor}' AND neighbourhood IS NOT NULL`,
      group: "year, neighbourhood",
      order: "year",
      limit: 50000,
    },
    init,
  );

  const neighbourhoodYears = neighbourhood
    ? await fetchDataset(
        naloxone,
        {
          select: "date_extract_y(dispatch_date) as year, count(*) as cnt",
          where: `upper(neighbourhood)=${soql.str(neighbourhood.toUpperCase())} AND dispatch_date >= '${sixYearFloor}'`,
          group: "year",
          order: "year",
        },
        init,
      ).catch(() => [] as SocrataRow[])
    : [];

  const ages = await fetchDataset(
    naloxone,
    {
      select: "age, count(*) as cnt",
      group: "age",
      order: "cnt DESC",
      limit: 6,
    },
    init,
  ).catch(() => [] as SocrataRow[]);

  const ageNeighbourhoodClause = neighbourhood
    ? `upper(neighbourhood)=${soql.str(neighbourhood.toUpperCase())} AND `
    : "";
  const agesByYearRows = await fetchDataset(
    naloxone,
    {
      select: "date_extract_y(dispatch_date) as year, age, count(*) as cnt",
      where: `${ageNeighbourhoodClause}dispatch_date >= '${sixYearFloor}' AND age IS NOT NULL`,
      group: "year, age",
      order: "year, cnt DESC",
    },
    init,
  ).catch(() => [] as SocrataRow[]);

  const neighbourhoodClause = neighbourhood
    ? `upper(neighbourhood)=${soql.str(neighbourhood.toUpperCase())} AND `
    : "";
  const [
    substances,
    substancesByYearRows,
    citySubstances,
    citySubstancesByYearRows,
    citySubstanceNeighbourhoodRows,
  ] = await Promise.all([
    fetchDataset(
      substanceDataset,
      {
        select: "substance, count(*) as cnt",
        where: `${neighbourhoodClause}dispatch_date >= '${sixYearFloor}' AND substance IS NOT NULL`,
        group: "substance",
        order: "cnt DESC",
        limit: 8,
      },
      init,
    ).catch(() => [] as SocrataRow[]),
    fetchDataset(
      substanceDataset,
      {
        select: "date_extract_y(dispatch_date) as year, substance, count(*) as cnt",
        where: `${neighbourhoodClause}dispatch_date >= '${sixYearFloor}' AND substance IS NOT NULL`,
        group: "year, substance",
        order: "year, cnt DESC",
      },
      init,
    ).catch(() => [] as SocrataRow[]),
    fetchDataset(
      substanceDataset,
      {
        select: "substance, count(*) as cnt",
        where: `dispatch_date >= '${sixYearFloor}' AND substance IS NOT NULL AND neighbourhood IS NOT NULL`,
        group: "substance",
      },
      init,
    ).catch(() => [] as SocrataRow[]),
    fetchDataset(
      substanceDataset,
      {
        select: "date_extract_y(dispatch_date) as year, substance, count(*) as cnt",
        where: `dispatch_date >= '${sixYearFloor}' AND substance IS NOT NULL AND neighbourhood IS NOT NULL`,
        group: "year, substance",
      },
      init,
    ).catch(() => [] as SocrataRow[]),
    fetchDataset(
      substanceDataset,
      {
        select: "count(distinct neighbourhood) as nbh",
        where: `dispatch_date >= '${sixYearFloor}' AND substance IS NOT NULL AND neighbourhood IS NOT NULL`,
      },
      init,
    ).catch(() => [] as SocrataRow[]),
  ]);
  const citySubstanceNeighbourhoodCount =
    (citySubstanceNeighbourhoodRows[0] && rowInt(citySubstanceNeighbourhoodRows[0], "nbh")) ?? 0;

  // Merge neighbourhood vs. citywide-average counts per year.
  const citywideCountsByYear = new Map<number, number[]>();
  for (const row of citywideNeighbourhoodYears) {
    const year = rowInt(row, "year");
    const count = rowInt(row, "cnt");
    if (year == null || count == null) continue;
    if (!citywideCountsByYear.has(year)) citywideCountsByYear.set(year, []);
    citywideCountsByYear.get(year)!.push(count);
  }

  const mergedYears = new Map<number, { neighbourhood: number; citywideAverage: number }>();
  const ensureYear = (year: number) => {
    let e = mergedYears.get(year);
    if (!e) {
      e = { neighbourhood: 0, citywideAverage: 0 };
      mergedYears.set(year, e);
    }
    return e;
  };
  for (const [year, counts] of citywideCountsByYear) {
    if (!counts.length) continue;
    ensureYear(year).citywideAverage = counts.reduce((a, b) => a + b, 0) / counts.length;
  }
  for (const row of neighbourhoodYears) {
    const year = rowInt(row, "year");
    const count = rowInt(row, "cnt");
    if (year == null || count == null) continue;
    ensureYear(year).neighbourhood = count;
  }

  const ageGroupsByYear = new Map<number, IncidentBreakdown[]>();
  for (const row of agesByYearRows) {
    const year = rowInt(row, "year");
    const age = rowString(row, "age");
    const count = rowInt(row, "cnt");
    if (year == null || age == null || count == null) continue;
    if (!ageGroupsByYear.has(year)) ageGroupsByYear.set(year, []);
    ageGroupsByYear.get(year)!.push({ incidentType: age, count, citywideAverage: 0 });
  }

  const substancesByYear = new Map<number, IncidentBreakdown[]>();
  const substanceTotalsByYear = new Map<number, number>();
  for (const row of substancesByYearRows) {
    const year = rowInt(row, "year");
    const substance = rowString(row, "substance");
    const count = rowInt(row, "cnt");
    if (year == null || substance == null || count == null) continue;
    if (!substancesByYear.has(year)) substancesByYear.set(year, []);
    substancesByYear.get(year)!.push({ incidentType: substance, count, citywideAverage: 0 });
    substanceTotalsByYear.set(year, (substanceTotalsByYear.get(year) ?? 0) + count);
  }
  // Fall back to substance totals for years the naloxone feed didn't cover.
  for (const [year, count] of substanceTotalsByYear) {
    const e = ensureYear(year);
    if (e.neighbourhood === 0) e.neighbourhood = count;
  }

  const citySubstanceTotals = new Map<string, number>();
  for (const row of citySubstances) {
    const substance = rowString(row, "substance");
    const count = rowInt(row, "cnt");
    if (substance == null || count == null) continue;
    citySubstanceTotals.set(substance, count);
  }
  const citySubstanceTotalsByYear = new Map<number, Map<string, number>>();
  for (const row of citySubstancesByYearRows) {
    const year = rowInt(row, "year");
    const substance = rowString(row, "substance");
    const count = rowInt(row, "cnt");
    if (year == null || substance == null || count == null) continue;
    if (!citySubstanceTotalsByYear.has(year)) citySubstanceTotalsByYear.set(year, new Map());
    citySubstanceTotalsByYear.get(year)!.set(substance, count);
  }
  const cityAvgForSubstance = (substance: string): number =>
    citySubstanceNeighbourhoodCount > 0
      ? (citySubstanceTotals.get(substance) ?? 0) / citySubstanceNeighbourhoodCount
      : 0;
  const cityAvgForSubstanceYear = (substance: string, year: number): number =>
    citySubstanceNeighbourhoodCount > 0
      ? (citySubstanceTotalsByYear.get(year)?.get(substance) ?? 0) / citySubstanceNeighbourhoodCount
      : 0;

  const aedData = await fetchNearbyAEDs(coordinate, init);

  const yearlyEvents: PublicHealthYear[] = [...mergedYears.keys()]
    .sort((a, b) => a - b)
    .map((year) => {
      const counts = mergedYears.get(year)!;
      return { year, neighbourhood: counts.neighbourhood, citywideAverage: counts.citywideAverage };
    });

  const ageGroups: IncidentBreakdown[] = ages.flatMap((row) => {
    const age = rowString(row, "age");
    const count = rowInt(row, "cnt");
    if (age == null || count == null) return [];
    return [{ incidentType: age, count, citywideAverage: 0 }];
  });

  const ageGroupsByYearObj: Record<number, IncidentBreakdown[]> = {};
  for (const [year, items] of ageGroupsByYear) {
    ageGroupsByYearObj[year] = [...items].sort((a, b) => b.count - a.count);
  }

  const substancesTop: IncidentBreakdown[] = substances.flatMap((row) => {
    const substance = rowString(row, "substance");
    const count = rowInt(row, "cnt");
    if (substance == null || count == null) return [];
    return [{ incidentType: substance, count, citywideAverage: cityAvgForSubstance(substance) }];
  });

  const substancesByYearObj: Record<number, IncidentBreakdown[]> = {};
  for (const [year, items] of substancesByYear) {
    substancesByYearObj[year] = items
      .map((item) => ({
        incidentType: item.incidentType,
        count: item.count,
        citywideAverage: cityAvgForSubstanceYear(item.incidentType, year),
      }))
      .sort((a, b) => b.count - a.count);
  }

  const summary: PublicHealthSummary = {
    yearlyEvents,
    ageGroups,
    ageGroupsByYear: ageGroupsByYearObj,
    substances: substancesTop,
    substancesByYear: substancesByYearObj,
    nearestAED: aedData.nearest,
    aedsNearby: aedData.count,
  };

  if (
    summary.yearlyEvents.length === 0 &&
    summary.ageGroups.length === 0 &&
    summary.substances.length === 0 &&
    summary.nearestER == null &&
    summary.nearestWalkIn == null &&
    summary.nearestAED == null
  ) {
    return undefined;
  }
  return summary;
}

async function fetchNearbyAEDs(
  coordinate: Coordinate | undefined,
  init?: { signal?: AbortSignal },
): Promise<{ nearest?: DefibrillatorAccess; count: number }> {
  if (!coordinate) return { count: 0 };
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.publicAeds,
    {
      select: "name,location_description,access,indoor,source,location",
      where: soql.withinCircle("location", coordinate.latitude, coordinate.longitude, 500),
      limit: 50,
    },
    init,
  ).catch(() => [] as SocrataRow[]);

  const matches = rows
    .flatMap((row) => {
      const aedCoordinate = parseCoordinate(row);
      if (!aedCoordinate) return [];
      const distance = distanceMeters(coordinate, aedCoordinate);
      const aed: DefibrillatorAccess = {
        name: rowString(row, "name") ?? "Public AED",
        locationDescription: rowString(row, "location_description"),
        access: rowString(row, "access"),
        indoor: rowBool(row, "indoor"),
        distanceDescription: distanceDescription(distance),
        coordinate: aedCoordinate,
        source: rowString(row, "source"),
      };
      return [{ aed, distance }];
    })
    .sort((a, b) => a.distance - b.distance);

  return { nearest: matches[0]?.aed, count: matches.length };
}
