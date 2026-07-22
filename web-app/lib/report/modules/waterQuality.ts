// Water quality module — pulls the latest year's drinking-water test results
// from the CDS water-quality dataset and de-dupes to one reading per parameter
// (max 8). Port of WinnipegProvider.fetchWaterQuality.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { rowDouble, rowInt, rowString } from "../row";
import { WaterQualityReading, WaterQualitySummary } from "../types";

export async function fetchWaterQuality(init?: {
  signal?: AbortSignal;
}): Promise<WaterQualitySummary | undefined> {
  const dataset = WINNIPEG_DATASETS.waterQuality;

  // Primary determining fetch — latest reporting year. Let it throw so the
  // orchestrator can distinguish a data-source failure from an empty result.
  const yearRows = await fetchDataset(dataset, { select: "max(year) as y" }, init);
  const latestYear = yearRows.length ? rowInt(yearRows[0], "y") : undefined;
  if (latestYear == null) return undefined;

  const rows = await fetchDataset(
    dataset,
    {
      select: "area,parameter,units,average,minimum,maximum",
      where: `year=${latestYear} AND average IS NOT NULL`,
      limit: 60,
    },
    init,
  );
  if (rows.length === 0) return undefined;

  const seen = new Set<string>();
  const readings: WaterQualityReading[] = [];
  let area: string | undefined;
  for (const row of rows) {
    const parameter = rowString(row, "parameter");
    if (!parameter || seen.has(parameter)) continue;
    seen.add(parameter);
    if (area == null) area = rowString(row, "area");
    readings.push({
      parameter,
      average: rowDouble(row, "average"),
      minimum: rowDouble(row, "minimum"),
      maximum: rowDouble(row, "maximum"),
      units: rowString(row, "units"),
    });
    if (readings.length >= 8) break;
  }
  if (readings.length === 0) return undefined;

  return { year: latestYear, area, parameters: readings };
}
