// Facility closures card — health-protection closure reports for establishments
// whose address matches this street.

import { ErrorState, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function FacilityClosuresCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("facilityClosures");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Health protection" title="Facility closures">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const closures = report.facilityClosures?.closures ?? [];
  if (closures.length === 0) return null;

  return (
    <KrokvaCard
      eyebrow="Amenities · Health protection"
      title="Facility closures"
      subtitle="Health-protection closure reports on this street"
      accent={`${closures.length}`}
      collapsible
      collapsedSummary={`${closures.length} closure report${closures.length === 1 ? "" : "s"} on this street`}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {closures.map((c, i) => (
          <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong style={{ fontSize: 14 }}>{c.name}</strong>
              {c.closureDate ? (
                <span className="card__subtitle">{shortDate(c.closureDate)}</span>
              ) : null}
            </div>
            {c.establishmentType ? (
              <div className="card__subtitle">{titleCase(c.establishmentType)}</div>
            ) : null}
            {c.reason ? <div className="card__subtitle">{c.reason}</div> : null}
            {c.reopenDate ? (
              <div className="card__subtitle">Reopened {shortDate(c.reopenDate)}</div>
            ) : null}
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}
