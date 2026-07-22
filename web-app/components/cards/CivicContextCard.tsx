// Daily living — civic context: ward, neighbourhood, postal code, plow zone, and
// school division for the address. Ports the AddressCivicContext summary.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { titleCase } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function CivicContextCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("civicContext");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Daily · Civic" title="Address context">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const ctx = report.civicContext;
  if (!ctx) return null;

  const hasAny =
    ctx.ward ||
    ctx.neighbourhood ||
    ctx.postalCode ||
    ctx.plowZone ||
    ctx.schoolDivision ||
    ctx.schoolDivisionBoundaryName ||
    ctx.schoolDivisionWard ||
    ctx.schoolDivisionWebsite;
  if (!hasAny) return null;

  return (
    <KrokvaCard
      eyebrow="Daily · Civic"
      title="Address context"
      subtitle={ctx.neighbourhood ? titleCase(ctx.neighbourhood) : undefined}
    >
      <Fact label="Ward" value={ctx.ward ? titleCase(ctx.ward) : undefined} />
      <Fact
        label="Neighbourhood"
        value={ctx.neighbourhood ? titleCase(ctx.neighbourhood) : undefined}
      />
      <Fact label="Postal code" value={ctx.postalCode?.toUpperCase()} />
      <Fact label="Plow zone" value={ctx.plowZone} />
      <Fact
        label="School division"
        value={
          ctx.schoolDivisionBoundaryName
            ? titleCase(ctx.schoolDivisionBoundaryName)
            : ctx.schoolDivision
              ? titleCase(ctx.schoolDivision)
              : undefined
        }
      />
      <Fact label="School division code" value={ctx.schoolDivisionCode} />
      <Fact
        label="School division ward"
        value={ctx.schoolDivisionWard ? titleCase(ctx.schoolDivisionWard) : undefined}
      />
      <Fact label="School division website" value={ctx.schoolDivisionWebsite} />
    </KrokvaCard>
  );
}
