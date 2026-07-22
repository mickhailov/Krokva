// Amenities & street — street access: pavement condition, school speed zone,
// nearby cycling routes, active accessibility disruptions, and lane closures.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport, StreetDisruption } from "@/lib/report/types";

function DisruptionList({ items }: { items: StreetDisruption[] }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {items.map((d, i) => (
        <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
            <strong style={{ fontSize: 14 }}>{d.title}</strong>
            {d.distanceDescription ? (
              <span className="card__subtitle">{d.distanceDescription}</span>
            ) : null}
          </div>
          {d.detail ? <div className="card__subtitle">{d.detail}</div> : null}
          {d.startDate || d.endDate ? (
            <div className="card__subtitle">
              {[shortDate(d.startDate), shortDate(d.endDate)].filter(Boolean).join(" – ")}
            </div>
          ) : null}
          {d.status ? <span className="pill">{titleCase(d.status)}</span> : null}
        </div>
      ))}
    </div>
  );
}

export function StreetAccessCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("streetAccess");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Street" title="Street access">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const access = report.streetAccess;
  if (!access) return null;

  const school = access.schoolSpeedLimit;
  const hasFacts =
    access.pavementCondition != null ||
    access.pavementSurface != null ||
    access.roadType != null ||
    access.cyclingRoutesNearby > 0 ||
    school != null;

  return (
    <KrokvaCard eyebrow="Amenities · Street" title="Street access">
      {hasFacts ? (
        <>
          <Fact label="Pavement condition" value={titleCase(access.pavementCondition)} />
          <Fact label="Surface type" value={titleCase(access.pavementSurface)} />
          <Fact label="Road type" value={titleCase(access.roadType)} />
          <Fact
            label="Cycling routes nearby"
            value={access.cyclingRoutesNearby || undefined}
          />
          {school ? (
            <>
              <Fact label="School speed zone" value={school.school} />
              <Fact label="Speed limit" value={school.speedLimit} />
              <Fact
                label="When in effect"
                value={[school.effectiveDays, school.effectiveTime].filter(Boolean).join(", ") || undefined}
              />
            </>
          ) : null}
        </>
      ) : null}

      {access.activeDisruptions.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Active disruptions</span>
          <div style={{ marginTop: 8 }}>
            <DisruptionList items={access.activeDisruptions} />
          </div>
        </div>
      ) : null}

      {access.activeLaneClosures.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Lane closures</span>
          <div style={{ marginTop: 8 }}>
            <DisruptionList items={access.activeLaneClosures} />
          </div>
        </div>
      ) : null}

      {!hasFacts && !access.activeDisruptions.length && !access.activeLaneClosures.length ? (
        <EmptyState />
      ) : null}
    </KrokvaCard>
  );
}
