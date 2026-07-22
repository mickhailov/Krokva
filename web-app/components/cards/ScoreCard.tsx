// House Score card — overall grade + per-section breakdown with explainable
// signals. Mirrors the app's score hero + ScoreBreakdownSheet.

import { KrokvaCard } from "../KrokvaCard";
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

function scoreColor(v: number): string {
  if (v >= 80) return "var(--sage)";
  if (v >= 60) return "var(--gold-deep)";
  if (v >= 40) return "var(--clay)";
  return "var(--clay)";
}

function SectionRow({
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
    <div style={{ padding: "10px 0", borderBottom: "1px solid var(--line-soft)" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12 }}>
        <span style={{ fontWeight: 600, fontSize: 14 }}>{name}</span>
        <span className="mono" style={{ fontSize: 13, color: unavailable ? "var(--ink3)" : "var(--ink)" }}>
          {unavailable ? "No data" : `${Math.round(v)}`}
          {!unavailable && weight > 0 ? (
            <span style={{ color: "var(--ink3)" }}> · {Math.round(weight * 100)}%</span>
          ) : null}
        </span>
      </div>
      {!unavailable ? (
        <div style={{ height: 8, background: "var(--surface-alt)", borderRadius: 4, marginTop: 6 }}>
          <div style={{ width: `${v}%`, height: "100%", background: scoreColor(v), borderRadius: 4 }} />
        </div>
      ) : null}
      {section.signals.length ? (
        <div style={{ marginTop: 8 }}>
          {section.signals.map((s) => (
            <div
              key={s.label}
              style={{ display: "flex", justifyContent: "space-between", gap: 12, padding: "3px 0", fontSize: 12.5 }}
            >
              <span style={{ color: "var(--ink3)" }}>{s.detail}</span>
              <span className="mono" style={{ color: "var(--ink3)" }}>
                {Math.round(s.score)}
              </span>
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
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, marginBottom: 4 }}>
        <span style={{ fontSize: 48, fontWeight: 800, letterSpacing: "-0.02em", color: scoreColor(overall) }}>
          {overall}
        </span>
        <span style={{ fontSize: 16, color: "var(--ink3)" }}>/ 100</span>
      </div>
      <p className="card__subtitle" style={{ marginBottom: 8 }}>
        Weighted across {totalDataPoints(rating)} data points from the sections below. Sections with no city
        data are dropped and their weight redistributed.
      </p>
      {rows.map(([name, section]) => (
        <SectionRow
          key={name}
          name={name}
          section={section}
          weight={effectiveWeight(rating, weightKey[name])}
        />
      ))}
    </KrokvaCard>
  );
}
