// By-Law investigations card — neighbourhood complaint activity by year and the
// top complaint types over the last year.

import { EmptyState, ErrorState, KrokvaCard } from "../KrokvaCard";
import { titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function BylawCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("bylaw");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · By-law" title="By-law investigations">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const bylaw = report.bylaw;
  if (!bylaw || (bylaw.yearly.length === 0 && bylaw.complaintTypes.length === 0)) return null;

  const yearly = [...bylaw.yearly].sort((a, b) => a.year - b.year);
  const max = Math.max(...yearly.map((y) => y.count), 1);
  const lastYear = yearly.length ? yearly[yearly.length - 1].count : undefined;

  return (
    <KrokvaCard
      eyebrow="Permits · By-law"
      title="By-law investigations"
      subtitle={`${bylaw.neighbourhood} · complaints per year`}
      accent={lastYear != null ? `${lastYear}` : undefined}
    >
      {yearly.length ? (
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          {yearly.map((y) => (
            <div key={y.year} style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <span className="mono" style={{ width: 44, color: "var(--ink3)", fontSize: 13 }}>
                {y.year}
              </span>
              <div style={{ flex: 1, height: 10, background: "var(--surface-alt)", borderRadius: 5 }}>
                <div
                  style={{
                    width: `${(y.count / max) * 100}%`,
                    height: "100%",
                    background: "var(--gold)",
                    borderRadius: 5,
                  }}
                />
              </div>
              <span className="mono" style={{ width: 40, textAlign: "right", fontSize: 13 }}>
                {y.count}
              </span>
            </div>
          ))}
        </div>
      ) : null}

      {bylaw.complaintTypes.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Top complaint types</span>
          <div style={{ marginTop: 8 }}>
            {bylaw.complaintTypes.map((t) => (
              <div className="kv" key={t.incidentType}>
                <span className="kv__key">{titleCase(t.incidentType)}</span>
                <span className="kv__val">{t.count}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {yearly.length === 0 && bylaw.complaintTypes.length === 0 ? <EmptyState /> : null}
    </KrokvaCard>
  );
}
