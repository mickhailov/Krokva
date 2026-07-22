// Mosquito control (Insect Control) module — latest adult-nuisance trap counts
// for the address's city quadrant, with a fogging-threshold flag. Port of
// fetchMosquito from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { rowInt, rowString } from "../row";
import { MosquitoSummary, PropertyAssessment } from "../types";
import { parseDate } from "../util";

// Winnipeg's geographic quadrants split roughly at the city centre (Portage & Main).
const CENTRE_LAT = 49.8951;
const CENTRE_LON = -97.1384;

export async function fetchMosquito(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<MosquitoSummary | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.mosquitoTraps,
    {
      select:
        "count_date,city_wide_daily_average,north_west_average,north_east_average,south_east_average,south_west_average",
      order: "count_date DESC",
      limit: 1,
    },
    init,
  );

  const row = rows[0];
  if (!row) return undefined;

  // The trap dataset reports one average per quadrant, so we pick the matching one.
  const northSouth = subject.latitude >= CENTRE_LAT ? "north" : "south";
  const eastWest = subject.longitude >= CENTRE_LON ? "east" : "west";
  const quadrantKey = `${northSouth}_${eastWest}_average`;
  const quadrantName = `${capitalize(northSouth)} ${capitalize(eastWest)}`;

  const quadrantCount = rowInt(row, quadrantKey);
  const cityWide = rowInt(row, "city_wide_daily_average");
  if (quadrantCount == null && cityWide == null) return undefined;

  const peak = Math.max(quadrantCount ?? 0, cityWide ?? 0);
  return {
    quadrant: quadrantName,
    quadrantCount: quadrantCount ?? undefined,
    cityWideAverage: cityWide ?? undefined,
    countDate: parseDate(rowString(row, "count_date")),
    foggingThresholdReached: peak >= 100,
  };
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
