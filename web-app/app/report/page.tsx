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
import { KpiStrip } from "@/components/cards/KpiStrip";
import { DigestCard } from "@/components/cards/DigestCard";
import { PrintButton } from "@/components/PrintButton";
import { SectionNav } from "@/components/SectionNav";
import { computeDigest, sectionTone, SECTION_IDS, SectionTone } from "@/lib/report/digest";

/** Section header + dashboard grid for its cards. `id` anchors the section nav;
 *  `tone` drives the traffic-light dot beside the header. */
function Section({
  id,
  title,
  tone = "none",
  children,
}: {
  id: string;
  title: string;
  tone?: SectionTone;
  children: React.ReactNode;
}) {
  return (
    <section id={id} style={{ scrollMarginTop: 76 }}>
      <div className="section-head">
        {tone !== "none" ? <span className={`section-head__dot section-head__dot--${tone}`} aria-hidden /> : null}
        {title}
      </div>
      <div className="report-grid">{children}</div>
    </section>
  );
}

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
  const digest = computeDigest(report);
  const navSections = [
    { id: SECTION_IDS.property, title: "Value" },
    { id: SECTION_IDS.permits, title: "Flags" },
    { id: SECTION_IDS.safety, title: "Safety" },
    { id: SECTION_IDS.daily, title: "Daily life" },
    { id: SECTION_IDS.amenities, title: "Schools & travel" },
    { id: SECTION_IDS.reference, title: "Reference" },
  ].map((s) => ({ ...s, hasConcern: digest.concernSections.has(s.id) }));

  return (
    <main className="wrap wrap--wide" style={{ paddingTop: 28, paddingBottom: 64 }}>
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
      <div style={{ marginTop: 14 }}>
        <KpiStrip report={report} />
      </div>
      <div style={{ marginTop: 14 }}>
        <DigestCard report={report} />
      </div>

      <SectionNav sections={navSections} />

      <Section id={SECTION_IDS.property} title="What's it worth?" tone={sectionTone(digest, SECTION_IDS.property)}>
        <HeroPropertyCard property={report.property} failed={propertyFailed} />
        {report.property ? (
          <>
            <PropertyFinancialCard property={report.property} />
            <PropertyFactsCard property={report.property} />
          </>
        ) : null}
        <NeighbourhoodValuesCard report={report} />
        <ComparablesCard report={report} />
      </Section>

      <MapCard report={report} />

      <Section id={SECTION_IDS.permits} title="Anything flagged here?" tone={sectionTone(digest, SECTION_IDS.permits)}>
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
      </Section>

      <Section id={SECTION_IDS.safety} title="Is it safe here?" tone={sectionTone(digest, SECTION_IDS.safety)}>
        <EmergencyCard
          emergency={report.emergency}
          failed={report.failedModules.includes("emergency")}
        />
        <PublicHealthCard report={report} />
        <PoliceCrimeCard report={report} />
        <NeighbourhoodRiskCard report={report} />
      </Section>

      <Section id={SECTION_IDS.daily} title="What's daily life like?" tone={sectionTone(digest, SECTION_IDS.daily)}>
        <WasteCard report={report} />
        <DemographicsCard report={report} />
        <LocalGovernmentCard report={report} />
        <LocalBusinessCard report={report} />
        <CivicContextCard report={report} />
        <ServiceRequestsCard report={report} />
      </Section>

      <Section id={SECTION_IDS.amenities} title="Schools & getting around" tone={sectionTone(digest, SECTION_IDS.amenities)}>
        {/* Buyer-priority order: schools + how you get around come first, then
            green space and leisure, then street/utility reference cards. */}
        <SchoolsCard report={report} />
        <TransitCard report={report} />
        <StreetAccessCard report={report} />
        <TrafficCard report={report} />
        <ParksCard report={report} />
        <RecreationCard report={report} />
        <AquaticsCard report={report} />
        <LibraryCard report={report} />
        <RiverCard report={report} />
        <InfrastructureCard
          infrastructure={report.infrastructure}
          failed={report.failedModules.includes("infrastructure")}
        />
        <WaterQualityCard report={report} />
        <CapitalWorksCard report={report} />
        <FacilityClosuresCard report={report} />
        <HeritageCard report={report} />
        <MosquitoCard report={report} />
      </Section>

      <Section id={SECTION_IDS.reference} title="Good to know" tone={sectionTone(digest, SECTION_IDS.reference)}>
        <RadonCard report={report} />
        <RentalMarketCard report={report} />
      </Section>

      <p className="card__subtitle" style={{ marginTop: 32 }}>
        {report.attribution}
      </p>
    </main>
  );
}
