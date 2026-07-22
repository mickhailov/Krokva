// Police crime module — unlike the other modules this hits ArcGIS directly
// (not CDS/Socrata): it downloads the city-wide WPS crime CSV once, parses it,
// and serves a pre-aggregated per-neighbourhood slice. Port of
// fetchPoliceCrime / PoliceCrimeStore.parse / incidentBreakdowns.

import { WINNIPEG_DATASETS } from "../../datasets";
import {
  IncidentBreakdown,
  PoliceCrimeMonth,
  PoliceCrimeSummary,
  PoliceCrimeYear,
} from "../types";

// Pre-aggregated crime counts for one neighbourhood of the city-wide WPS CSV.
interface CrimeSlice {
  yearly: Map<number, number>;
  crimeTypes: Map<string, number>;
  crimeTypesByYear: Map<number, Map<string, number>>;
  offenceTypes: Map<string, number>;
  offenceTypesByYear: Map<number, Map<string, number>>;
}

interface CrimeAggregates {
  slices: Map<string, CrimeSlice>;
  yearlyCityTotals: Map<number, number>;
  cityCrimeTypes: Map<string, number>;
  cityCrimeTypesByYear: Map<number, Map<string, number>>;
  cityOffenceTypes: Map<string, number>;
  cityOffenceTypesByYear: Map<number, Map<string, number>>;
  latestMonth?: PoliceCrimeMonth;
}

/** Case- and diacritic-insensitive slice key, mirroring Swift's `.folding`. */
function sliceKey(name: string): string {
  return name
    .trim()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function emptySlice(): CrimeSlice {
  return {
    yearly: new Map(),
    crimeTypes: new Map(),
    crimeTypesByYear: new Map(),
    offenceTypes: new Map(),
    offenceTypesByYear: new Map(),
  };
}

function bump(map: Map<string, number>, key: string, by: number): void {
  map.set(key, (map.get(key) ?? 0) + by);
}

function bumpYear(map: Map<number, Map<string, number>>, year: number, key: string, by: number): void {
  let inner = map.get(year);
  if (!inner) {
    inner = new Map();
    map.set(year, inner);
  }
  bump(inner, key, by);
}

/** Splits one CSV line, honouring double-quoted fields and "" escapes. */
function parseCSVLine(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  let isQuoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (isQuoted && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        isQuoted = !isQuoted;
      }
    } else if (ch === "," && !isQuoted) {
      fields.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  fields.push(current);
  return fields;
}

function parseCSV(csv: string): CrimeAggregates {
  const agg: CrimeAggregates = {
    slices: new Map(),
    yearlyCityTotals: new Map(),
    cityCrimeTypes: new Map(),
    cityCrimeTypesByYear: new Map(),
    cityOffenceTypes: new Map(),
    cityOffenceTypesByYear: new Map(),
    latestMonth: undefined,
  };

  const lines = csv.split(/\r\n|\r|\n/).slice(1); // drop header row
  for (const rawLine of lines) {
    const columns = parseCSVLine(rawLine);
    if (columns.length < 7) continue;
    const year = parseInt(columns[0], 10);
    const month = parseInt(columns[1], 10);
    const count = parseInt(columns[4], 10);
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(count)) continue;

    const neighbourhood = columns[2].trim();
    if (!neighbourhood || neighbourhood.toUpperCase() === "NA") continue;

    agg.yearlyCityTotals.set(year, (agg.yearlyCityTotals.get(year) ?? 0) + count);
    if (
      !agg.latestMonth ||
      year > agg.latestMonth.year ||
      (year === agg.latestMonth.year && month > agg.latestMonth.month)
    ) {
      agg.latestMonth = { year, month };
    }

    const crimeType = columns[5].trim();
    const offenceType = columns[6].trim();
    const key = sliceKey(neighbourhood);
    let slice = agg.slices.get(key);
    if (!slice) {
      slice = emptySlice();
      agg.slices.set(key, slice);
    }
    slice.yearly.set(year, (slice.yearly.get(year) ?? 0) + count);

    if (crimeType) {
      bump(agg.cityCrimeTypes, crimeType, count);
      bumpYear(agg.cityCrimeTypesByYear, year, crimeType, count);
      bump(slice.crimeTypes, crimeType, count);
      bumpYear(slice.crimeTypesByYear, year, crimeType, count);
    }
    if (offenceType) {
      bump(agg.cityOffenceTypes, offenceType, count);
      bumpYear(agg.cityOffenceTypesByYear, year, offenceType, count);
      bump(slice.offenceTypes, offenceType, count);
      bumpYear(slice.offenceTypesByYear, year, offenceType, count);
    }
  }
  return agg;
}

/** Breakdowns annotated with the city-wide average count per neighbourhood. */
function incidentBreakdowns(
  counts: Map<string, number>,
  cityTotals: Map<string, number>,
  neighbourhoodCount: number,
): IncidentBreakdown[] {
  return [...counts.entries()]
    .map(([incidentType, count]) => ({
      incidentType,
      count,
      citywideAverage: neighbourhoodCount > 0 ? (cityTotals.get(incidentType) ?? 0) / neighbourhoodCount : 0,
    }))
    .sort((a, b) => (a.count === b.count ? (a.incidentType < b.incidentType ? -1 : 1) : b.count - a.count));
}

function breakdownsByYear(
  byYear: Map<number, Map<string, number>>,
  cityByYear: Map<number, Map<string, number>>,
  neighbourhoodCount: number,
): Record<number, IncidentBreakdown[]> {
  const result: Record<number, IncidentBreakdown[]> = {};
  for (const [year, counts] of byYear) {
    result[year] = incidentBreakdowns(counts, cityByYear.get(year) ?? new Map(), neighbourhoodCount);
  }
  return result;
}

export async function fetchPoliceCrime(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<PoliceCrimeSummary | undefined> {
  if (!neighbourhood) return undefined;

  const dataset = WINNIPEG_DATASETS.policeCrimeMaps;
  const url = `https://www.arcgis.com/sharing/rest/content/items/${dataset}/data`;

  // Primary determining fetch — hits ArcGIS directly, not CDS. Let transport/
  // HTTP errors throw so the orchestrator marks the module failed ("Database
  // error"); a successful-but-empty file degrades to undefined below.
  const response = await fetch(url, { signal: init?.signal });
  if (!response.ok) {
    throw new Error(`ArcGIS crime CSV HTTP ${response.status}`);
  }
  const csv = await response.text();
  const agg = parseCSV(csv);

  const slice = agg.slices.get(sliceKey(neighbourhood)) ?? emptySlice();
  const neighbourhoodCount = agg.slices.size;

  const yearlyCounts: PoliceCrimeYear[] = [...agg.yearlyCityTotals.keys()]
    .sort((a, b) => a - b)
    .map((year) => ({
      year,
      neighbourhood: slice.yearly.get(year) ?? 0,
      citywideAverage: neighbourhoodCount > 0 ? (agg.yearlyCityTotals.get(year) ?? 0) / neighbourhoodCount : 0,
    }));

  const crimeTypes = incidentBreakdowns(slice.crimeTypes, agg.cityCrimeTypes, neighbourhoodCount);
  const offenceTypes = incidentBreakdowns(slice.offenceTypes, agg.cityOffenceTypes, neighbourhoodCount);

  const summary: PoliceCrimeSummary = {
    neighbourhood,
    latestMonth: agg.latestMonth,
    yearlyCounts,
    crimeTypes,
    crimeTypesByYear: breakdownsByYear(slice.crimeTypesByYear, agg.cityCrimeTypesByYear, neighbourhoodCount),
    offenceTypes,
    offenceTypesByYear: breakdownsByYear(slice.offenceTypesByYear, agg.cityOffenceTypesByYear, neighbourhoodCount),
  };

  if (summary.yearlyCounts.length === 0 && summary.crimeTypes.length === 0 && summary.offenceTypes.length === 0) {
    return undefined;
  }
  return summary;
}
