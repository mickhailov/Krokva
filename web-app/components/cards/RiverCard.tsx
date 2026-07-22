// River gauge card — nearest river-level reading near the property.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate } from "@/lib/format";
import { AddressReport } from "@/lib/report/types";

export function RiverCard({ report }: { report: AddressReport }) {
  const river = report.river;
  const failed = report.failedModules.includes("river");

  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Rivers" title="River water levels">
        <ErrorState />
      </KrokvaCard>
    );
  }
  if (!river) return null;

  return (
    <KrokvaCard
      eyebrow="Amenities · Rivers"
      title="River water levels"
      subtitle={`${river.location} · ${river.distanceDescription}`}
      accent={river.riverName}
    >
      <Fact
        label="James datum"
        value={river.jamesFeet != null ? `${river.jamesFeet.toFixed(2)} ft` : undefined}
      />
      <Fact
        label="Geodetic level"
        value={river.geodeticFeet != null ? `${river.geodeticFeet.toFixed(2)} ft` : undefined}
      />
      <Fact
        label="Geodetic level (metric)"
        value={river.geodeticMetric != null ? `${river.geodeticMetric.toFixed(2)} m` : undefined}
      />
      <Fact label="Reading date" value={shortDate(river.readingDate)} />
      <Fact label="Notes" value={river.notes} />
    </KrokvaCard>
  );
}
