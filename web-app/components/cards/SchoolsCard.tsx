// Amenities & street — nearby schools. Ports the app's school-amenity list into a
// KrokvaCard: closest schools by distance with grades, type, and program tags.

import { ErrorState, KrokvaCard } from "../KrokvaCard";
import { AddressReport } from "@/lib/report/types";

export function SchoolsCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("schools");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Schools" title="Nearby schools">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const schools = report.nearbySchools;
  if (!schools || schools.length === 0) return null;

  return (
    <KrokvaCard
      eyebrow="Amenities · Schools"
      title="Nearby schools"
      subtitle="Closest schools to this address"
      accent={`${schools.length}`}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {schools.map((s, i) => (
          <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <strong style={{ fontSize: 14 }}>{s.name}</strong>
              <span className="card__subtitle">{s.distanceDescription}</span>
            </div>
            <div className="card__subtitle">{s.address}</div>
            <div
              style={{
                display: "flex",
                flexWrap: "wrap",
                gap: 6,
                alignItems: "center",
                marginTop: s.schoolType || s.grades || s.programs.length ? 6 : 0,
              }}
            >
              {s.schoolType ? <span className="pill">{s.schoolType}</span> : null}
              {s.grades ? <span className="card__subtitle">Grades {s.grades}</span> : null}
              {s.walkingTimeDescription ? (
                <span className="card__subtitle">· {s.walkingTimeDescription}</span>
              ) : null}
            </div>
            {s.programs.length ? (
              <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 6 }}>
                {s.programs.map((p) => (
                  <span key={p} className="pill">
                    {p}
                  </span>
                ))}
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </KrokvaCard>
  );
}
