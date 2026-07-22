// Permits & development cards — recent building permits, vacant-building orders,
// neighbourhood permit activity, and the street infrastructure summary.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { ColumnTrend } from "../viz/Viz";
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
  // Work on or next to this property matters far more to a buyer than a sign
  // permit three blocks away — float adjacent structural permits to the top.
  const ordered = [...permits].sort(
    (a, b) => Number(b.isAdjacentStructural) - Number(a.isAdjacentStructural),
  );
  const adjacentCount = permits.filter((p) => p.isAdjacentStructural).length;
  return (
    <KrokvaCard
      eyebrow="Permits · Building"
      title="Recent building permits"
      subtitle="On this street, last 2 years"
      accent={`${permits.length}`}
      status={
        adjacentCount > 0
          ? ({ tone: "warn", label: `${adjacentCount} on/next to this lot` } as const)
          : undefined
      }
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {ordered.slice(0, 12).map((p, i) => (
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
  const status =
    orders.length >= 2
      ? ({ tone: "bad", label: `${orders.length} nearby` } as const)
      : ({ tone: "warn", label: "1 nearby" } as const);
  return (
    <KrokvaCard
      eyebrow="Permits · Vacant buildings"
      title="Vacant-building orders"
      subtitle="Nearby compliance orders"
      accent={`${orders.length}`}
      status={status}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {orders.slice(0, 10).map((o, i) => (
          <div key={i} className="kv">
            <span className="kv__key">{o.address}</span>
            <span className="kv__val">
              {titleCase(o.orderType)}
              {o.issuedDate ? (
                <span className="card__subtitle" style={{ marginLeft: 6 }}>
                  {shortDate(o.issuedDate)}
                </span>
              ) : null}
            </span>
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}

export function PermitActivityCard({ activity }: { activity: YearCount[] }) {
  if (activity.length === 0) return null;
  return (
    <KrokvaCard
      eyebrow="Permits · Activity"
      title="Neighbourhood permit activity"
      subtitle="Building permits issued per year"
    >
      <ColumnTrend
        items={activity.map((a) => ({
          label: `${a.year}`,
          value: a.count,
          context: a.citywideAverage > 0 ? a.citywideAverage : undefined,
        }))}
        contextLabel="city-wide neighbourhood average"
      />
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
  const summary = [
    infrastructure.speedLimit ? `${infrastructure.speedLimit} limit` : undefined,
    infrastructure.publicTrees > 0 ? `${infrastructure.publicTrees} public trees` : undefined,
  ]
    .filter(Boolean)
    .join(" · ");
  return (
    <KrokvaCard
      eyebrow="Street · Infrastructure"
      title="Street infrastructure"
      collapsible
      collapsedSummary={summary || "Street details"}
    >
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
