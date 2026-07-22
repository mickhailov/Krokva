// Facility closures module — health-protection closure reports whose
// name_and_address string matches the address's street core. Port of
// fetchFacilityClosures from WinnipegProvider.

import { NormalizedAddress, streetCore } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, rowString } from "../row";
import { FacilityClosureRecord, FacilityClosureSummary, PropertyAssessment } from "../types";
import { parseDate, plainText } from "../util";

export async function fetchFacilityClosures(
  address: NormalizedAddress,
  _property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<FacilityClosureSummary | undefined> {
  const core = escaped(streetCore(address.streetName));
  if (core.length < 3) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.facilityClosures,
    {
      where: `upper(name_and_address) like '%${core}%'`,
      order: "closure_date DESC",
      limit: 10,
    },
    init,
  );

  const closures: FacilityClosureRecord[] = rows.flatMap((row) => {
    const name = rowString(row, "name_and_address");
    if (!name) return [];
    return [
      {
        name: plainText(name) ?? name,
        establishmentType: rowString(row, "type_of_establishment"),
        reason: plainText(rowString(row, "reasons_for_closure")),
        closureDate: parseDate(rowString(row, "closure_date")),
        reopenDate: parseDate(rowString(row, "re_open_date")),
      },
    ];
  });

  if (closures.length === 0) return undefined;
  return { closures };
}
