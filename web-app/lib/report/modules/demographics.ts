// Demographics module — "Who lives here": census age/income/household/commute/
// language/immigration for the address's census boundary, plus a higher-poverty
// flag. Ports fetchDemographics (both overloads), censusBoundaryCandidates,
// censusBoundaryClause, fetchTopNonOfficialLanguage, and fetchPovertyInfo from
// WinnipegProvider. Census joins on boundary_name; poverty is point-in-polygon.

import { NormalizedAddress, streetCore, streetVariants } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, SocrataRow, soql } from "../../socrata";
import { Coordinate, escaped, rowDouble, rowInt, rowString } from "../row";
import { DemographicsSummary, IncidentBreakdown, PropertyAssessment } from "../types";

interface CensusBoundaryCandidate {
  boundaryType: string;
  names: string[];
  displayName: string;
}

/**
 * Row from the Addresses dataset carrying ward / neighbourhood. Used only to seed
 * extra census-boundary candidates, so — like the Swift `try?` — a failure here
 * degrades to fewer candidates rather than failing the module.
 */
async function fetchCivicAddressRow(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<SocrataRow | undefined> {
  const select = "full_address,ward,neighbourhood,school_division,school_division_ward";
  let rows: SocrataRow[] = [];

  const fullAddress = property?.fullAddress;
  if (fullAddress && fullAddress.length > 0) {
    rows = await fetchDataset(
      WINNIPEG_DATASETS.addresses,
      { select, where: `upper(full_address)='${escaped(fullAddress.toUpperCase())}'`, limit: 1 },
      init,
    ).catch(() => []);
  }

  if (rows.length === 0 && address.civicNumber != null) {
    const streetTokens = new Set(streetVariants(address).map((v) => v.toUpperCase()));
    const core = streetCore(address.streetName);
    if (core.length > 0) streetTokens.add(core);
    const streetClauses = [...streetTokens]
      .map((token) => `upper(street_name)='${escaped(token)}'`)
      .join(" OR ");
    if (streetClauses.length > 0) {
      rows = await fetchDataset(
        WINNIPEG_DATASETS.addresses,
        { select, where: `street_number='${address.civicNumber}' AND (${streetClauses})`, limit: 1 },
        init,
      ).catch(() => []);
    }
  }

  return rows[0];
}

/** Capitalize each whitespace-separated word (Swift `String.capitalized`). */
function capitalized(value: string): string {
  return value.replace(/\S+/g, (w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());
}

function censusBoundaryCandidates(
  property: PropertyAssessment | undefined,
  civicRow: SocrataRow | undefined,
): CensusBoundaryCandidate[] {
  const candidates: CensusBoundaryCandidate[] = [];
  const seen = new Set<string>();

  function append(boundaryType: string, names: string[], displayName: string): void {
    const normalizedNames = names.map((n) => n.trim()).filter((n) => n.length > 0);
    if (normalizedNames.length === 0) return;
    const key = `${boundaryType}|${normalizedNames.join("|")}`.toUpperCase();
    if (seen.has(key)) return;
    seen.add(key);
    candidates.push({ boundaryType, names: normalizedNames, displayName });
  }

  const propNeighbourhood = property?.neighbourhood;
  if (propNeighbourhood && propNeighbourhood.length > 0) {
    append("Neighbourhood", [propNeighbourhood], capitalized(propNeighbourhood));
  }
  const civicNeighbourhood = rowString(civicRow ?? {}, "neighbourhood");
  if (civicNeighbourhood && civicNeighbourhood.length > 0) {
    append("Neighbourhood", [civicNeighbourhood], capitalized(civicNeighbourhood));
  }
  const ward = rowString(civicRow ?? {}, "ward");
  if (ward && ward.length > 0) {
    append("Ward", [ward, `${ward} Ward`], `${ward} Ward`);
  }
  append("City", ["City of Winnipeg"], "City of Winnipeg");
  return candidates;
}

function censusBoundaryClause(candidate: CensusBoundaryCandidate): string {
  const names = candidate.names
    .map((n) => `upper(boundary_name)='${escaped(n.toUpperCase())}'`)
    .join(" OR ");
  return `boundary_type='${escaped(candidate.boundaryType)}' AND (${names})`;
}

/** Top non-official language for a boundary (enrichment — degrades to undefined). */
async function fetchTopNonOfficialLanguage(
  clause: string,
  init?: { signal?: AbortSignal },
): Promise<string | undefined> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.censusLanguage,
    { where: clause, order: "census_year DESC", limit: 1 },
    init,
  ).catch(() => []);
  const row = rows[0];
  if (!row) return undefined;

  let best: { name: string; count: number } | undefined;
  for (const [key, value] of Object.entries(row)) {
    if (!key.startsWith("language2_") || key === "language2_total") continue;
    const count =
      typeof value === "string"
        ? parseInt(value, 10) || 0
        : typeof value === "number"
          ? Math.trunc(value)
          : 0;
    if (count > (best?.count ?? 0)) {
      const name = capitalized(key.replace("language2_", "").replace(/_/g, " "));
      best = { name, count };
    }
  }
  return best?.name;
}

/** Higher-poverty flag + Gini index at the coordinate (enrichment — degrades). */
async function fetchPovertyInfo(
  coordinate: Coordinate | undefined,
  init?: { signal?: AbortSignal },
): Promise<{ high?: boolean; gini?: number } | undefined> {
  if (!coordinate) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.higherPovertyAreas,
    {
      select: "is_high_poverty_area,gini_index",
      where: soql.intersectsPoint("location", coordinate.longitude, coordinate.latitude),
      limit: 1,
    },
    init,
  ).catch(() => []);
  const row = rows[0];
  if (!row) return undefined;
  const rawHigh = row["is_high_poverty_area"];
  let high: boolean | undefined;
  if (typeof rawHigh === "boolean") high = rawHigh;
  else if (typeof rawHigh === "string") high = /^(true|yes|1)$/i.test(rawHigh.trim());
  return { high, gini: rowDouble(row, "gini_index") };
}

async function fetchForCandidate(
  candidate: CensusBoundaryCandidate,
  coordinate: Coordinate | undefined,
  init?: { signal?: AbortSignal },
): Promise<DemographicsSummary | undefined> {
  const nClause = censusBoundaryClause(candidate);

  // Age is the PRIMARY determining fetch: a transport/HTTP error here throws and
  // marks the module failed; an empty result just means this candidate has no
  // census data, so the caller advances to the next candidate. Everything else is
  // enrichment and degrades via .catch.
  const [ageRows, householdRows, transportRows, immigrationRows, topLanguage, povertyInfo] =
    await Promise.all([
      fetchDataset(WINNIPEG_DATASETS.censusAge, { where: nClause, limit: 1 }, init),
      fetchDataset(
        WINNIPEG_DATASETS.censusHouseholds,
        {
          select: "income_median,size_average_person,census_year",
          where: nClause,
          order: "census_year DESC",
          limit: 1,
        },
        init,
      ).catch(() => []),
      fetchDataset(
        WINNIPEG_DATASETS.censusTransportMode,
        {
          select: "car_total,passenger_total,public_total,walk_total,bicycle_total,census_year",
          where: nClause,
          order: "census_year DESC",
          limit: 1,
        },
        init,
      ).catch(() => []),
      fetchDataset(
        WINNIPEG_DATASETS.censusImmigration,
        {
          select: "born_total_immigrants,generation_total_population",
          where: nClause,
          limit: 1,
        },
        init,
      ).catch(() => []),
      fetchTopNonOfficialLanguage(nClause, init),
      fetchPovertyInfo(coordinate, init),
    ]);

  const age = ageRows[0];
  const household = householdRows[0];
  const transport = transportRows[0];
  const immigration = immigrationRows[0];

  let children: number | undefined;
  let seniors: number | undefined;
  let population: number | undefined;
  if (age) {
    const total = rowDouble(age, "age_total");
    population = rowInt(age, "age_total");
    const kids = ["age_0_4_total", "age_5_9_total", "age_10_14_total"]
      .map((k) => rowDouble(age, k))
      .filter((v): v is number => v != null)
      .reduce((a, b) => a + b, 0);
    const old = ["age_65_69_total", "age_70_74_total", "age_75_79_total", "age_80_84_total", "age_85_total"]
      .map((k) => rowDouble(age, k))
      .filter((v): v is number => v != null)
      .reduce((a, b) => a + b, 0);
    if (total != null && total > 0) {
      children = (kids / total) * 100;
      seniors = (old / total) * 100;
    }
  }

  let commuteModes: IncidentBreakdown[] = [];
  if (transport) {
    const pairs: [string, string][] = [
      ["Drive", "car_total"],
      ["Carpool", "passenger_total"],
      ["Transit", "public_total"],
      ["Walk", "walk_total"],
      ["Bicycle", "bicycle_total"],
    ];
    commuteModes = pairs.flatMap(([label, key]) => {
      const count = rowInt(transport, key);
      if (count == null || count <= 0) return [];
      return [{ incidentType: label, count, citywideAverage: 0 }];
    });
  }

  let immigrantPercent: number | undefined;
  if (immigration) {
    const immigrants = rowDouble(immigration, "born_total_immigrants");
    const base = rowDouble(immigration, "generation_total_population");
    if (immigrants != null && base != null && base > 0) {
      immigrantPercent = (immigrants / base) * 100;
    }
  }

  const medianHouseholdIncome = household ? rowDouble(household, "income_median") : undefined;
  const averageHouseholdSize = household ? rowDouble(household, "size_average_person") : undefined;

  const hasData =
    population != null ||
    medianHouseholdIncome != null ||
    commuteModes.length > 0 ||
    immigrantPercent != null ||
    topLanguage != null ||
    povertyInfo != null;
  if (!hasData) return undefined;

  return {
    boundaryName: candidate.displayName,
    totalPopulation: population,
    childrenPercent: children,
    seniorsPercent: seniors,
    medianHouseholdIncome,
    averageHouseholdSize,
    immigrantPercent,
    topNonOfficialLanguage: topLanguage,
    commuteModes,
    isHighPovertyArea: povertyInfo?.high,
    giniIndex: povertyInfo?.gini,
  };
}

export async function fetchDemographics(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<DemographicsSummary | undefined> {
  if (property == null && address.civicNumber == null) return undefined;

  const civicRow = await fetchCivicAddressRow(address, property, init);
  const coordinate = property?.coordinate;
  for (const candidate of censusBoundaryCandidates(property, civicRow)) {
    const summary = await fetchForCandidate(candidate, coordinate, init);
    if (summary) return summary;
  }
  return undefined;
}
