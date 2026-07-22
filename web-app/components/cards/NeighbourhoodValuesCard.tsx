// Neighbourhood values card — assessed-value distribution ($50k bins) for the
// address's neighbourhood, with this property's band highlighted.

import { ErrorState, KrokvaCard } from "../KrokvaCard";
import { HBars } from "../viz/Viz";
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
  const subjectValue = report.property?.totalAssessedValue;
  // Highlight the band this property falls into ($50k bins around the midpoint).
  const subjectBin =
    subjectValue != null
      ? bins.reduce(
          (best, bin) =>
            Math.abs(bin.midpoint - subjectValue) < Math.abs((best?.midpoint ?? Infinity) - subjectValue)
              ? bin
              : best,
          undefined as (typeof bins)[number] | undefined
        )
      : undefined;

  return (
    <KrokvaCard
      eyebrow="Property · Neighbourhood"
      title="Assessed value distribution"
      subtitle="Assessed values across this neighbourhood, in $50k bands"
      accent={`${total} properties`}
    >
      <HBars
        items={bins.map((bin) => ({
          label: bin.bucket,
          value: bin.count,
          emphasis: subjectBin ? bin.midpoint === subjectBin.midpoint : true,
        }))}
      />
      {subjectBin ? (
        <div className="chart-legend">
          <span className="chart-legend__item">
            <span className="swatch swatch--bar" /> this property&apos;s band ({subjectBin.bucket})
          </span>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
