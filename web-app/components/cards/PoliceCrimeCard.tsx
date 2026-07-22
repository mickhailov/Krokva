// Police crime card — WPS reported crime for the neighbourhood, with the
// latest year's counts set against the city-wide per-neighbourhood average.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
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

  return (
    <KrokvaCard
      eyebrow="Safety · WPS crime"
      title="Reported crime"
      subtitle={`${crime.neighbourhood}${crime.latestMonth ? ` · to ${monthLabel(crime.latestMonth.year, crime.latestMonth.month)}` : ""}`}
      accent={latestYear ? `${latestYear.neighbourhood}` : undefined}
    >
      {latestYear ? (
        <>
          <Fact label={`Incidents (${latestYear.year})`} value={latestYear.neighbourhood} />
          <Fact
            label="City-wide neighbourhood avg"
            value={Math.round(latestYear.citywideAverage)}
          />
        </>
      ) : null}

      {crime.yearlyCounts.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Yearly totals</span>
          <div style={{ marginTop: 8 }}>
            {crime.yearlyCounts.map((y) => (
              <div className="kv" key={y.year}>
                <span className="kv__key">{y.year}</span>
                <span className="kv__val">
                  {y.neighbourhood}
                  <span className="card__subtitle" style={{ marginLeft: 8 }}>
                    avg {Math.round(y.citywideAverage)}
                  </span>
                </span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {topCrimeTypes.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Top crime types</span>
          <div style={{ marginTop: 8 }}>
            {topCrimeTypes.map((t) => (
              <div className="kv" key={t.incidentType}>
                <span className="kv__key">{titleCase(t.incidentType)}</span>
                <span className="kv__val">{t.count}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {topOffenceTypes.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Top offences</span>
          <div style={{ marginTop: 8 }}>
            {topOffenceTypes.map((t) => (
              <div className="kv" key={t.incidentType}>
                <span className="kv__key">{titleCase(t.incidentType)}</span>
                <span className="kv__val">{t.count}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
