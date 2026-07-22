// Public health card — naloxone/opioid overdose response and substance use for
// this neighbourhood (vs. citywide average), plus the nearest public AED. Port of
// the app's public-health section of the Safety & health module.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function PublicHealthCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("publicHealth");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Safety · Public health" title="Overdose response & health access">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const health = report.publicHealth;
  if (!health) return null;

  const latest = health.yearlyEvents.length
    ? health.yearlyEvents[health.yearlyEvents.length - 1]
    : undefined;
  const topSubstances = health.substances.slice(0, 6);
  const topAges = health.ageGroups.slice(0, 5);
  const aed = health.nearestAED;

  const hasAny =
    latest != null ||
    topSubstances.length > 0 ||
    topAges.length > 0 ||
    aed != null ||
    (health.aedsNearby ?? 0) > 0;
  if (!hasAny) return null;

  return (
    <KrokvaCard
      eyebrow="Safety · Public health"
      title="Overdose response & health access"
      subtitle="Naloxone administrations & substance use vs. citywide average"
      accent={latest ? `${latest.neighbourhood}` : undefined}
    >
      {latest ? (
        <>
          <Fact label={`Overdose responses (${latest.year})`} value={latest.neighbourhood} />
          <Fact
            label="Citywide average per neighbourhood"
            value={latest.citywideAverage > 0 ? Math.round(latest.citywideAverage) : undefined}
          />
        </>
      ) : null}

      {topSubstances.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Substances involved</span>
          <div style={{ marginTop: 8 }}>
            {topSubstances.map((s) => (
              <div className="kv" key={s.incidentType}>
                <span className="kv__key">{titleCase(s.incidentType)}</span>
                <span className="kv__val">
                  {s.count}
                  {s.citywideAverage > 0 ? (
                    <span className="card__subtitle" style={{ marginLeft: 6 }}>
                      city avg {Math.round(s.citywideAverage)}
                    </span>
                  ) : null}
                </span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {topAges.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Age groups</span>
          <div style={{ marginTop: 8 }}>
            {topAges.map((a) => (
              <div className="kv" key={a.incidentType}>
                <span className="kv__key">{titleCase(a.incidentType)}</span>
                <span className="kv__val">{a.count}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {aed ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Nearest public AED</span>
          <div style={{ marginTop: 8 }}>
            <Fact label={aed.name} value={aed.distanceDescription} />
            <Fact label="Location" value={aed.locationDescription} />
            <Fact label="Access" value={titleCase(aed.access)} />
            <Fact label="Indoor" value={aed.indoor === true ? "Yes" : aed.indoor === false ? "No" : undefined} />
            <Fact
              label="AEDs within 500 m"
              value={health.aedsNearby && health.aedsNearby > 0 ? health.aedsNearby : undefined}
            />
          </div>
        </div>
      ) : null}

      {!latest && !topSubstances.length && !topAges.length && !aed ? <EmptyState /> : null}
    </KrokvaCard>
  );
}
