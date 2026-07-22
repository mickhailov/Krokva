// Neighbourhood risk card — rooming-house enforcement, vacant-property fire
// trend, rush-hour towing, paid parking, and graffiti reports nearby.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { ColumnTrend, HBars } from "../viz/Viz";
import { AddressReport } from "@/lib/report/types";

export function NeighbourhoodRiskCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("neighbourhoodRisk");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Safety · Neighbourhood" title="Neighbourhood risk">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const risk = report.neighbourhoodRisk;
  if (!risk) return null;

  const rooming = risk.roomingHouse;
  const fires = risk.vacantFireTrend;
  const fireTotal = fires.reduce((sum, y) => sum + y.count, 0);

  return (
    <KrokvaCard
      eyebrow="Safety · Neighbourhood"
      title="Neighbourhood risk"
      subtitle="Enforcement, fires, towing & parking nearby"
    >
      <Fact
        label="Rush-hour tows (within 500 m)"
        value={risk.towingNearby || undefined}
      />
      <Fact
        label="Paid-parking zones nearby"
        value={risk.paidParkingNearby || undefined}
      />
      <Fact label="Nearest paid parking" value={risk.nearestPaidParking} />
      <Fact label="Graffiti reports" value={risk.graffitiReports || undefined} />

      {rooming ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Rooming-house enforcement · {rooming.year}</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={[
                { label: "Complaint-driven", value: rooming.complaintDriven ?? NaN },
                { label: "Proactive", value: rooming.proactive ?? NaN },
                { label: "In progress", value: rooming.inProgress ?? NaN },
                { label: "Completed", value: rooming.completed ?? NaN },
              ]}
            />
          </div>
        </div>
      ) : null}

      {fires.length ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">
            Vacant-property fires · citywide{fireTotal > 0 ? ` · ${fireTotal} over ${fires.length} yr` : ""}
          </span>
          <div style={{ marginTop: 8 }}>
            <ColumnTrend
              items={fires.map((y) => ({ label: `${y.year}`, value: y.count }))}
            />
          </div>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
