// Comparables card — assessed-value peers in the same neighbourhood with a
// similar living area and build year.

import { ErrorState, KrokvaCard } from "../KrokvaCard";
import { area as formatArea, currency } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function ComparablesCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("comparables");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Property · Comparables" title="Comparable properties">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const comparables = report.comparables;
  if (!comparables || comparables.length === 0) return null;

  const values = comparables.map((c) => c.value);
  const average = values.reduce((a, b) => a + b, 0) / values.length;

  return (
    <KrokvaCard
      eyebrow="Property · Comparables"
      title="Comparable properties"
      subtitle="Similar homes assessed in this neighbourhood"
      accent={currency(average)}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {comparables.slice(0, 12).map((c, i) => (
          <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong style={{ fontSize: 14 }}>{c.address}</strong>
              <span className="mono" style={{ fontSize: 14 }}>
                {currency(c.value)}
              </span>
            </div>
            <div className="card__subtitle">
              {[formatArea(c.livingArea), c.yearBuilt != null ? `Built ${c.yearBuilt}` : undefined]
                .filter(Boolean)
                .join(" · ")}
            </div>
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}
