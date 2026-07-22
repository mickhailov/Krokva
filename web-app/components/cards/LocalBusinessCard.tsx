// Daily living — licensed local businesses within 500 m + seasonal patios.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { HBars } from "../viz/Viz";
import { titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function LocalBusinessCard({ report }: { report: AddressReport }) {
  const business = report.localBusiness;
  const failed = report.failedModules.includes("localBusiness");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Daily · Local business" title="Local businesses">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!business || (business.recent.length === 0 && business.patios.length === 0)) return null;

  const categories = business.topCategories.slice(0, 6);
  return (
    <KrokvaCard
      eyebrow="Daily · Local business"
      title="Local businesses"
      subtitle="Licensed within 500 m"
      accent={business.totalNearby ? `${business.totalNearby}` : undefined}
    >
      {business.totalNearby ? (
        <Fact label="Licensed businesses nearby" value={business.totalNearby} />
      ) : (
        <p className="card__subtitle">No licensed businesses within 500 m.</p>
      )}

      {categories.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Top categories</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={categories.map((c) => ({
                label: titleCase(c.incidentType) ?? c.incidentType,
                value: c.count,
              }))}
            />
          </div>
        </div>
      ) : null}

      {business.recent.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Closest</span>
          <div style={{ marginTop: 8, display: "flex", flexDirection: "column", gap: 8 }}>
            {business.recent.map((r, i) => (
              <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <strong style={{ fontSize: 14 }}>{r.name}</strong>
                  {r.distanceDescription ? (
                    <span className="card__subtitle">{r.distanceDescription}</span>
                  ) : null}
                </div>
                {r.category ? <div className="card__subtitle">{r.category}</div> : null}
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {business.patios.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Seasonal patios</span>
          <div style={{ marginTop: 8, display: "flex", flexDirection: "column", gap: 8 }}>
            {business.patios.map((p, i) => (
              <div key={i} className="kv">
                <span className="kv__key">{p.name}</span>
                <span className="kv__val">{p.distanceDescription}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
