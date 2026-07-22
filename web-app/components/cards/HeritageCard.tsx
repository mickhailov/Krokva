// Heritage card — the subject's own heritage designation (if any) plus nearby
// designated historical resources within 500 m.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { AddressReport, HeritageBuilding } from "@/lib/report/types";

function buildingLines(b: HeritageBuilding): string | undefined {
  const parts = [b.grade, b.listType, b.constructionYear].filter(
    (x): x is string => !!x,
  );
  return parts.length ? parts.join(" · ") : undefined;
}

export function HeritageCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("heritage");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Heritage" title="Heritage buildings">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const heritage = report.heritage;
  if (!heritage) return null;
  const { subjectDesignation, nearby } = heritage;
  if (!subjectDesignation && nearby.length === 0) return null;

  return (
    <KrokvaCard
      eyebrow="Amenities · Heritage"
      title="Heritage buildings"
      subtitle="Designated historical resources within 500 m"
      accent={`${nearby.length + (subjectDesignation ? 1 : 0)}`}
    >
      {subjectDesignation ? (
        <div style={{ marginBottom: nearby.length ? 16 : 0 }}>
          <span className="eyebrow">This property</span>
          <div style={{ marginTop: 8 }}>
            <strong style={{ fontSize: 15 }}>{subjectDesignation.name}</strong>
            {subjectDesignation.address ? (
              <div className="card__subtitle">{subjectDesignation.address}</div>
            ) : null}
            <Fact label="Grade" value={subjectDesignation.grade} />
            <Fact label="List type" value={subjectDesignation.listType} />
            <Fact label="Construction" value={subjectDesignation.constructionYear} />
          </div>
        </div>
      ) : null}

      {nearby.length ? (
        <div>
          <span className="eyebrow">Nearby heritage</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 8 }}>
            {nearby.map((b, i) => (
              <div
                key={i}
                style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}
              >
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <strong style={{ fontSize: 14 }}>{b.name}</strong>
                  <span className="card__subtitle">{b.distanceDescription}</span>
                </div>
                {b.address ? <div className="card__subtitle">{b.address}</div> : null}
                {buildingLines(b) ? (
                  <div className="card__subtitle">{buildingLines(b)}</div>
                ) : null}
              </div>
            ))}
          </div>
        </div>
      ) : subjectDesignation ? null : (
        <EmptyState />
      )}
    </KrokvaCard>
  );
}
