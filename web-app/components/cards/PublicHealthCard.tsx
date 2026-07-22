// Public health card — naloxone/opioid overdose response and substance use for
// this neighbourhood (vs. citywide average), plus ER/walk-in access and the
// nearest public AED. Port of the app's public-health section.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { ColumnTrend, HBars } from "../viz/Viz";
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
  const years = health.yearlyEvents.slice(-6);
  const topSubstances = health.substances.slice(0, 6);
  const aed = health.nearestAED;
  const er = health.nearestER;

  const hasAny =
    latest != null ||
    topSubstances.length > 0 ||
    aed != null ||
    er != null ||
    (health.aedsNearby ?? 0) > 0;
  if (!hasAny) return null;

  const status =
    latest != null && latest.citywideAverage > 0
      ? latest.neighbourhood > latest.citywideAverage * 1.05
        ? ({ tone: "bad", label: "Above city average" } as const)
        : latest.neighbourhood < latest.citywideAverage * 0.95
          ? ({ tone: "good", label: "Below city average" } as const)
          : ({ tone: "warn", label: "Around city average" } as const)
      : undefined;

  return (
    <KrokvaCard
      eyebrow="Safety · Public health"
      title="Overdose response & health access"
      subtitle="Naloxone administrations & substance use vs. citywide average"
      accent={latest ? `${latest.neighbourhood}` : undefined}
      status={status}
    >
      {years.length > 1 ? (
        <div>
          <span className="eyebrow">Overdose responses by year</span>
          <div style={{ marginTop: 8 }}>
            <ColumnTrend
              items={years.map((y) => ({
                label: `${y.year}`,
                value: y.neighbourhood,
                context: y.citywideAverage > 0 ? y.citywideAverage : undefined,
              }))}
              contextLabel="city-wide neighbourhood average"
            />
          </div>
        </div>
      ) : latest ? (
        <>
          <Fact label={`Overdose responses (${latest.year})`} value={latest.neighbourhood} />
          <Fact
            label="Citywide average per neighbourhood"
            value={latest.citywideAverage > 0 ? Math.round(latest.citywideAverage) : undefined}
          />
        </>
      ) : null}

      {topSubstances.length ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">Substances involved</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={topSubstances.map((s) => ({
                label: titleCase(s.incidentType) ?? s.incidentType,
                value: s.count,
                context: s.citywideAverage > 0 ? s.citywideAverage : undefined,
              }))}
            />
          </div>
        </div>
      ) : null}

      {er ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">Nearest emergency room</span>
          <div style={{ marginTop: 8 }}>
            <Fact label={er.name} value={er.driveMinutes != null ? `${Math.round(er.driveMinutes)} min drive` : undefined} />
            <Fact
              label="Current ER wait"
              value={er.currentWaitMinutes != null ? `${Math.round(er.currentWaitMinutes)} min` : undefined}
            />
            <Fact
              label="Average ER wait"
              value={er.avgWaitMinutes != null ? `${Math.round(er.avgWaitMinutes)} min` : undefined}
            />
            <Fact label="Patients waiting" value={er.waitingPatients ?? undefined} />
          </div>
        </div>
      ) : null}

      {health.nearestWalkIn ? (
        <Fact
          label="Nearest walk-in clinic"
          value={`${health.nearestWalkIn.name}${
            health.nearestWalkIn.driveMinutes != null
              ? ` · ${Math.round(health.nearestWalkIn.driveMinutes)} min drive`
              : ""
          }`}
        />
      ) : null}

      {aed ? (
        <div style={{ marginTop: 14 }}>
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

      {!latest && !topSubstances.length && !aed && !er ? <EmptyState /> : null}
    </KrokvaCard>
  );
}
