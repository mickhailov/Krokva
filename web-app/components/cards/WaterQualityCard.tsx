// Water quality card — latest-year drinking-water test results for the city's
// distribution system. Renders one row per measured parameter (average + range).

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { RangeStrip } from "../viz/Viz";
import { titleCase } from "@/lib/format";
import { AddressReport, WaterQualityReading } from "@/lib/report/types";

function formatNumber(value: number): string {
  return `${Math.round(value * 1000) / 1000}`;
}

function readingValue(r: WaterQualityReading): string | undefined {
  if (r.average == null) return undefined;
  const unit = r.units ? ` ${r.units}` : "";
  return `${formatNumber(r.average)}${unit}`;
}

function readingRange(r: WaterQualityReading): string | undefined {
  if (r.minimum == null || r.maximum == null) return undefined;
  return `${formatNumber(r.minimum)}–${formatNumber(r.maximum)}`;
}

export function WaterQualityCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("waterQuality");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Amenities · Drinking water" title="Water quality">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const water = report.waterQuality;
  if (!water || water.parameters.length === 0) return null;

  const subtitleParts = [water.area, water.year != null ? `${water.year}` : undefined].filter(
    (p): p is string => !!p,
  );

  return (
    <KrokvaCard
      eyebrow="Amenities · Drinking water"
      title="Water quality"
      subtitle={subtitleParts.length ? subtitleParts.join(" · ") : undefined}
      accent={`${water.parameters.length}`}
      collapsible
      collapsedSummary={`${water.parameters.length} parameters tested${water.year != null ? ` · ${water.year}` : ""}`}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
        {water.parameters.map((r) => {
          const value = readingValue(r);
          const range = readingRange(r);
          const showStrip = r.minimum != null && r.maximum != null && r.maximum > r.minimum;
          return (
            <div key={r.parameter} style={{ paddingBottom: showStrip ? 6 : 0 }}>
              <Fact label={titleCase(r.parameter) ?? r.parameter} value={value} />
              {showStrip ? (
                <div title={`Min ${r.minimum} · avg ${r.average ?? "—"} · max ${r.maximum}${r.units ? ` ${r.units}` : ""}`}>
                  <RangeStrip
                    min={r.minimum}
                    max={r.maximum}
                    avg={r.average}
                    domainMin={0}
                    domainMax={r.maximum as number}
                  />
                  <div className="spark__caption">
                    <span>0</span>
                    <span>range {range}</span>
                  </div>
                </div>
              ) : range ? (
                <div className="card__subtitle" style={{ marginTop: -2 }}>
                  Range {range}
                </div>
              ) : null}
            </div>
          );
        })}
      </div>
    </KrokvaCard>
  );
}
