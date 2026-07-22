// Mosquito control card — latest adult-nuisance trap counts for the address's
// city quadrant, with an informational fogging-threshold note.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function MosquitoCard({ report }: { report: AddressReport }) {
  const mosquito = report.mosquito;
  const failed = report.failedModules.includes("mosquito");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Insect control" title="Mosquito activity">
        <ErrorState />
      </KrokvaCard>
    );
  }

  if (!mosquito) return null;

  const peak = Math.max(mosquito.quadrantCount ?? 0, mosquito.cityWideAverage ?? 0);

  return (
    <KrokvaCard
      eyebrow="Amenities · Insect control"
      title="Mosquito activity"
      subtitle={`${mosquito.quadrant} quadrant`}
      accent={peak > 0 ? `${peak}` : undefined}
    >
      <Fact label="Quadrant trap count" value={mosquito.quadrantCount ?? undefined} />
      <Fact label="City-wide daily average" value={mosquito.cityWideAverage ?? undefined} />
      <Fact label="Count date" value={shortDate(mosquito.countDate)} />
      {mosquito.foggingThresholdReached ? (
        <div style={{ marginTop: 12 }}>
          <span className="eyebrow">Note</span>
          <p style={{ marginTop: 8 }}>
            Trap counts are high enough (about 100+ per trap) that the City typically
            considers fogging for nuisance mosquitoes.
          </p>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
