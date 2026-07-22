// Reference cards — metro-wide radon potential and CMHC rental-market figures.
// These are regional references (not address-level), shown for context.

import { KrokvaCard } from "../KrokvaCard";
import { HBars, Meter } from "../viz/Viz";
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
      collapsible
      collapsedSummary={`${radon.percentAboveGuideline}% of tested homes above guideline`}
    >
      <p style={{ fontSize: 14 }}>
        About <strong>{radon.percentAboveGuideline}%</strong> of tested homes in {radon.region} sit at
        or above Health Canada&rsquo;s 200&nbsp;Bq/m³ guideline. Testing your own home is the only way
        to know its level.
      </p>
      <div style={{ marginTop: 10 }}>
        <Meter
          value={radon.percentAboveGuideline}
          tone={radon.percentAboveGuideline >= 40 ? "bad" : radon.percentAboveGuideline >= 20 ? "warn" : "good"}
        />
        <div className="spark__caption">
          <span>0%</span>
          <span>homes above guideline · 100%</span>
        </div>
      </div>
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
      collapsible
      collapsedSummary={`${rm.area} · ${rm.year}${rm.vacancyRate != null ? ` · ${rm.vacancyRate}% vacancy` : ""}`}
    >
      <HBars
        items={rm.brackets
          .filter((b) => b.averageRent != null)
          .map((b) => ({
            label: b.bedrooms,
            value: b.averageRent as number,
            display: currency(b.averageRent),
          }))}
      />
      <p className="card__subtitle" style={{ marginTop: 8 }}>
        Metro-wide averages, not specific to this address.
      </p>
    </KrokvaCard>
  );
}
