// House Score card — dashboard hero: the overall grade plus per-section meters
// with explainable signals. Mirrors the app's score hero + ScoreBreakdownSheet.

import { KrokvaCard } from "../KrokvaCard";
import { Meter, Tone } from "../viz/Viz";
import { AddressReport } from "@/lib/report/types";
import {
  computeRating,
  effectiveWeight,
  grade,
  isUnavailable,
  sectionScore,
  SectionScore,
  totalDataPoints,
} from "@/lib/report/rating";

function scoreTone(v: number): Tone {
  if (v >= 80) return "good";
  if (v >= 60) return "warn";
  return "bad";
}

function scoreColor(v: number): string {
  if (v >= 80) return "var(--sage)";
  if (v >= 60) return "var(--gold-deep)";
  return "var(--clay)";
}

function SectionBlock({
  name,
  section,
  weight,
}: {
  name: string;
  section: SectionScore;
  weight: number;
}) {
  const unavailable = isUnavailable(section);
  const v = sectionScore(section);
  return (
    <div style={{ minWidth: 0 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 8 }}>
        <span style={{ fontWeight: 650, fontSize: 13.5 }}>{name}</span>
        <span className="mono" style={{ fontSize: 12.5, color: unavailable ? "var(--ink3)" : "var(--ink)" }}>
          {unavailable ? "No data" : Math.round(v)}
          {!unavailable && weight > 0 ? (
            <span style={{ color: "var(--ink3)" }}> · {Math.round(weight * 100)}%</span>
          ) : null}
        </span>
      </div>
      <div style={{ marginTop: 6 }}>
        {!unavailable ? <Meter value={v} tone={scoreTone(v)} /> : <Meter value={0} />}
      </div>
      {section.signals.length ? (
        <div style={{ marginTop: 7 }}>
          {section.signals.slice(0, 5).map((s) => (
            <div
              key={s.label}
              style={{ display: "flex", justifyContent: "space-between", gap: 10, padding: "2px 0", fontSize: 11.5 }}
            >
              <span style={{ color: "var(--ink3)", minWidth: 0 }}>{s.detail}</span>
              <span className="mono" style={{ color: "var(--ink3)" }}>{Math.round(s.score)}</span>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export function ScoreCard({ report }: { report: AddressReport }) {
  // Only meaningful once an address resolved with some data.
  if (!report.property && !report.civicContext) return null;
  const rating = computeRating(report);
  if (totalDataPoints(rating) === 0) return null;

  const overall = Math.round(rating.overall);
  const rows: [string, SectionScore][] = [
    ["Property", rating.property],
    ["Safety", rating.safety],
    ["Mobility", rating.mobility],
    ["Liveability", rating.liveability],
    ["Risk & condition", rating.risk],
  ];
  // effectiveWeight keys on the original section names.
  const weightKey: Record<string, string> = {
    "Property": "Property",
    "Safety": "Safety",
    "Mobility": "Mobility",
    "Liveability": "Liveability",
    "Risk & condition": "Risk",
  };

  return (
    <KrokvaCard eyebrow="Krokva · House Score" title="House Score" accent={grade(rating.overall)}>
      <div style={{ display: "flex", flexWrap: "wrap", gap: "20px 32px", alignItems: "flex-start" }}>
        <div style={{ flex: "0 0 auto" }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
            <span style={{ fontSize: 56, fontWeight: 800, letterSpacing: "-0.02em", lineHeight: 1, color: scoreColor(overall) }}>
              {overall}
            </span>
            <span style={{ fontSize: 16, color: "var(--ink3)" }}>/ 100</span>
          </div>
          <p className="card__subtitle" style={{ marginTop: 8, maxWidth: 220 }}>
            Weighted across {totalDataPoints(rating)} data points. Sections with no
            city data are dropped and their weight redistributed.
          </p>
        </div>
        <div
          style={{
            flex: "1 1 340px",
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
            gap: "14px 24px",
          }}
        >
          {rows.map(([name, section]) => (
            <SectionBlock
              key={name}
              name={name}
              section={section}
              weight={effectiveWeight(rating, weightKey[name])}
            />
          ))}
        </div>
      </div>
    </KrokvaCard>
  );
}
