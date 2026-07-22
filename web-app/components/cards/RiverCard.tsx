// River gauge card — nearest river-level reading near the property, plus a
// plain river-proximity note. Winnipeg has no wired flood-zone dataset, so this
// is an exposure *hint* from gauge distance, not an official flood rating.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate } from "@/lib/format";
import { parseMeters } from "@/lib/report/rating";
import { AddressReport } from "@/lib/report/types";

/** Buyer-facing river-proximity note keyed off the nearest gauge distance. */
function floodHint(distanceDescription: string): { tone: "warn" | "good"; text: string } | undefined {
  const m = parseMeters(distanceDescription);
  if (m == null) return undefined;
  if (m < 500)
    return {
      tone: "warn",
      text: "Close to a river. Check the City/Province flood maps and whether the lot sits in a designated flood zone — riverbank properties can face overland-flood insurance costs and spring sandbagging.",
    };
  if (m < 1500)
    return {
      tone: "warn",
      text: "Within a short distance of a river. Low-lying or basement-level areas are worth checking against the flood maps before buying.",
    };
  return {
    tone: "good",
    text: "Well back from the nearest monitored river — limited direct river-flood exposure.",
  };
}

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

  const hint = floodHint(river.distanceDescription);

  return (
    <KrokvaCard
      eyebrow="Amenities · Rivers"
      title="River water levels"
      subtitle={`${river.location} · ${river.distanceDescription}`}
      accent={river.riverName}
      collapsible
      collapsedSummary={`${river.riverName} · ${river.distanceDescription}`}
    >
      {hint ? (
        <div
          style={{
            marginBottom: 12,
            padding: "10px 12px",
            borderRadius: 8,
            background: "var(--paper-2, rgba(0,0,0,0.03))",
            border: "1px solid var(--line-soft)",
          }}
        >
          <span className="eyebrow">River proximity</span>
          <p className="card__subtitle" style={{ marginTop: 4 }}>
            {hint.text}
          </p>
        </div>
      ) : null}
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
