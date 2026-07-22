// Permits & development cards — recent building permits, vacant-building orders,
// neighbourhood permit activity, and the street infrastructure summary.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import {
  BuildingPermit,
  InfrastructureSummary,
  VacantOrder,
  YearCount,
} from "@/lib/report/types";

export function PermitsCard({ permits, failed }: { permits: BuildingPermit[]; failed: boolean }) {
  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · Building" title="Recent building permits">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (permits.length === 0) return null;
  return (
    <KrokvaCard
      eyebrow="Permits · Building"
      title="Recent building permits"
      subtitle="On this street, last 2 years"
      accent={`${permits.length}`}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {permits.slice(0, 12).map((p, i) => (
          <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong style={{ fontSize: 14 }}>{titleCase(p.type)}</strong>
              <span className="card__subtitle">{shortDate(p.issuedDate)}</span>
            </div>
            <div className="card__subtitle">{p.address}</div>
            {p.workType ? <div className="card__subtitle">{titleCase(p.workType)}</div> : null}
            {p.isAdjacentStructural ? <span className="pill">Adjacent structural</span> : null}
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}

export function VacantOrdersCard({ orders, failed }: { orders: VacantOrder[]; failed: boolean }) {
  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · Vacant buildings" title="Vacant-building orders">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (orders.length === 0) return null;
  return (
    <KrokvaCard
      eyebrow="Permits · Vacant buildings"
      title="Vacant-building orders"
      subtitle="Nearby compliance orders"
      accent={`${orders.length}`}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {orders.slice(0, 10).map((o, i) => (
          <div key={i} className="kv">
            <span className="kv__key">{o.address}</span>
            <span className="kv__val">{titleCase(o.orderType)}</span>
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}

export function PermitActivityCard({ activity }: { activity: YearCount[] }) {
  if (activity.length === 0) return null;
  const max = Math.max(...activity.map((a) => a.count), 1);
  return (
    <KrokvaCard
      eyebrow="Permits · Activity"
      title="Neighbourhood permit activity"
      subtitle="Building permits issued per year"
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {activity.map((a) => (
          <div key={a.year} style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span className="mono" style={{ width: 44, color: "var(--ink3)", fontSize: 13 }}>
              {a.year}
            </span>
            <div style={{ flex: 1, height: 10, background: "var(--surface-alt)", borderRadius: 5 }}>
              <div
                style={{
                  width: `${(a.count / max) * 100}%`,
                  height: "100%",
                  background: "var(--gold)",
                  borderRadius: 5,
                }}
              />
            </div>
            <span className="mono" style={{ width: 40, textAlign: "right", fontSize: 13 }}>
              {a.count}
            </span>
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}

export function InfrastructureCard({
  infrastructure,
  failed,
}: {
  infrastructure?: InfrastructureSummary;
  failed: boolean;
}) {
  if (failed) {
    return (
      <KrokvaCard eyebrow="Street · Infrastructure" title="Street infrastructure">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!infrastructure) return null;
  const hasAny =
    infrastructure.speedLimit != null ||
    infrastructure.potholes > 0 ||
    infrastructure.publicTrees > 0;
  return (
    <KrokvaCard eyebrow="Street · Infrastructure" title="Street infrastructure">
      {hasAny ? (
        <>
          <Fact label="Speed limit" value={infrastructure.speedLimit} />
          <Fact label="Pothole repairs (on street)" value={infrastructure.potholes || undefined} />
          <Fact label="Public trees (on street)" value={infrastructure.publicTrees || undefined} />
          <Fact label="Tagged trees" value={infrastructure.taggedTrees || undefined} />
          <Fact label="Top tree species" value={titleCase(infrastructure.topTreeSpecies)} />
        </>
      ) : (
        <EmptyState />
      )}
    </KrokvaCard>
  );
}
