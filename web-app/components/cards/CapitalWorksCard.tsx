// Capital works card — active capital projects and infrastructure-plan funding
// matched to this street.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { currency, titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function CapitalWorksCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("capitalWorks");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Capital works" title="Capital projects">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const capitalWorks = report.capitalWorks;
  if (!capitalWorks || capitalWorks.projects.length === 0) return null;

  const { projects } = capitalWorks;

  return (
    <KrokvaCard
      eyebrow="Amenities · Capital works"
      title="Capital projects"
      subtitle="Planned and active works on this street"
      accent={`${projects.length}`}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {projects.map((p, i) => (
          <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong style={{ fontSize: 14 }}>{p.name}</strong>
              {p.year ? <span className="card__subtitle">{p.year}</span> : null}
            </div>
            {p.status ? (
              <div className="card__subtitle">{titleCase(p.status)}</div>
            ) : p.detail ? (
              <div className="card__subtitle">{p.detail}</div>
            ) : null}
            {p.budget != null ? <Fact label="Budget" value={currency(p.budget)} /> : null}
            {p.funded === true ? <span className="pill">Funded</span> : null}
            {p.funded === false ? <span className="pill">Not funded</span> : null}
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}
