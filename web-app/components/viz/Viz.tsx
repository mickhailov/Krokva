// Krokva chart kit — small server-rendered infographic primitives shared by the
// dossier cards. All HTML/CSS (plus inline SVG for lines), no client JS, so the
// dashboard stays SSR-only and printable.
//
// Color discipline (validated with the dataviz six-checks): the brand palette is
// deliberately muted, so charts never use multi-hue categorical series. Every
// chart is either a single accent hue (--gold-deep, ≥3:1 on the surface) or the
// "emphasis" pattern: subject in the accent hue, city-wide context in a
// recessive gray marker. Values are always direct-labeled or tabulated, never
// color-gated.

const nf = new Intl.NumberFormat("en-CA", { maximumFractionDigits: 0 });

export function compact(value: number): string {
  if (!Number.isFinite(value)) return "—";
  const abs = Math.abs(value);
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
  if (abs >= 10_000) return `${(value / 1_000).toFixed(0)}K`;
  if (abs >= 1_000) return `${(value / 1_000).toFixed(1).replace(/\.0$/, "")}K`;
  return nf.format(value);
}

export type Tone = "default" | "good" | "warn" | "bad" | "accent";

const TONE_COLOR: Record<Tone, string> = {
  default: "var(--ink)",
  good: "var(--sage)",
  warn: "var(--gold-deep)",
  bad: "var(--clay)",
  accent: "var(--gold-deep)",
};

/* ---------------------------------------------------------------- stat tile */

export function StatTile({
  label,
  value,
  sub,
  tone = "default",
}: {
  label: string;
  value?: string | number;
  sub?: string;
  tone?: Tone;
}) {
  if (value == null || value === "") return null;
  return (
    <div className="stat">
      <div className="stat__label">{label}</div>
      <div className="stat__value" style={{ color: TONE_COLOR[tone] }}>
        {value}
      </div>
      {sub ? <div className="stat__sub">{sub}</div> : null}
    </div>
  );
}

/** Grid wrapper for a row of stat tiles. */
export function StatRow({ children }: { children: React.ReactNode }) {
  return <div className="stat-row">{children}</div>;
}

/* ------------------------------------------------------- delta vs. baseline */

/**
 * Compares a subject value to a baseline (usually the city-wide average).
 * `higherIsBad` picks the tone: crime above average is bad, parks above
 * average is good.
 */
export function DeltaBadge({
  value,
  baseline,
  baselineLabel = "city avg",
  higherIsBad = true,
}: {
  value?: number;
  baseline?: number;
  baselineLabel?: string;
  higherIsBad?: boolean;
}) {
  if (value == null || baseline == null || baseline <= 0) return null;
  const pct = Math.round(((value - baseline) / baseline) * 100);
  if (!Number.isFinite(pct)) return null;
  const near = Math.abs(pct) < 5;
  const tone: Tone = near ? "default" : (pct > 0) === higherIsBad ? "bad" : "good";
  const arrow = near ? "≈" : pct > 0 ? "▲" : "▼";
  return (
    <span className={`delta delta--${tone}`}>
      {arrow} {near ? "near" : `${Math.abs(pct)}%`} {near ? "" : pct > 0 ? "above " : "below "}
      {baselineLabel}
    </span>
  );
}

/* -------------------------------------------------------- horizontal bars */

export interface HBarItem {
  label: string;
  value: number;
  /** Optional recessive context tick on the same track (e.g. city-wide avg). */
  context?: number;
  /** Optional display override for the value. */
  display?: string;
  emphasis?: boolean;
}

/**
 * Horizontal bar list — the workhorse for breakdowns (crime types, commute
 * modes, complaint subjects). Single accent hue; every bar carries its value,
 * so this doubles as the table view.
 */
export function HBars({
  items,
  max,
  unit,
}: {
  items: HBarItem[];
  max?: number;
  unit?: string;
}) {
  const rows = items.filter((i) => Number.isFinite(i.value));
  if (!rows.length) return null;
  const top = max ?? Math.max(...rows.map((i) => Math.max(i.value, i.context ?? 0)));
  if (top <= 0) return null;
  return (
    <div className="hbars">
      {rows.map((i, idx) => (
        <div
          className="hbar"
          key={`${i.label}-${idx}`}
          title={`${i.label}: ${i.display ?? nf.format(i.value)}${unit ? ` ${unit}` : ""}${
            i.context != null ? ` (city avg ${nf.format(Math.round(i.context))})` : ""
          }`}
        >
          <span className="hbar__label">{i.label}</span>
          <span className="hbar__track">
            <span
              className={`hbar__fill${i.emphasis === false ? " hbar__fill--muted" : ""}`}
              style={{ width: `${Math.max((i.value / top) * 100, i.value > 0 ? 2 : 0)}%` }}
            />
            {i.context != null && i.context > 0 ? (
              <span className="hbar__tick" style={{ left: `${Math.min((i.context / top) * 100, 100)}%` }} />
            ) : null}
          </span>
          <span className="hbar__value mono">{i.display ?? nf.format(i.value)}</span>
        </div>
      ))}
    </div>
  );
}

/* ------------------------------------------------------------ column trend */

export interface ColumnItem {
  label: string;
  value: number;
  /** Recessive context marker (e.g. city-wide average) drawn as a dash. */
  context?: number;
  emphasis?: boolean;
}

/**
 * Column chart for short series (yearly counts). Subject columns in the accent
 * hue; optional city-wide average as a gray dash on each column slot
 * (emphasis pattern, not a second categorical hue). Caps are direct-labeled —
 * the series are short (≤ 8 points), so labels stay sparse.
 */
export function ColumnTrend({
  items,
  height = 108,
  contextLabel,
}: {
  items: ColumnItem[];
  height?: number;
  contextLabel?: string;
}) {
  const rows = items.filter((i) => Number.isFinite(i.value));
  if (!rows.length) return null;
  const top = Math.max(...rows.map((i) => Math.max(i.value, i.context ?? 0)));
  if (top <= 0) return null;
  const hasContext = rows.some((i) => i.context != null && i.context > 0);
  return (
    <div>
      <div className="cols" style={{ height }}>
        {rows.map((i, idx) => (
          <div
            className="col"
            key={`${i.label}-${idx}`}
            title={`${i.label}: ${nf.format(i.value)}${
              i.context != null ? ` (city avg ${nf.format(Math.round(i.context))})` : ""
            }`}
          >
            <span className="col__cap mono">{compact(i.value)}</span>
            <span className="col__slot">
              <span
                className={`col__bar${i.emphasis === false ? " col__bar--muted" : ""}`}
                style={{ height: `${(i.value / top) * 100}%` }}
              />
              {i.context != null && i.context > 0 ? (
                <span className="col__tick" style={{ bottom: `${Math.min((i.context / top) * 100, 100)}%` }} />
              ) : null}
            </span>
            <span className="col__label">{i.label}</span>
          </div>
        ))}
      </div>
      {hasContext && contextLabel ? (
        <div className="chart-legend">
          <span className="chart-legend__item">
            <span className="swatch swatch--bar" /> this neighbourhood
          </span>
          <span className="chart-legend__item">
            <span className="swatch swatch--tick" /> {contextLabel}
          </span>
        </div>
      ) : null}
    </div>
  );
}

/* --------------------------------------------------------------- sparkline */

export interface SparkPoint {
  label: string;
  value: number;
}

/**
 * Monthly-trend sparkline: 2px line, 10% area wash, ringed end dot, last value
 * labeled. Values also surface via per-chart title tooltips and the caller's
 * text summary, so nothing is color- or hover-gated.
 */
export function Sparkline({
  points,
  height = 56,
}: {
  points: SparkPoint[];
  height?: number;
}) {
  const rows = points.filter((p) => Number.isFinite(p.value));
  if (rows.length < 2) return null;
  const w = 100;
  const h = 32;
  const pad = 3;
  const max = Math.max(...rows.map((p) => p.value));
  const min = Math.min(...rows.map((p) => p.value));
  const span = max - min || 1;
  const x = (i: number) => pad + (i / (rows.length - 1)) * (w - pad * 2);
  const y = (v: number) => pad + (1 - (v - min) / span) * (h - pad * 2);
  const path = rows.map((p, i) => `${i === 0 ? "M" : "L"}${x(i).toFixed(2)},${y(p.value).toFixed(2)}`).join(" ");
  const area = `${path} L${x(rows.length - 1).toFixed(2)},${h - pad} L${x(0).toFixed(2)},${h - pad} Z`;
  const last = rows[rows.length - 1];
  const peak = rows.reduce((a, b) => (b.value > a.value ? b : a));
  return (
    <div className="spark" title={`${rows[0].label} → ${last.label}. Peak ${nf.format(peak.value)} (${peak.label}).`}>
      <svg
        viewBox={`0 0 ${w} ${h}`}
        preserveAspectRatio="none"
        style={{ width: "100%", height, display: "block" }}
        role="img"
        aria-label={`Trend from ${rows[0].label} (${rows[0].value}) to ${last.label} (${last.value})`}
      >
        <path d={area} fill="var(--gold-deep)" opacity={0.1} />
        <path d={path} fill="none" stroke="var(--gold-deep)" strokeWidth={1.4} strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
        <circle cx={x(rows.length - 1)} cy={y(last.value)} r={2.6} fill="var(--gold-deep)" stroke="var(--surface)" strokeWidth={1.2} />
      </svg>
      <div className="spark__caption">
        <span>{rows[0].label}</span>
        <span>
          {last.label} · <strong className="mono">{nf.format(last.value)}</strong>
        </span>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------- meter */

/** Single ratio against a limit: filled track, same-ramp unfilled portion. */
export function Meter({
  value,
  max = 100,
  tone = "accent",
}: {
  value: number;
  max?: number;
  tone?: Tone;
}) {
  const pct = Math.max(0, Math.min((value / max) * 100, 100));
  return (
    <div className="meter">
      <div className="meter__fill" style={{ width: `${pct}%`, background: TONE_COLOR[tone] }} />
    </div>
  );
}

/* ------------------------------------------------------------ min–avg–max */

/** Range strip for measured parameters (water quality): min–max band + avg dot. */
export function RangeStrip({
  min,
  max,
  avg,
  domainMin,
  domainMax,
}: {
  min?: number;
  max?: number;
  avg?: number;
  domainMin: number;
  domainMax: number;
}) {
  const span = domainMax - domainMin || 1;
  const pos = (v: number) => `${Math.max(0, Math.min(((v - domainMin) / span) * 100, 100))}%`;
  if (min == null || max == null) return null;
  return (
    <div className="range">
      <div
        className="range__band"
        style={{ left: pos(min), width: `calc(${pos(max)} - ${pos(min)})` }}
      />
      {avg != null ? <div className="range__dot" style={{ left: pos(avg) }} /> : null}
    </div>
  );
}
