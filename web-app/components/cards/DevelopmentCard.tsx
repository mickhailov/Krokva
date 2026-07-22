// Development card — recent development permits on nearby streets. Citywide
// review-pace / intake-outcome charts were dropped: they speak to developers,
// not to someone deciding whether to buy this house.

import { ErrorState, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport, DevelopmentPermit } from "@/lib/report/types";

/** Collapse permits that repeat the same address + type + date (the nearby
 *  feed occasionally returns a record more than once). */
function dedupePermits(permits: DevelopmentPermit[]): DevelopmentPermit[] {
  const seen = new Set<string>();
  const out: DevelopmentPermit[] = [];
  for (const p of permits) {
    const key = `${p.address}|${p.type}|${p.subType ?? ""}|${p.issuedDate ?? ""}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(p);
  }
  return out;
}

export function DevelopmentCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("development");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · Development" title="Development permits">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const development = report.development;
  if (!development) return null;

  const recentPermits = dedupePermits(development.recentPermits);
  if (recentPermits.length === 0) return null;

  return (
    <KrokvaCard
      eyebrow="Permits · Development"
      title="Development permits"
      subtitle="Recent development applications nearby"
      accent={recentPermits.length ? `${recentPermits.length}` : undefined}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {recentPermits.slice(0, 6).map((p, i) => (
          <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong style={{ fontSize: 14 }}>{titleCase(p.type)}</strong>
              <span className="card__subtitle">{shortDate(p.issuedDate)}</span>
            </div>
            <div className="card__subtitle">{p.address}</div>
            {p.subType ? <div className="card__subtitle">{titleCase(p.subType)}</div> : null}
            {p.workType ? <div className="card__subtitle">{titleCase(p.workType)}</div> : null}
            {p.status ? <span className="pill">{titleCase(p.status)}</span> : null}
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}
