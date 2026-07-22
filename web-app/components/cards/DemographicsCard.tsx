// Daily living · Demographics card — "Who lives here": census population,
// household income/size, commute split, top non-official language, immigration,
// and a higher-poverty flag for the address's census boundary.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { HBars, StatRow, StatTile } from "../viz/Viz";
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
          <StatRow>
            <StatTile label="Population" value={demographics.totalPopulation?.toLocaleString()} />
            <StatTile label="Median income" value={currency(demographics.medianHouseholdIncome)} sub="per household" />
            <StatTile
              label="Household size"
              value={
                demographics.averageHouseholdSize != null
                  ? demographics.averageHouseholdSize.toFixed(1)
                  : undefined
              }
              sub="people, average"
            />
            <StatTile label="Immigrants" value={percent(demographics.immigrantPercent)} />
          </StatRow>

          {demographics.childrenPercent != null || demographics.seniorsPercent != null ? (
            <div style={{ marginTop: 14 }}>
              <span className="eyebrow">Age mix</span>
              <div style={{ marginTop: 8 }}>
                <HBars
                  max={100}
                  items={[
                    demographics.childrenPercent != null
                      ? {
                          label: "Children (0–14)",
                          value: demographics.childrenPercent,
                          display: `${Math.round(demographics.childrenPercent)}%`,
                        }
                      : null,
                    demographics.seniorsPercent != null
                      ? {
                          label: "Seniors (65+)",
                          value: demographics.seniorsPercent,
                          display: `${Math.round(demographics.seniorsPercent)}%`,
                        }
                      : null,
                  ].filter((x): x is NonNullable<typeof x> => x != null)}
                />
              </div>
            </div>
          ) : null}

          <div style={{ marginTop: 12 }}>
            <Fact label="Top non-official language" value={demographics.topNonOfficialLanguage} />
          </div>
          {demographics.isHighPovertyArea ? (
            <div style={{ marginTop: 8 }}>
              <span className="pill">Higher-poverty area</span>
            </div>
          ) : null}

          {commute.length > 0 ? (
            <div style={{ marginTop: 14 }}>
              <span className="eyebrow">Commute to work</span>
              <div style={{ marginTop: 8 }}>
                <HBars
                  items={commute.map((mode) => ({
                    label: mode.incidentType,
                    value: commuteTotal > 0 ? (mode.count / commuteTotal) * 100 : mode.count,
                    display:
                      commuteTotal > 0
                        ? `${Math.round((mode.count / commuteTotal) * 100)}%`
                        : mode.count.toLocaleString(),
                  }))}
                  max={commuteTotal > 0 ? 100 : undefined}
                />
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
