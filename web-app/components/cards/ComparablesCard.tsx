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
  const subject = report.property?.totalAssessedValue;
  const subjectArea = report.property?.livingArea;
  const top = Math.max(...values, subject ?? 0);

  // Per-sq-ft normalises away size, so a small home doesn't look "cheap" just
  // for being small — the honest way to compare against bigger neighbours.
  const perSqftValues = comparables
    .filter((c) => c.livingArea > 0)
    .map((c) => c.value / c.livingArea);
  const avgPerSqft = perSqftValues.length
    ? perSqftValues.reduce((a, b) => a + b, 0) / perSqftValues.length
    : undefined;
  const subjectPerSqft =
    subject != null && subjectArea != null && subjectArea > 0 ? subject / subjectArea : undefined;

  return (
    <KrokvaCard
      eyebrow="Property · Comparables"
      title="Comparable properties"
      subtitle="Similar homes assessed in this neighbourhood"
      accent={`avg ${currency(average)}`}
    >
      {avgPerSqft != null ? (
        <div style={{ display: "flex", flexWrap: "wrap", gap: 16, marginBottom: 12 }}>
          {subjectPerSqft != null ? (
            <div>
              <div className="eyebrow">This home · $/sq ft</div>
              <div style={{ fontSize: 20, fontWeight: 650 }}>${Math.round(subjectPerSqft)}</div>
            </div>
          ) : null}
          <div>
            <div className="eyebrow">Neighbourhood avg · $/sq ft</div>
            <div style={{ fontSize: 20, fontWeight: 650 }}>${Math.round(avgPerSqft)}</div>
          </div>
        </div>
      ) : null}

      <p className="card__subtitle" style={{ marginBottom: 12 }}>
        These are the City&apos;s <strong>assessed values</strong> — used to set property tax,
        not asking prices. Market prices are usually higher and move faster. Compare on
        $/sq&nbsp;ft rather than the total, since these homes differ in size.
      </p>
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {comparables.slice(0, 12).map((c, i) => (
          <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong style={{ fontSize: 13.5 }}>{c.address}</strong>
              <span className="mono" style={{ fontSize: 13 }}>
                {currency(c.value)}
              </span>
            </div>
            <div
              className="hbar__track"
              style={{ marginTop: 6 }}
              title={
                subject != null
                  ? `${currency(c.value)} vs this property ${currency(subject)}`
                  : currency(c.value)
              }
            >
              <span className="hbar__fill" style={{ width: `${(c.value / top) * 100}%` }} />
              {subject != null ? (
                <span className="hbar__tick" style={{ left: `${Math.min((subject / top) * 100, 100)}%` }} />
              ) : null}
            </div>
            <div className="card__subtitle" style={{ marginTop: 4 }}>
              {[
                formatArea(c.livingArea),
                c.livingArea > 0 ? `$${Math.round(c.value / c.livingArea)}/sq ft` : undefined,
                c.yearBuilt != null ? `Built ${c.yearBuilt}` : undefined,
              ]
                .filter(Boolean)
                .join(" · ")}
            </div>
          </div>
        ))}
      </div>
      {subject != null ? (
        <div className="chart-legend">
          <span className="chart-legend__item">
            <span className="swatch swatch--tick" /> this property ({currency(subject)})
          </span>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
