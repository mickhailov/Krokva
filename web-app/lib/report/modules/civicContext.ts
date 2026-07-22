// Civic context module — ward, neighbourhood, and school division come from the
// Addresses dataset; postal code (snow-route address dataset) and plow zone
// (plow-zone polygons) are sourced separately since they are not columns there.
// Port of fetchCivicContext + fetchCivicAddressRow / fetchPostalCode /
// fetchPlowZone / fetchSchoolDivisionInfo from WinnipegProvider.

import { NormalizedAddress, streetCore, streetVariants } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, SocrataRow } from "../../socrata";
import { escaped, rowString } from "../row";
import { AddressCivicContext, PropertyAssessment } from "../types";

/**
 * Row from the Addresses dataset carrying ward / neighbourhood / school division.
 * This is the PRIMARY determining fetch — it is not wrapped in a catch, so a
 * transport/HTTP error propagates and the orchestrator marks the module failed.
 * A successful query that matches nothing resolves to undefined (No data).
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
      {
        select,
        where: `upper(full_address)='${escaped(fullAddress.toUpperCase())}'`,
        limit: 1,
      },
      init,
    );
  }

  if (rows.length === 0 && address.civicNumber != null) {
    // The Addresses dataset stores `street_name` WITHOUT the street type (e.g.
    // "ARNOLD", not "ARNOLD AVE"), so the assessment's full_address never matches
    // above. Match on the bare street core first, then fall back to the full
    // street-name variants for the rare dataset that keeps the type.
    const streetTokens = new Set(streetVariants(address).map((v) => v.toUpperCase()));
    const core = streetCore(address.streetName);
    if (core.length > 0) streetTokens.add(core);
    const streetClauses = [...streetTokens]
      .map((token) => `upper(street_name)='${escaped(token)}'`)
      .join(" OR ");
    if (streetClauses.length > 0) {
      rows = await fetchDataset(
        WINNIPEG_DATASETS.addresses,
        {
          select,
          where: `street_number='${address.civicNumber}' AND (${streetClauses})`,
          limit: 1,
        },
        init,
      );
    }
  }

  return rows[0];
}

/** Postal code from the snow-route address dataset (matched on the street core). */
async function fetchPostalCode(
  address: NormalizedAddress,
  init?: { signal?: AbortSignal },
): Promise<string | undefined> {
  if (address.civicNumber == null) return undefined;
  const token = escaped(streetCore(address.streetName));
  if (token.length === 0) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.snowRouteAddresses,
    {
      select: "postal_code",
      where: `address_number='${address.civicNumber}' AND upper(street_name)='${token}' AND postal_code IS NOT NULL`,
      limit: 1,
    },
    init,
  ).catch(() => []);
  return rowString(rows[0] ?? {}, "postal_code");
}

/** Plow zone (+ city area) from the plow-zone polygon dataset via point-in-polygon. */
async function fetchPlowZone(
  coordinate: { latitude: number; longitude: number } | undefined,
  init?: { signal?: AbortSignal },
): Promise<string | undefined> {
  if (!coordinate) return undefined;
  const point = `POINT (${coordinate.longitude} ${coordinate.latitude})`;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.plowZones,
    {
      select: "plow_zone,city_area",
      where: `intersects(the_geom,'${point}')`,
      limit: 1,
    },
    init,
  ).catch(() => []);
  const row = rows[0];
  const zone = row ? rowString(row, "plow_zone") : undefined;
  if (!zone) return undefined;
  const area = rowString(row, "city_area");
  return area && area.length > 0 ? `${zone} · ${area}` : zone;
}

interface SchoolDivisionBoundaryInfo {
  name?: string;
  code?: string;
  website?: string;
}

/** School-division boundary lookup (name/code/website) matched on the division name. */
async function fetchSchoolDivisionInfo(
  name: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<SchoolDivisionBoundaryInfo | undefined> {
  if (!name || name.trim().length === 0) return undefined;
  const token = escaped(name.toUpperCase());
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.schoolDivisions,
    {
      select: "name,division,website",
      where: `upper(name)='${token}' OR upper(division)='${token}'`,
      limit: 1,
    },
    init,
  ).catch(() => []);
  const row = rows[0];
  if (!row) return undefined;
  return {
    name: rowString(row, "name"),
    code: rowString(row, "division"),
    website: rowString(row, "website"),
  };
}

export async function fetchCivicContext(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<AddressCivicContext | undefined> {
  const [row, postalCode, plowZone] = await Promise.all([
    fetchCivicAddressRow(address, property, init),
    fetchPostalCode(address, init),
    fetchPlowZone(property?.coordinate, init),
  ]);

  if (!row && !postalCode && !plowZone) return undefined;

  const schoolDivision = row ? rowString(row, "school_division") : undefined;
  const divisionInfo = await fetchSchoolDivisionInfo(schoolDivision, init);

  return {
    addressID: row ? rowString(row, "address_id") : undefined,
    ward: row ? rowString(row, "ward") : undefined,
    neighbourhood: row ? rowString(row, "neighbourhood") : undefined,
    postalCode,
    plowZone,
    schoolDivision,
    schoolDivisionBoundaryName: divisionInfo?.name,
    schoolDivisionCode: divisionInfo?.code,
    schoolDivisionWard: row ? rowString(row, "school_division_ward") : undefined,
    schoolDivisionWebsite: divisionInfo?.website,
  } satisfies AddressCivicContext;
}
