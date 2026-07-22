// Permits module — nearby street-core resolution + building permits, vacant
// building orders, and neighbourhood permit activity. Ports fetchNearbyStreetCores,
// fetchPermits, fetchVacantOrders, fetchPermitActivity from WinnipegProvider.

import { NormalizedAddress, streetCore, streetVariants } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, parseCoordinate, rowInt, rowString } from "../row";
import { PropertyAssessment, BuildingPermit, VacantOrder, YearCount } from "../types";
import { distanceMeters, isAdjacent, limitedStreetCores, parseDate, yearOffset } from "../util";

const NEARBY_RADIUS_METERS = 500;

/** Street cores within the radius, seeded from the address's own variants. */
export async function fetchNearbyStreetCores(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<string[]> {
  const cores = new Set(streetVariants(address).map(streetCore).filter((c) => c.length > 0));
  const subject = property?.coordinate;
  if (!subject) return [...cores].sort();

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.assessment,
    {
      select: "street_name,centroid_lat,centroid_lon,geometry",
      where: `neighbourhood_area='${escaped(property!.neighbourhood)}' AND street_name IS NOT NULL`,
      limit: 2000,
    },
    init,
  ).catch(() => []);

  for (const row of rows) {
    const street = rowString(row, "street_name");
    const coord = parseCoordinate(row);
    if (!street || !coord) continue;
    if (distanceMeters(coord, subject) <= NEARBY_RADIUS_METERS) {
      const core = streetCore(street);
      if (core.length) cores.add(core);
    }
  }
  return [...cores].sort();
}

export async function fetchPermits(
  address: NormalizedAddress,
  streetCores: string[],
  init?: { signal?: AbortSignal },
): Promise<BuildingPermit[]> {
  const nearby = limitedStreetCores(streetCores);
  const streetClauses = nearby.map((c) => `upper(street_name)='${escaped(c)}'`).join(" OR ");
  if (!streetClauses) return [];
  const where = `(${streetClauses}) AND issue_date > '${yearOffset(-2)}-01-01T00:00:00'`;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.permits,
    { where, order: "issue_date DESC", limit: 50 },
    init,
  ).catch(() => []);

  return rows.map((row) => {
    const permitAddress = rowString(row, "address") ?? "";
    const workType = (rowString(row, "work_type") ?? "").toLowerCase();
    const structural = ["foundation", "structural"].some((k) => workType.includes(k));
    return {
      issuedDate: parseDate(rowString(row, "issue_date")),
      type: rowString(row, "permit_type") ?? "Permit",
      subType: rowString(row, "sub_type"),
      workType: rowString(row, "work_type"),
      address: permitAddress,
      status: rowString(row, "status"),
      isAdjacentStructural: structural && isAdjacent(permitAddress, address.civicNumber),
      coordinate: parseCoordinate(row),
    } satisfies BuildingPermit;
  });
}

export async function fetchPermitActivity(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<YearCount[]> {
  if (!neighbourhood) return [];
  const n = escaped(neighbourhood.toUpperCase());
  const neighClause = `(upper(neighbourhood_name)='${n}' OR upper(neighbourhood)='${n}' OR upper(neighborhood_name)='${n}')`;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.permits,
    {
      select: "date_extract_y(issue_date) as year, count(*) as cnt",
      where: `${neighClause} AND issue_date >= '${yearOffset(-6)}-01-01T00:00:00'`,
      group: "year",
      order: "year",
    },
    init,
  ).catch(() => []);
  return rows
    .map((row) => {
      const year = rowInt(row, "year");
      const count = rowInt(row, "cnt");
      if (year == null || count == null) return null;
      return { year, count, citywideAverage: 0 } satisfies YearCount;
    })
    .filter((x): x is YearCount => x != null);
}

export async function fetchVacantOrders(
  streetCores: string[],
  init?: { signal?: AbortSignal },
): Promise<VacantOrder[]> {
  const nearby = limitedStreetCores(streetCores);
  const streetClauses = nearby.map((c) => `upper(address) like '%${escaped(c)}%'`).join(" OR ");
  if (!streetClauses) return [];
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.vacantOrders,
    { where: `(${streetClauses})`, order: "order_issued_date DESC", limit: 40 },
    init,
  ).catch(() => []);
  return rows.map((row) => ({
    issuedDate: parseDate(rowString(row, "order_issued_date")),
    address: rowString(row, "address") ?? "Address unavailable",
    orderType: rowString(row, "order_type") ?? "Compliance order",
    distanceDescription: undefined,
    coordinate: parseCoordinate(row),
  }));
}
