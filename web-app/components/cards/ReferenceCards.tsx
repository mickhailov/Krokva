// Reference cards — metro-wide radon potential and CMHC rental-market figures.
// These are regional references (not address-level), shown for context.

import { Fact, KrokvaCard } from "../KrokvaCard";
import { currency } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function RadonCard({ report }: { report: AddressReport }) {
  const radon = report.radon;
  if (!radon) return null;
  return (
    <KrokvaCard
      eyebrow="Reference · Radon"
      title="Radon potential"
      subtitle={`${radon.region} — regional reference, not an address reading`}
      accent={`${radon.percentAboveGuideline}%`}
    >
      <p style={{ fontSize: 14 }}>
        About <strong>{radon.percentAboveGuideline}%</strong> of tested homes in {radon.region} sit at
        or above Health Canada&rsquo;s 200&nbsp;Bq/m³ guideline. Testing your own home is the only way
        to know its level.
      </p>
      <p className="card__subtitle" style={{ marginTop: 8 }}>
        {radon.surveyName}
      </p>
    </KrokvaCard>
  );
}

export function RentalMarketCard({ report }: { report: AddressReport }) {
  const rm = report.rentalMarket;
  if (!rm) return null;
  return (
    <KrokvaCard
      eyebrow="Reference · Rental market"
      title="Rental market"
      subtitle={`${rm.area} · ${rm.year} (CMHC)`}
      accent={rm.vacancyRate != null ? `${rm.vacancyRate}% vacancy` : undefined}
    >
      {rm.brackets.map((b) => (
        <Fact key={b.bedrooms} label={b.bedrooms} value={currency(b.averageRent)} />
      ))}
      <p className="card__subtitle" style={{ marginTop: 8 }}>
        Metro-wide averages, not specific to this address.
      </p>
    </KrokvaCard>
  );
}
