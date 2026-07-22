// Neighbourhood values module — assessment-value histogram for the address's
// neighbourhood, bucketed into $50k bins. Port of fetchNeighbourhoodValues.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, rowDouble, rowInt } from "../row";
import { AssessmentValueBin } from "../types";
import { currency } from "../../format";

export async function fetchNeighbourhoodValues(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<AssessmentValueBin[]> {
  if (!neighbourhood) return [];

  // The app's original SoQL used `floor(total_assessed_value / 50000) * 50000`.
  // The CDS facade's SoQL parser rejects the `/` operator (400) and stores
  // total_assessed_value as text, so arithmetic bucketing yields null buckets.
  // We use multiplication + to_number (the CDS-accepted equivalent) and compute
  // the midpoint in JS. When the backend can't bucket (older facade), the query
  // returns null buckets and we degrade to an empty histogram — a completeness
  // gap, not an error — so this module never surfaces a "Database error".
  const select = "floor(to_number(total_assessed_value) * 0.00002) as bucket_index, count(*) as cnt";
  let rows;
  try {
    rows = await fetchDataset(
      WINNIPEG_DATASETS.assessment,
      {
        select,
        where: `neighbourhood_area='${escaped(neighbourhood)}' AND total_assessed_value IS NOT NULL`,
        group: "bucket_index",
        order: "bucket_index",
        limit: 24,
      },
      init,
    );
  } catch {
    return [];
  }

  return rows.flatMap((row) => {
    const bucketIndex = rowDouble(row, "bucket_index");
    const count = rowInt(row, "cnt");
    if (bucketIndex == null || count == null) return [];
    const midpoint = bucketIndex * 50000 + 25000;
    return [
      {
        bucket: currency(midpoint) ?? `${midpoint}`,
        count,
        midpoint,
      } satisfies AssessmentValueBin,
    ];
  });
}
