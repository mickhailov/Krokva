// Short-term rentals module — licensed STR accommodations on nearby street cores,
// split into primary / non-primary residence licences. Ports
// fetchShortTermRentals from WinnipegProvider.

import { NormalizedAddress } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, rowString } from "../row";
import { ShortTermRentalRecord, ShortTermRentalSummary } from "../types";
import { limitedStreetCores, parseDate } from "../util";

export async function fetchShortTermRentals(
  address: NormalizedAddress,
  cores: string[],
  init?: { signal?: AbortSignal },
): Promise<ShortTermRentalSummary | undefined> {
  const dataset = WINNIPEG_DATASETS.shortTermRentals;
  if (!dataset) return undefined;

  const nearby = limitedStreetCores(cores, 8);
  const streetClauses = nearby
    .map((c) => `upper(short_term_rental_accommodation_address) like '%${escaped(c)}%'`)
    .join(" OR ");
  if (!streetClauses) return undefined;

  // Primary determining fetch — let it throw so the module is marked failed.
  const rows = await fetchDataset(
    dataset,
    {
      select:
        "primary_non_primary,short_term_rental_accommodation_address,date_licence_was_issued,electoral_ward",
      where: `(${streetClauses})`,
      order: "date_licence_was_issued DESC",
      limit: 100,
    },
    init,
  );
  if (rows.length === 0) return undefined;

  const records: ShortTermRentalRecord[] = rows.map((row) => ({
    address: rowString(row, "short_term_rental_accommodation_address") ?? "Address unavailable",
    primaryStatus: rowString(row, "primary_non_primary"),
    issuedDate: parseDate(rowString(row, "date_licence_was_issued")),
    ward: rowString(row, "electoral_ward"),
  }));

  const nonPrimaryCount = records.filter((r) =>
    (r.primaryStatus ?? "").toLowerCase().includes("non"),
  ).length;
  const primaryCount = records.filter((r) => {
    const status = (r.primaryStatus ?? "").toLowerCase();
    return status.includes("primary") && !status.includes("non");
  }).length;

  return {
    total: records.length,
    primaryCount,
    nonPrimaryCount,
    recent: records.slice(0, 8),
  };
}
