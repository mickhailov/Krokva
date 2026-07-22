// Property module cards — hero value + assessment facts. Port of
// HeroPropertyCard / PropertyFinancialCard / PropertyFactsCard (the essential
// fields). A card renders "No data" when its summary is empty and "Database
// error" only when the fetch failed.

import { EmptyState, ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { area, currency, titleCase } from "@/lib/format";
import { PropertyAssessment } from "@/lib/report/types";

export function HeroPropertyCard({
  property,
  failed,
}: {
  property?: PropertyAssessment;
  failed: boolean;
}) {
  const value = currency(property?.totalAssessedValue);
  return (
    <KrokvaCard
      eyebrow="Property · Assessment"
      title={property?.fullAddress ?? "This address"}
      subtitle={property?.neighbourhood}
      accent={value ? "Assessed" : undefined}
    >
      {failed ? (
        <ErrorState />
      ) : !property ? (
        <EmptyState label="No assessment on file for this address." />
      ) : (
        <>
          {value ? (
            <div style={{ fontSize: 34, fontWeight: 800, letterSpacing: "-0.02em" }}>{value}</div>
          ) : (
            <EmptyState label="No assessed value published." />
          )}
          {property.assessmentYear ? (
            <p className="card__subtitle">Assessment year {property.assessmentYear}</p>
          ) : null}
        </>
      )}
    </KrokvaCard>
  );
}

export function PropertyFinancialCard({ property }: { property: PropertyAssessment }) {
  const tax = currency(property.propertyTax);
  if (!tax) return null;
  return (
    <KrokvaCard
      eyebrow="Property · Taxes"
      title="Property tax"
      accent={property.propertyTaxIsEstimated ? "Estimated" : undefined}
    >
      <div style={{ fontSize: 26, fontWeight: 700 }}>
        {tax}
        <span style={{ fontSize: 13, fontWeight: 500, color: "var(--ink3)" }}>
          {" "}
          / yr{property.propertyTaxYear ? ` · ${property.propertyTaxYear}` : ""}
        </span>
      </div>
      {property.propertyTaxIsEstimated ? (
        <p className="card__subtitle">
          Estimated from the assessed value at the average 2026 residential mill rate.
        </p>
      ) : null}
    </KrokvaCard>
  );
}

export function PropertyFactsCard({ property }: { property: PropertyAssessment }) {
  return (
    <KrokvaCard eyebrow="Property · Facts" title="Property facts">
      <Fact label="Neighbourhood" value={titleCase(property.neighbourhood)} />
      <Fact label="Living area" value={area(property.livingArea)} />
      <Fact label="Land area" value={area(property.landArea)} />
      <Fact label="Year built" value={property.yearBuilt} />
      <Fact label="Style" value={titleCase(property.houseStyle)} />
      <Fact label="Rooms" value={property.rooms} />
      <Fact label="Basement" value={titleCase(property.basement)} />
      <Fact label="Garage" value={titleCase(property.garage)} />
      <Fact label="Air conditioning" value={titleCase(property.airConditioning)} />
      <Fact label="Fireplace" value={titleCase(property.fireplace)} />
      <Fact label="Swimming pool" value={titleCase(property.swimmingPool)} />
      <Fact label="Zoning" value={property.zoning} />
      <Fact label="Use code" value={property.useCode} />
      <Fact label="Roll number" value={property.rollNumber} />
    </KrokvaCard>
  );
}
