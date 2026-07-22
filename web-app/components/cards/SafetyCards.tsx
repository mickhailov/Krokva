// Safety & health cards — WFPS emergency calls (more modules append here:
// public health, police crime, neighbourhood risk).

import { EmptyState, ErrorState, KrokvaCard } from "../KrokvaCard";
import { ColumnTrend, DeltaBadge, HBars, Sparkline, StatRow, StatTile } from "../viz/Viz";
import { titleCase } from "@/lib/format";
import { EmergencySummary } from "@/lib/report/types";

const MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export function EmergencyCard({
  emergency,
  failed,
}: {
  emergency?: EmergencySummary;
  failed: boolean;
}) {
  if (failed) {
    return (
      <KrokvaCard eyebrow="Safety · WFPS" title="Emergency calls">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!emergency || emergency.totalLastYear === 0) return null;
  const top = emergency.last12Months.slice(0, 6);
  const years = emergency.yearlyCalls.slice(-6);
  const months = emergency.monthlyTrend.slice(-12);
  const median = emergency.citywideMedian;
  const status =
    median != null && median > 0
      ? emergency.totalLastYear > median * 1.05
        ? ({ tone: "bad", label: "Above city median" } as const)
        : emergency.totalLastYear < median * 0.95
          ? ({ tone: "good", label: "Below city median" } as const)
          : ({ tone: "warn", label: "Around city median" } as const)
      : undefined;
  return (
    <KrokvaCard
      eyebrow="Safety · WFPS"
      title="Emergency calls"
      subtitle={`${emergency.neighbourhood} · last 12 months`}
      accent={`${emergency.totalLastYear}`}
      status={status}
    >
      <StatRow>
        <StatTile label="Calls · 12 mo" value={emergency.totalLastYear} />
        <StatTile
          label="Motor-vehicle"
          value={emergency.motorVehicleLastYear || undefined}
        />
        <StatTile
          label="Avg duration"
          value={
            emergency.averageDurationMinutes != null
              ? `${Math.round(emergency.averageDurationMinutes)} min`
              : undefined
          }
        />
        <StatTile
          label="Rank in city"
          value={
            emergency.neighbourhoodRank != null && emergency.neighbourhoodCount != null
              ? `${emergency.neighbourhoodRank} / ${emergency.neighbourhoodCount}`
              : undefined
          }
          sub="1 = most calls"
        />
      </StatRow>

      {emergency.citywideMedian != null ? (
        <div style={{ marginTop: 10 }}>
          <DeltaBadge
            value={emergency.totalLastYear}
            baseline={emergency.citywideMedian}
            baselineLabel={`city median (${Math.round(emergency.citywideMedian)})`}
          />
        </div>
      ) : null}

      {years.length > 1 ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">Calls by year</span>
          <div style={{ marginTop: 8 }}>
            <ColumnTrend
              items={years.map((y) => ({
                label: `${y.year}`,
                value: y.count,
                context: y.citywideAverage,
              }))}
              contextLabel="city-wide neighbourhood average"
            />
          </div>
        </div>
      ) : null}

      {months.length > 2 ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">Monthly trend</span>
          <div style={{ marginTop: 6 }}>
            <Sparkline
              points={months.map((m) => ({
                label: `${MONTH_SHORT[(m.month - 1 + 12) % 12]} ${m.year}`,
                value: m.count,
              }))}
            />
          </div>
        </div>
      ) : null}

      {top.length ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">Top call types</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={top.map((t) => ({
                label: titleCase(t.incidentType) ?? t.incidentType,
                value: t.count,
                context: t.citywideAverage > 0 ? t.citywideAverage : undefined,
              }))}
            />
          </div>
        </div>
      ) : (
        <EmptyState />
      )}
    </KrokvaCard>
  );
}
