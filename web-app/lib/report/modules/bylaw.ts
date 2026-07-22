// By-Law investigations module — neighbourhood complaint activity by year and
// top complaint types. Ports fetchBylaw (and its fetchNeighbourhoodID helper)
// from WinnipegProvider. Complaints are keyed by the neighbourhood's numeric id,
// so we resolve that id first, then aggregate on the by-law dataset.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, rowInt, rowString } from "../row";
import { BylawInvestigationSummary, IncidentBreakdown, YearCount } from "../types";
import { yearOffset } from "../util";

/** Resolve a neighbourhood's numeric id from its name (gating fetch). */
async function fetchNeighbourhoodID(
  neighbourhood: string,
  init?: { signal?: AbortSignal },
): Promise<string | undefined> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.neighbourhoods,
    {
      select: "id,name",
      where: `upper(name)='${escaped(neighbourhood.toUpperCase())}'`,
      limit: 1,
    },
    init,
  );
  return rows.length ? rowString(rows[0], "id") : undefined;
}

export async function fetchBylaw(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<BylawInvestigationSummary | undefined> {
  if (!neighbourhood) return undefined;

  // Primary determining fetch — a transport/HTTP failure here throws so the
  // orchestrator marks the module failed; a successful empty lookup is "no data".
  const neighbourhoodID = await fetchNeighbourhoodID(neighbourhood, init);
  if (!neighbourhoodID) return undefined;

  const [yearlyRows, typeRows] = await Promise.all([
    fetchDataset(
      WINNIPEG_DATASETS.bylawInvestigations,
      {
        select: "date_extract_y(indate) as year, count(*) as cnt",
        where: `nbhd_number='${escaped(neighbourhoodID)}' AND indate >= '${yearOffset(-6)}-01-01T00:00:00'`,
        group: "year",
        order: "year",
      },
      init,
    ).catch(() => []),
    fetchDataset(
      WINNIPEG_DATASETS.bylawInvestigations,
      {
        select: "complaint_type_1, count(*) as cnt",
        where: `nbhd_number='${escaped(neighbourhoodID)}' AND indate >= '${yearOffset(-1)}-01-01T00:00:00' AND complaint_type_1 IS NOT NULL`,
        group: "complaint_type_1",
        order: "cnt DESC",
        limit: 6,
      },
      init,
    ).catch(() => []),
  ]);

  const yearly: YearCount[] = yearlyRows
    .map((row) => {
      const year = rowInt(row, "year");
      const count = rowInt(row, "cnt");
      if (year == null || count == null) return null;
      return { year, count, citywideAverage: 0 } satisfies YearCount;
    })
    .filter((x): x is YearCount => x != null);

  const complaintTypes: IncidentBreakdown[] = typeRows
    .map((row) => {
      const type = rowString(row, "complaint_type_1");
      const count = rowInt(row, "cnt");
      if (!type || count == null) return null;
      return { incidentType: type, count, citywideAverage: 0 } satisfies IncidentBreakdown;
    })
    .filter((x): x is IncidentBreakdown => x != null);

  if (yearly.length === 0 && complaintTypes.length === 0) return undefined;
  return { neighbourhood, yearly, complaintTypes };
}
