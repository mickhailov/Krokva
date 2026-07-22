// Development card — recent development permits on nearby streets, plus citywide
// development-permit processing times and intake outcomes.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

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

  const { recentPermits, reviewProcessing, intake } = development;
  if (recentPermits.length === 0 && reviewProcessing.length === 0 && intake.length === 0) {
    return null;
  }

  return (
    <KrokvaCard
      eyebrow="Permits · Development"
      title="Development permits"
      subtitle="Nearby permits and citywide review pace"
      accent={recentPermits.length ? `${recentPermits.length}` : undefined}
    >
      {recentPermits.length > 0 ? (
        <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 12 }}>
          {recentPermits.slice(0, 12).map((p, i) => (
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
      ) : null}

      {reviewProcessing.length > 0 ? (
        <div style={{ marginBottom: intake.length ? 12 : 0 }}>
          <div className="card__subtitle" style={{ marginBottom: 6 }}>
            Review processing (avg. business days)
          </div>
          {reviewProcessing.map((m, i) => (
            <Fact
              key={i}
              label={m.description}
              value={
                m.serviceStandardDays != null
                  ? `${Math.round(m.averageBusinessDays)} of ${Math.round(m.serviceStandardDays)} days`
                  : `${Math.round(m.averageBusinessDays)} days`
              }
            />
          ))}
        </div>
      ) : null}

      {intake.length > 0 ? (
        <div>
          <div className="card__subtitle" style={{ marginBottom: 6 }}>
            Intake outcomes
          </div>
          {intake.map((m, i) => (
            <Fact
              key={i}
              label={m.description}
              value={`${m.approved} approved · ${m.notApproved} not approved`}
            />
          ))}
        </div>
      ) : null}
    </KrokvaCard>
  );
}
