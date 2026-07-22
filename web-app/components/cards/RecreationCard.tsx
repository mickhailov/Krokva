// Amenities & street — recreation complexes, community centres, and leisure
// activities near the address. Ports the RecreationSummary card from the app.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function RecreationCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("recreation");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Recreation" title="Recreation & leisure">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const recreation = report.recreation;
  if (
    !recreation ||
    (recreation.complexes.length === 0 &&
      recreation.communityCentres.length === 0 &&
      recreation.activities.length === 0)
  ) {
    return null;
  }

  const { nearestComplex, complexes, communityCentres, activities } = recreation;

  return (
    <KrokvaCard
      eyebrow="Amenities · Recreation"
      title="Recreation & leisure"
      subtitle="Complexes, community centres & activities nearby"
      accent={`${complexes.length}`}
    >
      {nearestComplex ? (
        <>
          <Fact label="Nearest complex" value={nearestComplex.name} />
          <Fact label="Distance" value={nearestComplex.distanceDescription} />
          <Fact label="Amenities" value={nearestComplex.amenities.join(" · ") || undefined} />
        </>
      ) : null}

      {complexes.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Complexes within 5 km</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 8 }}>
            {complexes.map((c, i) => (
              <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <strong style={{ fontSize: 14 }}>{c.name}</strong>
                  <span className="card__subtitle">{c.distanceDescription}</span>
                </div>
                {c.address ? <div className="card__subtitle">{c.address}</div> : null}
                {c.amenities.length ? (
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 4, marginTop: 4 }}>
                    {c.amenities.map((a) => (
                      <span className="pill" key={a}>
                        {a}
                      </span>
                    ))}
                  </div>
                ) : null}
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {communityCentres.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Community centres within 3 km</span>
          <div style={{ marginTop: 8 }}>
            {communityCentres.map((c, i) => (
              <div className="kv" key={i}>
                <span className="kv__key">{c.name}</span>
                <span className="kv__val">{c.distanceDescription}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {activities.length ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Leisure activities</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 8 }}>
            {activities.slice(0, 12).map((a, i) => (
              <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <strong style={{ fontSize: 14 }}>{a.name}</strong>
                  <span className="card__subtitle">{shortDate(a.startDate)}</span>
                </div>
                {a.placeName ? <div className="card__subtitle">{titleCase(a.placeName)}</div> : null}
                <div style={{ display: "flex", flexWrap: "wrap", gap: 4, marginTop: 4 }}>
                  {a.category ? <span className="pill">{titleCase(a.category)}</span> : null}
                  {a.status ? <span className="pill">{titleCase(a.status)}</span> : null}
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        complexes.length === 0 && communityCentres.length === 0 ? <EmptyState /> : null
      )}
    </KrokvaCard>
  );
}
