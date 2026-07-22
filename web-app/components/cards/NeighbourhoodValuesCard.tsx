// Neighbourhood values card — assessed-value distribution ($50k bins) for the
// address's neighbourhood. Reads report.neighbourhoodValues.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { AddressReport } from "@/lib/report/types";

export function NeighbourhoodValuesCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("neighbourhoodValues");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Property · Neighbourhood" title="Assessed value distribution">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const bins = report.neighbourhoodValues;
  if (!bins || bins.length === 0) return null;

  const total = bins.reduce((sum, bin) => sum + bin.count, 0);

  return (
    <KrokvaCard
      eyebrow="Property · Neighbourhood"
      title="Assessed value distribution"
      subtitle="Assessed values across this neighbourhood, in $50k bands"
      accent={`${total} properties`}
    >
      <Fact label="Properties assessed" value={total} />
      <div style={{ marginTop: 12 }}>
        <span className="eyebrow">By assessed value</span>
        <div style={{ marginTop: 8 }}>
          {bins.map((bin) => (
            <div className="kv" key={bin.midpoint}>
              <span className="kv__key">{bin.bucket}</span>
              <span className="kv__val">{bin.count}</span>
            </div>
          ))}
        </div>
      </div>
    </KrokvaCard>
  );
}
