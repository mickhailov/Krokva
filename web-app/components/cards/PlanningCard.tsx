// Planning context card — parcel zoning by-law description and nearby public
// planning notices. Ports PlanningContextSummary rendering, plus a plain-English
// zoning gloss and an infill-pressure read from nearby lot-split variances.

import { ErrorState, Fact, KrokvaCard } from "../KrokvaCard";
import { shortDate, titleCase } from "@/lib/format";
import { AddressReport, PublicNotice } from "@/lib/report/types";

/** One-line, buyer-facing translation of a Winnipeg zoning code. Matches the
 *  leading zone family (R1 / R2 / RMF …); everything else falls back to a
 *  generic note so we never show nothing but the raw code. */
function plainZoning(code?: string): string | undefined {
  if (!code) return undefined;
  const c = code.toUpperCase();
  if (/\bR1\b|R1M|R1-M|\bRSF\b/.test(c)) return "Single detached homes — the standard house-and-yard zone.";
  if (/\bR2\b/.test(c)) return "Detached and two-family homes (duplexes) permitted.";
  if (/RMF|RMU|\bRM\b/.test(c)) return "Multi-family — row houses and low-rise apartments are allowed.";
  if (/\bC\d|COM|MIXED|PMU/.test(c)) return "Commercial or mixed-use — shops and offices are permitted here.";
  return "Residential zone. See the City by-law for what may be built.";
}

/** Nearby notices that signal the block is densifying — lot splits (a big lot
 *  becoming two skinny ones) or new multi-family use. Buyers care: it changes
 *  the streetscape, parking and light around the house. */
function infillNotices(notices: PublicNotice[]): PublicNotice[] {
  return notices.filter((n) => {
    const text = `${n.noticeType} ${n.description ?? ""}`.toLowerCase();
    // Lot splits: "two (2) residential zoning/building lots". Do NOT match on a
    // bare "instead of N square feet" — that also fires on garage floor-area
    // variances, which aren't densification.
    const lotSplit = /residential (zoning|building) lots|residential lots to permit lot area/.test(text);
    const multiFamily = /multi-?family|multiple family|apartment|secondary suite/.test(text);
    return lotSplit || multiFamily;
  });
}

export function PlanningCard({ report }: { report: AddressReport }) {
  const failed = report.failedModules.includes("planning");
  if (failed) {
    return (
      <KrokvaCard eyebrow="Permits · Planning" title="Zoning & planning notices">
        <ErrorState />
      </KrokvaCard>
    );
  }

  const planning = report.planning;
  if (!planning) return null;
  const notices = planning.publicNotices;
  const hasZoning =
    planning.zoningCode != null ||
    planning.zoningDescription != null ||
    planning.zoningIntent != null;
  if (!hasZoning && notices.length === 0) return null;

  const zoningGloss =
    titleCase(planning.zoningDescription) ?? plainZoning(planning.zoningCode);
  const infill = infillNotices(notices);

  return (
    <KrokvaCard
      eyebrow="Permits · Planning"
      title="Zoning & planning notices"
      subtitle="Parcel zoning and nearby notices"
      accent={notices.length ? `${notices.length}` : undefined}
    >
      {hasZoning ? (
        <>
          <Fact label="Zoning code" value={planning.zoningCode} />
          {zoningGloss ? (
            <p className="card__subtitle" style={{ marginTop: 4 }}>
              {zoningGloss}
            </p>
          ) : null}
          <Fact label="Intent" value={titleCase(planning.zoningIntent)} />
        </>
      ) : null}

      {infill.length >= 2 ? (
        <div
          style={{
            marginTop: 12,
            padding: "10px 12px",
            borderRadius: 8,
            background: "var(--clay-soft, rgba(180,120,90,0.12))",
            border: "1px solid var(--line-soft)",
          }}
        >
          <span className="eyebrow">Infill pressure nearby</span>
          <p className="card__subtitle" style={{ marginTop: 4 }}>
            {infill.length} nearby approvals to split lots or add multi-family homes. This block
            is densifying — expect new builds, and check what could go up next door.
          </p>
        </div>
      ) : null}

      {notices.length ? (
        <div style={{ marginTop: hasZoning ? 12 : 0 }}>
          <span className="eyebrow">Nearby public notices</span>
          <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 8 }}>
            {notices.slice(0, 10).map((n, i) => (
              <div key={i} style={{ borderBottom: "1px solid var(--line-soft)", paddingBottom: 8 }}>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <strong style={{ fontSize: 14 }}>{titleCase(n.noticeType)}</strong>
                  <span className="card__subtitle">{shortDate(n.meetingDate)}</span>
                </div>
                <div className="card__subtitle">{n.address}</div>
                {n.description ? <div className="card__subtitle">{n.description}</div> : null}
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  {n.decision ? <span className="pill">{n.decision}</span> : <span />}
                  {n.distanceDescription ? (
                    <span className="card__subtitle">{n.distanceDescription}</span>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </KrokvaCard>
  );
}
