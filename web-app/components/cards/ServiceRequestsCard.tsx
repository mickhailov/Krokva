// Daily living · 311 service requests — neighbourhood totals for the trailing
// year plus top subjects/types and the most recent requests.

import { EmptyState, ErrorState, KrokvaCard } from "../KrokvaCard";
import { HBars, Sparkline, StatRow, StatTile } from "../viz/Viz";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport, IncidentBreakdown } from "@/lib/report/types";

const MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function BreakdownBars({ label, items }: { label: string; items: IncidentBreakdown[] }) {
  if (items.length === 0) return null;
  return (
    <div style={{ marginTop: 14 }}>
      <span className="eyebrow">{label}</span>
      <div style={{ marginTop: 8 }}>
        <HBars
          items={items.map((item) => ({
            label: titleCase(item.incidentType) ?? item.incidentType,
            value: item.count,
          }))}
        />
      </div>
    </div>
  );
}

export function ServiceRequestsCard({ report }: { report: AddressReport }) {
  const service = report.serviceRequests;
  const failed = report.failedModules.includes("serviceRequests");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Daily · 311" title="311 service requests">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!service || service.totalLastYear === 0) return null;

  const subjects = service.topSubjects.slice(0, 6);
  const types = service.topTypes.slice(0, 6);
  const recent = service.recentRequests.slice(0, 6);

  return (
    <KrokvaCard
      eyebrow="Daily · 311"
      title="311 service requests"
      subtitle={`${service.neighbourhood} · last 12 months`}
      accent={`${service.totalLastYear}`}
    >
      <StatRow>
        <StatTile label="Requests · 12 mo" value={service.totalLastYear} />
        <StatTile label="Open" value={service.openLastYear || undefined} tone="warn" />
        <StatTile label="Closed" value={service.closedLastYear || undefined} tone="good" />
      </StatRow>

      {service.monthlyTrend.length > 2 ? (
        <div style={{ marginTop: 14 }}>
          <span className="eyebrow">Monthly trend</span>
          <div style={{ marginTop: 6 }}>
            <Sparkline
              points={service.monthlyTrend.slice(-12).map((m) => ({
                label: `${MONTH_SHORT[(m.month - 1 + 12) % 12]} ${m.year}`,
                value: m.count,
              }))}
            />
          </div>
        </div>
      ) : null}

      <BreakdownBars label="Top subjects" items={subjects} />
      <BreakdownBars label="Top request types" items={types} />

      {recent.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Recent requests</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 8 }}>
            {recent.map((r, i) => (
              <div
                key={r.caseID ?? r.interactionID ?? i}
                style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}
              >
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <strong style={{ fontSize: 14 }}>
                    {titleCase(r.subject) ?? titleCase(r.type) ?? "Service request"}
                  </strong>
                  <span className="card__subtitle">{shortDate(r.openDate)}</span>
                </div>
                {r.reason ? <div className="card__subtitle">{titleCase(r.reason)}</div> : null}
                {r.status ? <span className="pill">{titleCase(r.status)}</span> : null}
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {subjects.length === 0 && types.length === 0 && recent.length === 0 ? (
        <EmptyState />
      ) : null}
    </KrokvaCard>
  );
}
