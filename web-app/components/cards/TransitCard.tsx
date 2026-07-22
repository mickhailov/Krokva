// Amenities & street — transit access: nearest stop, routes, on-time
// performance, pass-ups, and estimated daily boardings.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { Meter } from "../viz/Viz";
import { AddressReport } from "@/lib/report/types";

export function TransitCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("transit");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Transit" title="Transit access">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const transit = report.transit;
  if (!transit) return null;

  const routes = transit.routes;
  const hasAny =
    transit.nearestStop != null ||
    routes.length > 0 ||
    transit.averageDeviationSeconds != null ||
    transit.onTimePercentage != null ||
    transit.passUpsLastYear > 0 ||
    transit.averageDailyBoardings != null;
  if (!hasAny) return null;

  return (
    <KrokvaCard
      eyebrow="Amenities · Transit"
      title="Transit access"
      subtitle="Stops and routes within 500 m"
      accent={routes.length ? `${routes.length} routes` : undefined}
    >
      <Fact
        label="Nearest stop"
        value={
          transit.nearestStop
            ? `#${transit.nearestStop.stopNumber} · ${transit.nearestStop.distanceDescription}`
            : undefined
        }
      />
      {transit.onTimePercentage != null ? (
        <div style={{ padding: "9px 0", borderBottom: "1px solid var(--line-soft)" }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 16, fontSize: 14 }}>
            <span style={{ color: "var(--ink3)" }}>On-time performance</span>
            <span style={{ fontWeight: 600 }}>{Math.round(transit.onTimePercentage)}%</span>
          </div>
          <div style={{ marginTop: 6 }}>
            <Meter
              value={transit.onTimePercentage}
              tone={transit.onTimePercentage >= 80 ? "good" : transit.onTimePercentage >= 65 ? "warn" : "bad"}
            />
          </div>
        </div>
      ) : null}
      <Fact
        label="Avg schedule deviation"
        value={
          transit.averageDeviationSeconds != null
            ? `${Math.round(transit.averageDeviationSeconds / 60)} min`
            : undefined
        }
      />
      <Fact label="Pass-ups (last year)" value={transit.passUpsLastYear || undefined} />
      <Fact
        label="Est. daily boardings"
        value={
          transit.averageDailyBoardings != null
            ? Math.round(transit.averageDailyBoardings).toLocaleString()
            : undefined
        }
      />
      {routes.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Routes</span>
          <div style={{ marginTop: 8, display: "flex", flexWrap: "wrap", gap: 6 }}>
            {routes.map((r) => (
              <span className="pill" key={r.routeNumber}>
                {r.routeNumber} · {r.routeName}
              </span>
            ))}
          </div>
        </div>
      ) : (
        <EmptyState />
      )}
    </KrokvaCard>
  );
}
