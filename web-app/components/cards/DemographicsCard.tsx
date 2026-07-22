// Daily living · Demographics card — "Who lives here": census population,
// household income/size, commute split, top non-official language, immigration,
// and a higher-poverty flag for the address's census boundary.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { currency } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

function percent(value?: number): string | undefined {
  return value == null ? undefined : `${Math.round(value)}%`;
}

export function DemographicsCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("demographics");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Daily · Demographics" title="Who lives here">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const demographics = report.demographics;
  if (!demographics) return null;

  const commute = demographics.commuteModes;
  const commuteTotal = commute.reduce((a, m) => a + m.count, 0);

  const hasAny =
    demographics.totalPopulation != null ||
    demographics.medianHouseholdIncome != null ||
    demographics.averageHouseholdSize != null ||
    demographics.childrenPercent != null ||
    demographics.seniorsPercent != null ||
    demographics.immigrantPercent != null ||
    demographics.topNonOfficialLanguage != null ||
    demographics.isHighPovertyArea === true ||
    commute.length > 0;

  return (
    <KrokvaCard
      eyebrow="Daily · Demographics"
      title="Who lives here"
      subtitle={demographics.boundaryName}
      accent={demographics.totalPopulation != null ? demographics.totalPopulation.toLocaleString() : undefined}
    >
      {hasAny ? (
        <>
          <Fact label="Population" value={demographics.totalPopulation?.toLocaleString()} />
          <Fact label="Children (0–14)" value={percent(demographics.childrenPercent)} />
          <Fact label="Seniors (65+)" value={percent(demographics.seniorsPercent)} />
          <Fact label="Median household income" value={currency(demographics.medianHouseholdIncome)} />
          <Fact
            label="Average household size"
            value={
              demographics.averageHouseholdSize != null
                ? demographics.averageHouseholdSize.toFixed(1)
                : undefined
            }
          />
          <Fact label="Immigrants" value={percent(demographics.immigrantPercent)} />
          <Fact label="Top non-official language" value={demographics.topNonOfficialLanguage} />
          <Fact
            label="Gini index"
            value={demographics.giniIndex != null ? demographics.giniIndex.toFixed(3) : undefined}
          />
          {demographics.isHighPovertyArea ? (
            <div style={{ marginTop: 8 }}>
              <span className="pill">Higher-poverty area</span>
            </div>
          ) : null}
          {commute.length > 0 ? (
            <div style={{ marginTop: 12 }}>
              <span className="eyebrow">Commute to work</span>
              <div style={{ marginTop: 8 }}>
                {commute.map((mode) => (
                  <div className="kv" key={mode.incidentType}>
                    <span className="kv__key">{mode.incidentType}</span>
                    <span className="kv__val">
                      {commuteTotal > 0
                        ? `${Math.round((mode.count / commuteTotal) * 100)}%`
                        : mode.count.toLocaleString()}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
        </>
      ) : (
        <EmptyState />
      )}
    </KrokvaCard>
  );
}
