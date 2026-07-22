// Amenities & street — Pools & amenities card. Nearest indoor/outdoor/wading/
// spray-pad pool, nearby walkway count, and nearest public Wi-Fi site.
// Mirrors the "Pools & amenities" section of the iOS civic-amenities card.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { AddressReport } from "@/lib/report/types";

export function AquaticsCard({ report }: { report: AddressReport }) {
  const aquatics = report.aquatics;
  const failed = report.failedModules.includes("aquatics");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Aquatics" title="Pools & amenities">
        <ErrorState />
      </KrokvaCard>
    );
  }

  if (!aquatics) return null;
  const { pools, walkwaysNearby, nearestWifi } = aquatics;
  const hasAny = pools.length > 0 || walkwaysNearby > 0 || nearestWifi != null;
  if (!hasAny) return null;

  return (
    <KrokvaCard
      eyebrow="Amenities · Aquatics"
      title="Pools & amenities"
      subtitle="Within 500 m"
      accent={pools.length ? `${pools.length}` : undefined}
      collapsible
      collapsedSummary={
        pools.length
          ? `${pools.length} pool${pools.length === 1 ? "" : "s"} within 500 m`
          : "Walkways & Wi-Fi nearby"
      }
    >
      {pools.length ? (
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {pools.map((pool, i) => (
            <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                <strong style={{ fontSize: 14 }}>{pool.name}</strong>
                {pool.distanceDescription ? (
                  <span className="card__subtitle">{pool.distanceDescription}</span>
                ) : null}
              </div>
              <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
                <span className="pill">{pool.kind}</span>
                {pool.isOpen ? <span className="pill">Open</span> : null}
              </div>
              {pool.features.length ? (
                <div className="card__subtitle">{pool.features.join(" · ")}</div>
              ) : null}
              {pool.address ? <div className="card__subtitle">{pool.address}</div> : null}
            </div>
          ))}
        </div>
      ) : null}

      {walkwaysNearby > 0 ? (
        <Fact label="Walkways nearby" value={walkwaysNearby} />
      ) : null}
      {nearestWifi ? (
        <Fact
          label="Public Wi-Fi"
          value={[nearestWifi.name, nearestWifi.distanceDescription].filter(Boolean).join(" · ")}
        />
      ) : null}
    </KrokvaCard>
  );
}
