// Police crime card — WPS reported crime for the neighbourhood as a yearly
// column trend against the city-wide per-neighbourhood average, plus top
// crime/offence breakdowns as bars.

import { ErrorState, KrokvaCard } from "../KrokvaCard";
import { ColumnTrend, DeltaBadge, HBars } from "../viz/Viz";
import { titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

function monthLabel(year: number, month: number): string {
  const name = month >= 1 && month <= 12 ? MONTHS[month - 1] : `${month}`;
  return `${name} ${year}`;
}

export function PoliceCrimeCard({ report }: { report: AddressReport }) {
  const crime = report.policeCrime;
  const failed = report.failedModules.includes("policeCrime");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Safety · WPS crime" title="Reported crime">
        <ErrorState />
      </KrokvaCard>
    );
  }

  if (
    !crime ||
    (crime.yearlyCounts.length === 0 && crime.crimeTypes.length === 0 && crime.offenceTypes.length === 0)
  ) {
    return null;
  }

  const latestYear = crime.yearlyCounts.length ? crime.yearlyCounts[crime.yearlyCounts.length - 1] : undefined;
  const topCrimeTypes = crime.crimeTypes.slice(0, 6);
  const topOffenceTypes = crime.offenceTypes.slice(0, 6);
  const cityAvg = latestYear?.citywideAverage;
  const status =
    latestYear && cityAvg != null && cityAvg > 0
      ? latestYear.neighbourhood > cityAvg * 1.05
        ? ({ tone: "bad", label: "Above city average" } as const)
        : latestYear.neighbourhood < cityAvg * 0.95
          ? ({ tone: "good", label: "Below city average" } as const)
          : ({ tone: "warn", label: "Around city average" } as const)
      : undefined;

  return (
    <KrokvaCard
      eyebrow="Safety · WPS crime"
      title="Reported crime"
      subtitle={`${crime.neighbourhood}${crime.latestMonth ? ` · to ${monthLabel(crime.latestMonth.year, crime.latestMonth.month)}` : ""}`}
      accent={latestYear ? `${latestYear.neighbourhood} in ${latestYear.year}` : undefined}
      status={status}
    >
      {latestYear ? (
        <div style={{ marginBottom: 10 }}>
          <DeltaBadge
            value={latestYear.neighbourhood}
            baseline={latestYear.citywideAverage}
            baselineLabel={`city avg (${Math.round(latestYear.citywideAverage)} per neighbourhood)`}
          />
        </div>
      ) : null}

      {crime.yearlyCounts.length ? (
        <ColumnTrend
          items={crime.yearlyCounts.map((y) => ({
            label: `${y.year}`,
            value: y.neighbourhood,
            context: y.citywideAverage,
          }))}
          contextLabel="city-wide neighbourhood average"
        />
      ) : null}

      {topCrimeTypes.length ? (
        <div style={{ marginTop: 16 }}>
          <span className="eyebrow">Top crime types</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={topCrimeTypes.map((t) => ({
                label: titleCase(t.incidentType) ?? t.incidentType,
                value: t.count,
              }))}
            />
          </div>
        </div>
      ) : null}

      {topOffenceTypes.length ? (
        <div style={{ marginTop: 16 }}>
          <span className="eyebrow">Top offences</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={topOffenceTypes.map((t) => ({
                label: titleCase(t.incidentType) ?? t.incidentType,
                value: t.count,
              }))}
            />
          </div>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
