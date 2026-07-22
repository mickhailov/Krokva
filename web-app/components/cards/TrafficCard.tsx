// Traffic card — midblock street study + nearest permanent count station.
// Reads report.traffic (TrafficSummary).

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate } from "@/lib/format";
import { AddressReport, TrafficStudy } from "@/lib/report/types";

function StudyBlock({ heading, study }: { heading: string; study: TrafficStudy }) {
  const count =
    study.vehiclesCounted != null
      ? `${study.vehiclesCounted.toLocaleString()} ${study.countSummaryUnit ?? ""}`.trim()
      : undefined;
  return (
    <div style={{ marginTop: 12 }}>
      <span className="eyebrow">{heading}</span>
      <div style={{ marginTop: 8 }}>
        <Fact label="Location" value={study.locationDescription} />
        <Fact label={study.countMetricLabel ?? "Count"} value={count} />
        <Fact label="Direction" value={study.direction} />
        <Fact label="Distance" value={study.distanceDescription} />
        <Fact label="Count date" value={shortDate(study.countDate)} />
      </div>
    </div>
  );
}

export function TrafficCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("traffic");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Street" title="Traffic counts">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const traffic = report.traffic;
  if (!traffic || (!traffic.streetStudy && !traffic.nearestPermanentStation)) return null;

  const accent = traffic.streetStudy?.vehiclesCounted;

  return (
    <KrokvaCard
      eyebrow="Amenities · Street"
      title="Traffic counts"
      accent={accent != null ? accent.toLocaleString() : undefined}
    >
      {traffic.streetStudy ? (
        <StudyBlock heading="Midblock street study" study={traffic.streetStudy} />
      ) : null}
      {traffic.nearestPermanentStation ? (
        <StudyBlock heading="Nearest permanent count station" study={traffic.nearestPermanentStation} />
      ) : null}
      {traffic.streetStudy?.countNote ? (
        <p className="card__subtitle" style={{ marginTop: 12 }}>
          {traffic.streetStudy.countNote}
        </p>
      ) : null}
    </KrokvaCard>
  );
}
