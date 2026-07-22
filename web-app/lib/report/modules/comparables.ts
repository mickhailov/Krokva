// Comparables module — assessed-value peers in the same neighbourhood, filtered
// to a similar living-area band and year-built window. Port of fetchComparables
// from WinnipegProvider.

import { NormalizedAddress } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, rowDouble, rowInt, rowString } from "../row";
import { ComparableProperty, PropertyAssessment } from "../types";

export async function fetchComparables(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<ComparableProperty[]> {
  if (!property) return [];

  // The app filtered the living-area/year band server-side with `between`. The
  // CDS facade's SoQL parser rejects `between` and stores these fields as text
  // (numeric comparison also fails), so we fetch the neighbourhood's residential
  // rows once and apply the same ±20% living-area / ±10yr window in JS.
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.assessment,
    {
      where: `neighbourhood_area='${escaped(property.neighbourhood)}' AND total_living_area IS NOT NULL AND total_assessed_value IS NOT NULL`,
      limit: 600,
    },
    init,
  );

  const areaLo = property.livingArea != null ? property.livingArea * 0.8 : undefined;
  const areaHi = property.livingArea != null ? property.livingArea * 1.2 : undefined;
  const yearLo = property.yearBuilt != null ? property.yearBuilt - 10 : undefined;
  const yearHi = property.yearBuilt != null ? property.yearBuilt + 10 : undefined;

  const out: ComparableProperty[] = [];
  for (const row of rows) {
    const addr = rowString(row, "full_address");
    const value = rowDouble(row, "total_assessed_value");
    const area = rowDouble(row, "total_living_area");
    if (!addr || value == null || area == null) continue;
    if (areaLo != null && (area < areaLo || area > areaHi!)) continue;
    const yb = rowInt(row, "year_built");
    if (yearLo != null && (yb == null || yb < yearLo || yb > yearHi!)) continue;
    if (addr.toUpperCase() === property.fullAddress.toUpperCase()) continue; // exclude the subject
    out.push({ address: addr, value, livingArea: area, yearBuilt: yb });
    if (out.length >= 40) break;
  }
  return out;
}
