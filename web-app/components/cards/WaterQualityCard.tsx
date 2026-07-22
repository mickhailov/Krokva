// Water quality card — latest-year drinking-water test results for the city's
// distribution system. Renders one row per measured parameter (average + range).

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
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
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
        {water.parameters.map((r) => {
          const value = readingValue(r);
          const range = readingRange(r);
          return (
            <div key={r.parameter}>
              <Fact label={titleCase(r.parameter) ?? r.parameter} value={value} />
              {range ? (
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
