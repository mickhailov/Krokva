// KPI strip — the dashboard's headline numbers, pulled from across the report
// modules. Each tile degrades to nothing when its module has no data.

import { AddressReport } from "@/lib/report/types";
import { currency } from "@/lib/format";
import { compact, StatRow, StatTile } from "../viz/Viz";

const nf = new Intl.NumberFormat("en-CA", { maximumFractionDigits: 0 });

export function KpiStrip({ report }: { report: AddressReport }) {
  const p = report.property;
  const crimeLatest = report.policeCrime?.yearlyCounts.length
    ? report.policeCrime.yearlyCounts[report.policeCrime.yearlyCounts.length - 1]
    : undefined;
  const emergency = report.emergency;
  const transit = report.transit;
  const demo = report.demographics;

  const tiles = [
    p?.totalAssessedValue != null ? (
      <StatTile
        key="assess"
        label={`Assessed value${p.assessmentYear ? ` · ${p.assessmentYear}` : ""}`}
        value={currency(p.totalAssessedValue)}
        sub={p.livingArea ? `${nf.format(p.livingArea)} sq ft living area` : undefined}
      />
    ) : null,
    p?.propertyTax != null ? (
      <StatTile
        key="tax"
        label={`Property tax${p.propertyTaxYear ? ` · ${p.propertyTaxYear}` : ""}`}
        value={currency(p.propertyTax)}
        sub={p.propertyTaxIsEstimated ? "Estimated from assessment" : "City records"}
      />
    ) : null,
    p?.yearBuilt ? (
      <StatTile
        key="built"
        label="Year built"
        value={p.yearBuilt}
        sub={p.houseStyle ?? p.useCode}
      />
    ) : null,
    crimeLatest ? (
      <StatTile
        key="crime"
        label={`Crime · ${crimeLatest.year}`}
        value={nf.format(crimeLatest.neighbourhood)}
        sub={`city avg ${nf.format(Math.round(crimeLatest.citywideAverage))} per neighbourhood`}
        tone={crimeLatest.neighbourhood > crimeLatest.citywideAverage * 1.05 ? "bad" : "good"}
      />
    ) : null,
    emergency?.totalLastYear ? (
      <StatTile
        key="fire"
        label="Fire/EMS calls · 12 mo"
        value={nf.format(emergency.totalLastYear)}
        sub={
          emergency.citywideMedian != null
            ? `city median ${nf.format(Math.round(emergency.citywideMedian))}`
            : emergency.neighbourhood
        }
      />
    ) : null,
    transit?.onTimePercentage != null ? (
      <StatTile
        key="transit"
        label="Transit on time"
        value={`${Math.round(transit.onTimePercentage)}%`}
        sub={transit.nearestStop ? `nearest stop ${transit.nearestStop.distanceDescription}` : undefined}
        tone={transit.onTimePercentage >= 80 ? "good" : transit.onTimePercentage >= 65 ? "warn" : "bad"}
      />
    ) : null,
    demo?.medianHouseholdIncome != null ? (
      <StatTile
        key="income"
        label="Median household income"
        value={`$${compact(demo.medianHouseholdIncome)}`}
        sub={demo.boundaryName}
      />
    ) : null,
    report.localBusiness?.totalNearby ? (
      <StatTile
        key="biz"
        label="Businesses · 500 m"
        value={nf.format(report.localBusiness.totalNearby)}
        sub={report.localBusiness.topCategories[0]?.incidentType}
      />
    ) : null,
  ].filter(Boolean);

  if (!tiles.length) return null;
  return <StatRow>{tiles}</StatRow>;
}
