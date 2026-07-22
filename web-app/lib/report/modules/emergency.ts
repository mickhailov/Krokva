// Emergency (WFPS) module — pulls the indexed neighbourhood slice once and
// aggregates locally (Socrata-side grouping on this dataset times out). Port of
// fetchEmergency / fetchEmergencyCitywideYearRows / emergencyUnitBreakdown.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { rowInt, rowString } from "../row";
import { EmergencyIncidentRecord, EmergencySummary, IncidentBreakdown, YearCount } from "../types";
import { parseDate, properCaseNeighbourhood, yearOffset } from "../util";

/** Year/month from a naive Socrata timestamp's wall-clock (no timezone shift). */
function ymOf(raw?: string): { year: number; month: number } | undefined {
  if (!raw) return undefined;
  const m = /^(\d{4})-(\d{2})/.exec(raw);
  if (!m) return undefined;
  return { year: parseInt(m[1], 10), month: parseInt(m[2], 10) };
}

function durationMinutes(callRaw?: string, closedRaw?: string): number | undefined {
  if (!callRaw || !closedRaw) return undefined;
  const a = Date.parse(callRaw);
  const b = Date.parse(closedRaw);
  if (Number.isNaN(a) || Number.isNaN(b)) return undefined;
  return Math.max(Math.trunc((b - a) / 60000), 0);
}

function unitCategory(unit: string): string {
  if (/^\d+$/.test(unit)) return "Ambulance";
  if (unit.startsWith("E")) return "Engine / pumper";
  if (unit.startsWith("L")) return "Ladder";
  if (unit.startsWith("R")) return "Rescue";
  if (unit.startsWith("SQ")) return "Squad";
  if (unit.startsWith("DC") || unit === "D" || unit.startsWith("P")) return "Command";
  if (unit.startsWith("EPIC") || unit.startsWith("MIRV") || unit.startsWith("PACE") || unit.startsWith("PTRS"))
    return "Medical specialty";
  if (unit.startsWith("HM")) return "Hazmat";
  if (unit.startsWith("W")) return "Water rescue";
  return "Specialty / other";
}

function unitBreakdown(incidents: { units?: string }[]): IncidentBreakdown[] {
  const counts = new Map<string, number>();
  for (const inc of incidents) {
    if (!inc.units) continue;
    for (const raw of inc.units.split(/[,;/ ]+/)) {
      const unit = raw.trim().toUpperCase();
      if (!unit) continue;
      const cat = unitCategory(unit);
      counts.set(cat, (counts.get(cat) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([incidentType, count]) => ({ incidentType, count, citywideAverage: 0 }))
    .sort((a, b) => b.count - a.count);
}

function topBreakdown(counts: Map<string, number>, limit?: number): IncidentBreakdown[] {
  const arr = [...counts.entries()]
    .map(([incidentType, count]) => ({ incidentType, count, citywideAverage: 0 }))
    .sort((a, b) => b.count - a.count);
  return limit != null ? arr.slice(0, limit) : arr;
}

export async function fetchEmergency(
  neighbourhood: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<EmergencySummary | undefined> {
  if (!neighbourhood) return undefined;
  const neighName = properCaseNeighbourhood(neighbourhood).replace(/'/g, "''");
  const timeField = "call_time";
  const sixYearClause = `neighbourhood='${neighName}' AND ${timeField} >= '${yearOffset(-6)}-01-01T00:00:00'`;
  const lastYearStart = yearOffset(-1);
  const twoYearStart = yearOffset(-2);

  const [rows, citywideYearRows] = await Promise.all([
    fetchDataset(
      WINNIPEG_DATASETS.emergencyCalls,
      {
        select: "incident_number,incident_type,call_time,closed_time,motor_vehicle_incident,units,ward",
        where: sixYearClause,
        order: `${timeField} DESC`,
        limit: 50000,
      },
      init,
    ),
    fetchDataset(
      WINNIPEG_DATASETS.emergencyCalls,
      {
        select: `date_extract_y(${timeField}) as year, neighbourhood, count(*) as cnt`,
        where: `${timeField} >= '${yearOffset(-6)}-01-01T00:00:00' AND neighbourhood IS NOT NULL`,
        group: "year, neighbourhood",
        order: "year",
        limit: 50000,
      },
      init,
    ).catch(() => []),
  ]);

  const incidents: (EmergencyIncidentRecord & { callRaw?: string })[] = rows.flatMap((row) => {
    const type = rowString(row, "incident_type");
    if (!type) return [];
    const callRaw = rowString(row, "call_time");
    return [
      {
        incidentNumber: rowString(row, "incident_number"),
        incidentType: type,
        callTime: parseDate(callRaw),
        closedTime: parseDate(rowString(row, "closed_time")),
        motorVehicleIncident: rowString(row, "motor_vehicle_incident"),
        units: rowString(row, "units"),
        ward: rowString(row, "ward"),
        callRaw,
      },
    ];
  });

  const yearlyCounts = new Map<number, number>();
  const monthlyCounts = new Map<string, { year: number; month: number; count: number }>();
  const typeCounts = new Map<string, number>();
  const typeCountsByYear = new Map<number, Map<string, number>>();
  const wardCounts = new Map<string, number>();
  const motorVehicleCounts = new Map<string, number>();

  for (const inc of incidents) {
    const ym = ymOf(inc.callRaw);
    if (!ym) continue;
    const { year, month } = ym;
    yearlyCounts.set(year, (yearlyCounts.get(year) ?? 0) + 1);
    if (!typeCountsByYear.has(year)) typeCountsByYear.set(year, new Map());
    const ty = typeCountsByYear.get(year)!;
    ty.set(inc.incidentType, (ty.get(inc.incidentType) ?? 0) + 1);

    if (year >= twoYearStart) {
      const key = `${year}-${month}`;
      const cur = monthlyCounts.get(key) ?? { year, month, count: 0 };
      cur.count += 1;
      monthlyCounts.set(key, cur);
    }
    if (year < lastYearStart) continue;
    typeCounts.set(inc.incidentType, (typeCounts.get(inc.incidentType) ?? 0) + 1);
    if (inc.ward) wardCounts.set(inc.ward, (wardCounts.get(inc.ward) ?? 0) + 1);
    if (inc.motorVehicleIncident)
      motorVehicleCounts.set(inc.motorVehicleIncident, (motorVehicleCounts.get(inc.motorVehicleIncident) ?? 0) + 1);
  }

  const citywideCountsByYear = new Map<number, number[]>();
  for (const row of citywideYearRows) {
    const year = rowInt(row, "year");
    const count = rowInt(row, "cnt");
    if (year == null || count == null) continue;
    if (!citywideCountsByYear.has(year)) citywideCountsByYear.set(year, []);
    citywideCountsByYear.get(year)!.push(count);
  }

  const recentIncidents = incidents.slice(0, 8).map(({ callRaw, ...rest }) => rest);
  const durations = incidents
    .map((i) => durationMinutes(i.callRaw, i.closedTime))
    .filter((d): d is number => d != null && d > 0 && d < 24 * 60);
  const averageDuration = durations.length ? durations.reduce((a, b) => a + b, 0) / durations.length : undefined;
  const totalLastYear = [...typeCounts.values()].reduce((a, b) => a + b, 0);
  const motorVehicleLastYear = [...motorVehicleCounts.entries()]
    .filter(([k]) => /yes/i.test(k))
    .reduce((a, [, v]) => a + v, 0);

  const yearlyCalls: YearCount[] = [...yearlyCounts.entries()]
    .map(([year, count]) => {
      const city = citywideCountsByYear.get(year) ?? [];
      const citywideAverage = city.length ? city.reduce((a, b) => a + b, 0) / city.length : 0;
      return { year, count, citywideAverage };
    })
    .sort((a, b) => a.year - b.year);

  const breakdownByYear: Record<number, IncidentBreakdown[]> = {};
  for (const [year, counts] of typeCountsByYear) breakdownByYear[year] = topBreakdown(counts);

  return {
    neighbourhood,
    totalLastYear,
    motorVehicleLastYear,
    averageDurationMinutes: averageDuration,
    yearlyCalls,
    monthlyTrend: [...monthlyCounts.values()].sort((a, b) =>
      a.year === b.year ? a.month - b.month : a.year - b.year,
    ),
    last12Months: topBreakdown(typeCounts, 12),
    breakdownByYear,
    wardBreakdown: topBreakdown(wardCounts, 8),
    motorVehicleBreakdown: topBreakdown(motorVehicleCounts),
    unitBreakdown: unitBreakdown(recentIncidents),
    recentIncidents,
    citywideMedian: undefined,
    neighbourhoodRank: undefined,
    neighbourhoodCount: undefined,
  };
}
