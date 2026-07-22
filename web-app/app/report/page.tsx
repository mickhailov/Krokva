// Report page — server-renders the full dossier for ?address=…. Runs the report
// build on the server so the CDS facade fetches never touch the browser (no
// CORS, host stays server-side) and the page is shareable / indexable.

import Link from "next/link";
import { buildWinnipegReport } from "@/lib/report/winnipeg";
import { ErrorState } from "@/components/KrokvaCard";
import {
  HeroPropertyCard,
  PropertyFactsCard,
  PropertyFinancialCard,
} from "@/components/cards/PropertyCards";
import {
  InfrastructureCard,
  PermitActivityCard,
  PermitsCard,
  VacantOrdersCard,
} from "@/components/cards/PermitCards";
import { EmergencyCard } from "@/components/cards/SafetyCards";
import { NeighbourhoodValuesCard } from "@/components/cards/NeighbourhoodValuesCard";
import { ComparablesCard } from "@/components/cards/ComparablesCard";
import { DevelopmentCard } from "@/components/cards/DevelopmentCard";
import { PlanningCard } from "@/components/cards/PlanningCard";
import { BylawCard } from "@/components/cards/BylawCard";
import { ShortTermRentalsCard } from "@/components/cards/ShortTermRentalsCard";
import { PublicHealthCard } from "@/components/cards/PublicHealthCard";
import { PoliceCrimeCard } from "@/components/cards/PoliceCrimeCard";
import { NeighbourhoodRiskCard } from "@/components/cards/NeighbourhoodRiskCard";
import { WasteCard } from "@/components/cards/WasteCard";
import { DemographicsCard } from "@/components/cards/DemographicsCard";
import { LocalGovernmentCard } from "@/components/cards/LocalGovernmentCard";
import { LocalBusinessCard } from "@/components/cards/LocalBusinessCard";
import { CivicContextCard } from "@/components/cards/CivicContextCard";
import { ServiceRequestsCard } from "@/components/cards/ServiceRequestsCard";
import { ParksCard } from "@/components/cards/ParksCard";
import { RecreationCard } from "@/components/cards/RecreationCard";
import { AquaticsCard } from "@/components/cards/AquaticsCard";
import { LibraryCard } from "@/components/cards/LibraryCard";
import { RiverCard } from "@/components/cards/RiverCard";
import { TransitCard } from "@/components/cards/TransitCard";
import { SchoolsCard } from "@/components/cards/SchoolsCard";
import { StreetAccessCard } from "@/components/cards/StreetAccessCard";
import { TrafficCard } from "@/components/cards/TrafficCard";
import { WaterQualityCard } from "@/components/cards/WaterQualityCard";
import { CapitalWorksCard } from "@/components/cards/CapitalWorksCard";
import { FacilityClosuresCard } from "@/components/cards/FacilityClosuresCard";
import { HeritageCard } from "@/components/cards/HeritageCard";
import { MosquitoCard } from "@/components/cards/MosquitoCard";
import { RadonCard, RentalMarketCard } from "@/components/cards/ReferenceCards";
import { ScoreCard } from "@/components/cards/ScoreCard";
import { MapCard } from "@/components/cards/MapCard";
import { PrintButton } from "@/components/PrintButton";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  searchParams,
}: {
  searchParams: { address?: string };
}) {
  const address = searchParams.address?.trim();
  return {
    title: address ? `${address} — Krokva` : "Krokva report",
    description: address
      ? `Civic dossier for ${address}: assessment, taxes, permits, safety and amenities.`
      : undefined,
  };
}

export default async function ReportPage({
  searchParams,
}: {
  searchParams: { address?: string };
}) {
  const address = searchParams.address?.trim();

  if (!address) {
    return (
      <main className="wrap" style={{ paddingTop: 48 }}>
        <p className="state">No address given.</p>
        <p style={{ marginTop: 12 }}>
          <Link href="/">← Search an address</Link>
        </p>
      </main>
    );
  }

  const report = await buildWinnipegReport(address);
  const propertyFailed = report.failedModules.includes("property");

  return (
    <main className="wrap" style={{ paddingTop: 28, paddingBottom: 64 }}>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: 8,
        }}
      >
        <Link href="/" className="eyebrow">
          ← Krokva
        </Link>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <PrintButton />
          <span className="eyebrow">Winnipeg, MB</span>
        </div>
      </div>

      {report.dataSourceUnavailable ? (
        <div className="card">
          <ErrorState label="Couldn't reach the civic data source. Please try again shortly." />
        </div>
      ) : null}

      <ScoreCard report={report} />

      <div className="section-head">Property</div>
      <HeroPropertyCard property={report.property} failed={propertyFailed} />
      {report.property ? (
        <>
          <PropertyFinancialCard property={report.property} />
          <PropertyFactsCard property={report.property} />
        </>
      ) : null}
      <MapCard report={report} />
      <NeighbourhoodValuesCard report={report} />
      <ComparablesCard report={report} />

      <div className="section-head">Permits &amp; development</div>
      <PermitsCard permits={report.permits} failed={report.failedModules.includes("permits")} />
      <VacantOrdersCard
        orders={report.vacantOrders}
        failed={report.failedModules.includes("vacantOrders")}
      />
      <PermitActivityCard activity={report.permitActivity} />
      <DevelopmentCard report={report} />
      <PlanningCard report={report} />
      <BylawCard report={report} />
      <ShortTermRentalsCard report={report} />

      <div className="section-head">Safety &amp; health</div>
      <EmergencyCard
        emergency={report.emergency}
        failed={report.failedModules.includes("emergency")}
      />
      <PublicHealthCard report={report} />
      <PoliceCrimeCard report={report} />
      <NeighbourhoodRiskCard report={report} />

      <div className="section-head">Daily living</div>
      <WasteCard report={report} />
      <DemographicsCard report={report} />
      <LocalGovernmentCard report={report} />
      <LocalBusinessCard report={report} />
      <CivicContextCard report={report} />
      <ServiceRequestsCard report={report} />

      <div className="section-head">Amenities &amp; street</div>
      <InfrastructureCard
        infrastructure={report.infrastructure}
        failed={report.failedModules.includes("infrastructure")}
      />
      <ParksCard report={report} />
      <RecreationCard report={report} />
      <AquaticsCard report={report} />
      <LibraryCard report={report} />
      <RiverCard report={report} />
      <TransitCard report={report} />
      <SchoolsCard report={report} />
      <StreetAccessCard report={report} />
      <TrafficCard report={report} />
      <WaterQualityCard report={report} />
      <CapitalWorksCard report={report} />
      <FacilityClosuresCard report={report} />
      <HeritageCard report={report} />
      <MosquitoCard report={report} />

      <div className="section-head">Reference</div>
      <RadonCard report={report} />
      <RentalMarketCard report={report} />

      <p className="card__subtitle" style={{ marginTop: 32 }}>
        {report.attribution}
      </p>
    </main>
  );
}
