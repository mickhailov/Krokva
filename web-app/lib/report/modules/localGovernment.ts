// Local government module — ward councillor + community committee for the
// address. Ports fetchLocalGovernment (coordinate + wardName overloads),
// mergeLocalGovernment, and the fetchCivicAddressRow helper it leans on for the
// ward-name fallback, from WinnipegProvider.

import { NormalizedAddress, streetCore, streetVariants } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql, SocrataRow } from "../../socrata";
import { Coordinate, escaped, rowString } from "../row";
import { LocalGovernmentSummary, PropertyAssessment } from "../types";

/**
 * Ward-by-coordinate lookup. The ward polygon fetch is the primary determining
 * fetch (it throws so the orchestrator can mark the module failed); the
 * committee fetch is enrichment and degrades to nothing on error.
 */
async function fetchByCoordinate(
  coordinate: Coordinate,
  init?: { signal?: AbortSignal },
): Promise<LocalGovernmentSummary | undefined> {
  const where = soql.intersectsPoint("the_geom", coordinate.longitude, coordinate.latitude);

  const [wardRows, committeeRows] = await Promise.all([
    fetchDataset(
      WINNIPEG_DATASETS.electoralWards,
      { select: "councillor,name,phone,website", where, limit: 1 },
      init,
    ),
    fetchDataset(
      WINNIPEG_DATASETS.communityCommittees,
      { select: "desc", where, limit: 1 },
      init,
    ).catch(() => [] as SocrataRow[]),
  ]);

  const ward = wardRows[0];
  const committee = committeeRows[0];
  if (!ward && !committee) return undefined;
  return {
    wardName: ward ? rowString(ward, "name") : undefined,
    councillor: ward ? rowString(ward, "councillor") : undefined,
    councillorPhone: ward ? rowString(ward, "phone") : undefined,
    councillorWebsite: ward ? rowString(ward, "website") : undefined,
    communityCommittee: committee ? rowString(committee, "desc") : undefined,
  };
}

/** Ward-by-name fallback (used when the coordinate lookup is thin). */
async function fetchByWardName(
  wardName: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<LocalGovernmentSummary | undefined> {
  const trimmed = wardName?.trim();
  if (!trimmed) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.electoralWards,
    {
      select: "councillor,name,phone,website",
      where: `upper(name)='${escaped(trimmed.toUpperCase())}'`,
      limit: 1,
    },
    init,
  );
  const ward = rows[0];
  if (!ward) return undefined;
  return {
    wardName: rowString(ward, "name"),
    councillor: rowString(ward, "councillor"),
    councillorPhone: rowString(ward, "phone"),
    councillorWebsite: rowString(ward, "website"),
  };
}

/**
 * Civic-address row lookup (WinnipegProvider.fetchCivicAddressRow). Enrichment
 * only here — it supplies the ward name for the fallback — so it degrades to
 * undefined on error.
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
    ).catch(() => [] as SocrataRow[]);
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
      ).catch(() => [] as SocrataRow[]);
    }
  }

  return rows[0];
}

function merge(
  primary: LocalGovernmentSummary | undefined,
  fallback: LocalGovernmentSummary | undefined,
): LocalGovernmentSummary | undefined {
  if (!primary && !fallback) return undefined;
  return {
    wardName: primary?.wardName ?? fallback?.wardName,
    councillor: primary?.councillor ?? fallback?.councillor,
    councillorPhone: primary?.councillorPhone ?? fallback?.councillorPhone,
    councillorWebsite: primary?.councillorWebsite ?? fallback?.councillorWebsite,
    communityCommittee: primary?.communityCommittee ?? fallback?.communityCommittee,
  };
}

export async function fetchLocalGovernment(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<LocalGovernmentSummary | undefined> {
  const coordinate = property?.coordinate;

  let coordinateSummary: LocalGovernmentSummary | undefined;
  if (coordinate) {
    coordinateSummary = await fetchByCoordinate(coordinate, init);
    if (coordinateSummary?.wardName != null && coordinateSummary?.councillor != null) {
      return coordinateSummary;
    }
  }

  const civicRow = await fetchCivicAddressRow(address, property, init);
  const wardSummary = await fetchByWardName(civicRow ? rowString(civicRow, "ward") : undefined, init);
  return merge(coordinateSummary, wardSummary);
}
