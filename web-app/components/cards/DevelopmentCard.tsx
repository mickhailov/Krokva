// Development card — recent development permits on nearby streets, plus citywide
// development-permit processing times and intake outcomes.

import { ErrorState, KrokvaCard } from "../KrokvaCard";
import { HBars } from "../viz/Viz";
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
      ) : null}

      {reviewProcessing.length > 0 ? (
        <div style={{ marginBottom: intake.length ? 14 : 0 }}>
          <span className="eyebrow">Review processing · avg business days</span>
          <div style={{ marginTop: 8 }}>
            <HBars
              items={reviewProcessing.map((m) => ({
                label: m.month ? `${m.description} · ${m.month}` : m.description,
                value: m.averageBusinessDays,
                context: m.serviceStandardDays ?? undefined,
                display: `${Math.round(m.averageBusinessDays)} d`,
              }))}
            />
          </div>
          {reviewProcessing.some((m) => m.serviceStandardDays != null) ? (
            <div className="chart-legend">
              <span className="chart-legend__item">
                <span className="swatch swatch--tick" /> service standard
              </span>
            </div>
          ) : null}
        </div>
      ) : null}

      {intake.length > 0 ? (
        <div>
          <span className="eyebrow">Intake outcomes</span>
          <div style={{ marginTop: 8, display: "flex", flexDirection: "column", gap: 8 }}>
            {intake.map((m, i) => {
              const total = m.approved + m.notApproved;
              return (
                <div key={i}>
                  <div style={{ display: "flex", justifyContent: "space-between", gap: 12, fontSize: 12.5 }}>
                    <span style={{ color: "var(--ink2)" }}>
                      {m.month ? `${m.description} · ${m.month}` : m.description}
                    </span>
                    <span className="mono" style={{ fontSize: 11.5 }}>
                      {m.approved} ✓ · {m.notApproved} ✕
                    </span>
                  </div>
                  {total > 0 ? (
                    <div
                      style={{ display: "flex", gap: 2, height: 8, marginTop: 4 }}
                      title={`${m.approved} approved, ${m.notApproved} not approved`}
                    >
                      <span
                        style={{
                          width: `${(m.approved / total) * 100}%`,
                          background: "var(--sage)",
                          borderRadius: "4px 2px 2px 4px",
                          minWidth: m.approved > 0 ? 2 : 0,
                        }}
                      />
                      <span
                        style={{
                          width: `${(m.notApproved / total) * 100}%`,
                          background: "var(--clay)",
                          borderRadius: "2px 4px 4px 2px",
                          minWidth: m.notApproved > 0 ? 2 : 0,
                        }}
                      />
                    </div>
                  ) : null}
                </div>
              );
            })}
          </div>
          <div className="chart-legend">
            <span className="chart-legend__item">
              <span className="swatch swatch--bar" style={{ background: "var(--sage)" }} /> approved
            </span>
            <span className="chart-legend__item">
              <span className="swatch swatch--bar" style={{ background: "var(--clay)" }} /> not approved
            </span>
          </div>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
