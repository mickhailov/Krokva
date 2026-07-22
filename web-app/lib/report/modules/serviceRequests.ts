// 311 service requests module — neighbourhood-scoped totals, status/channel/
// subject/reason/type breakdowns, monthly trend, and recent requests for the
// trailing year. Port of fetchServiceRequests / fetchServiceBreakdown /
// serviceNeighbourhoodClause from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, parseCoordinate, rowInt, rowString } from "../row";
import {
  IncidentBreakdown,
  ServiceRequestMonth,
  ServiceRequestRecord,
  ServiceRequestSummary,
} from "../types";
import { parseDate, properCaseNeighbourhood, yearOffset } from "../util";

/**
 * Index-friendly Title-Case neighbourhood match instead of upper() — the 311
 * dataset is large and the full-scan version risks the request timeout (mirrors
 * serviceNeighbourhoodClause).
 */
function serviceNeighbourhoodClause(neighbourhood: string): string {
  const trimmed = neighbourhood.trim();
  return `neighbourhood='${escaped(properCaseNeighbourhood(trimmed))}'`;
}

/** Grouped count breakdown on a single field (fetchServiceBreakdown). */
async function fetchServiceBreakdown(
  dataset: string,
  field: string,
  whereBase: string,
  limit: number,
  init?: { signal?: AbortSignal },
): Promise<IncidentBreakdown[]> {
  const rows = await fetchDataset(
    dataset,
    {
      select: `${field}, count(*) as cnt`,
      where: `${whereBase} AND ${field} IS NOT NULL`,
      group: field,
      order: "cnt DESC",
      limit,
    },
    init,
  ).catch(() => []);
  const out: IncidentBreakdown[] = [];
  for (const row of rows) {
    const value = rowString(row, field);
    const count = rowInt(row, "cnt");
    if (value == null || count == null) continue;
    out.push({ incidentType: value, count, citywideAverage: 0 });
  }
  return out;
}

export async function fetchServiceRequests(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<ServiceRequestSummary | undefined> {
  const dataset = WINNIPEG_DATASETS.serviceRequests;
  if (!neighbourhood) return undefined;

  const whereBase = `${serviceNeighbourhoodClause(neighbourhood)} AND open_date >= '${yearOffset(-1)}-01-01T00:00:00'`;

  // Primary determining fetch — let it throw so the orchestrator marks the
  // module failed on a transport/HTTP error (Database error vs No data).
  const totalsRaw = await fetchDataset(
    dataset,
    { select: "count(*) as total", where: whereBase },
    init,
  );

  // Auxiliary/enrichment fetches degrade to empty on error.
  const [
    openRows,
    closedRows,
    statuses,
    channels,
    subjects,
    reasons,
    types,
    trendRows,
    recentRows,
  ] = await Promise.all([
    fetchDataset(
      dataset,
      { select: "count(*) as open_count", where: `${whereBase} AND upper(case_status)='OPEN'` },
      init,
    ).catch(() => []),
    fetchDataset(
      dataset,
      { select: "count(*) as closed_count", where: `${whereBase} AND upper(case_status)='CLOSED'` },
      init,
    ).catch(() => []),
    fetchServiceBreakdown(dataset, "case_status", whereBase, 6, init),
    fetchServiceBreakdown(dataset, "channel_type", whereBase, 6, init),
    fetchDataset(
      dataset,
      {
        select: "subject, count(*) as cnt",
        where: `${whereBase} AND subject IS NOT NULL`,
        group: "subject",
        order: "cnt DESC",
        limit: 8,
      },
      init,
    ).catch(() => []),
    fetchServiceBreakdown(dataset, "reason", whereBase, 8, init),
    fetchServiceBreakdown(dataset, "type", whereBase, 8, init),
    fetchDataset(
      dataset,
      {
        select: "date_extract_y(open_date) as year, date_extract_m(open_date) as month, count(*) as cnt",
        where: whereBase,
        group: "year, month",
        order: "year, month",
        limit: 18,
      },
      init,
    ).catch(() => []),
    fetchDataset(
      dataset,
      {
        select:
          "case_id,interaction_id,channel_type,subject,reason,type,open_date,closed_date,case_status,ward,geometry",
        where: whereBase,
        order: "open_date DESC",
        limit: 12,
      },
      init,
    ).catch(() => []),
  ]);

  const total = rowInt(totalsRaw[0] ?? {}, "total") ?? 0;
  const open = rowInt(openRows[0] ?? {}, "open_count") ?? 0;
  const closed = rowInt(closedRows[0] ?? {}, "closed_count") ?? 0;

  const breakdown: IncidentBreakdown[] = [];
  for (const row of subjects) {
    const subject = rowString(row, "subject");
    const count = rowInt(row, "cnt");
    if (subject == null || count == null) continue;
    breakdown.push({ incidentType: subject, count, citywideAverage: 0 });
  }

  const trend: ServiceRequestMonth[] = [];
  for (const row of trendRows) {
    const year = rowInt(row, "year");
    const month = rowInt(row, "month");
    const count = rowInt(row, "cnt");
    if (year == null || month == null || count == null) continue;
    trend.push({ year, month, count });
  }

  const recent: ServiceRequestRecord[] = recentRows.map((row) => ({
    caseID: rowString(row, "case_id"),
    interactionID: rowString(row, "interaction_id"),
    channel: rowString(row, "channel_type"),
    subject: rowString(row, "subject"),
    reason: rowString(row, "reason"),
    type: rowString(row, "type"),
    openDate: parseDate(rowString(row, "open_date")),
    closedDate: parseDate(rowString(row, "closed_date")),
    status: rowString(row, "case_status"),
    ward: rowString(row, "ward"),
    coordinate: parseCoordinate(row),
  }));

  if (total === 0 && breakdown.length === 0 && recent.length === 0) return undefined;

  return {
    neighbourhood,
    totalLastYear: total,
    openLastYear: open,
    closedLastYear: closed,
    statusBreakdown: statuses,
    channelBreakdown: channels,
    topSubjects: breakdown,
    topReasons: reasons,
    topTypes: types,
    monthlyTrend: trend,
    recentRequests: recent,
  };
}
