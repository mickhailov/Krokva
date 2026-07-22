// Short-term rentals card — licensed STR accommodations on this street, split
// into primary / non-primary residence licences with the most recent listings.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { HBars } from "../viz/Viz";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function ShortTermRentalsCard({ report }: { report: AddressReport }) {
  const str = report.shortTermRentals;
  const failed = report.failedModules.includes("shortTermRentals");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · Short-term rentals" title="Short-term rentals">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!str || str.total === 0) return null;

  return (
    <KrokvaCard
      eyebrow="Permits · Short-term rentals"
      title="Short-term rentals"
      subtitle="Licensed accommodations on this street"
      accent={`${str.total}`}
    >
      <Fact label="Licensed listings" value={str.total} />
      {str.primaryCount || str.nonPrimaryCount ? (
        <div style={{ margin: "10px 0 4px" }}>
          <HBars
            items={[
              { label: "Primary residence", value: str.primaryCount },
              { label: "Non-primary", value: str.nonPrimaryCount, emphasis: false },
            ].filter((x) => x.value > 0)}
          />
        </div>
      ) : null}

      {str.recent.length > 0 ? (
        <div style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 10 }}>
          {str.recent.map((r, i) => (
            <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                <strong style={{ fontSize: 14 }}>{r.address}</strong>
                <span className="card__subtitle">{shortDate(r.issuedDate)}</span>
              </div>
              {r.primaryStatus ? (
                <div className="card__subtitle">{titleCase(r.primaryStatus)}</div>
              ) : null}
              {r.ward ? <div className="card__subtitle">{titleCase(r.ward)}</div> : null}
            </div>
          ))}
        </div>
      ) : null}
    </KrokvaCard>
  );
}
