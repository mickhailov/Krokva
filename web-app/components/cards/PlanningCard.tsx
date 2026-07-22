// Planning context card — parcel zoning by-law description and nearby public
// planning notices. Ports PlanningContextSummary rendering.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function PlanningCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("planning");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · Planning" title="Zoning & planning notices">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const planning = report.planning;
  if (!planning) return null;
  const notices = planning.publicNotices;
  const hasZoning =
    planning.zoningCode != null ||
    planning.zoningDescription != null ||
    planning.zoningIntent != null;
  if (!hasZoning && notices.length === 0) return null;

  return (
    <KrokvaCard
      eyebrow="Permits · Planning"
      title="Zoning & planning notices"
      subtitle="Parcel zoning and nearby notices"
      accent={notices.length ? `${notices.length}` : undefined}
    >
      {hasZoning ? (
        <>
          <Fact label="Zoning code" value={planning.zoningCode} />
          <Fact label="Zoning" value={titleCase(planning.zoningDescription)} />
          <Fact label="Intent" value={titleCase(planning.zoningIntent)} />
        </>
      ) : null}

      {notices.length ? (
        <div style={{ marginTop: hasZoning ? 12 : 0 }}>
          <span className="eyebrow">Nearby public notices</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 8 }}>
            {notices.slice(0, 10).map((n, i) => (
              <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <strong style={{ fontSize: 14 }}>{titleCase(n.noticeType)}</strong>
                  <span className="card__subtitle">{shortDate(n.meetingDate)}</span>
                </div>
                <div className="card__subtitle">{n.address}</div>
                {n.description ? <div className="card__subtitle">{n.description}</div> : null}
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  {n.decision ? <span className="pill">{n.decision}</span> : <span />}
                  {n.distanceDescription ? (
                    <span className="card__subtitle">{n.distanceDescription}</span>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
