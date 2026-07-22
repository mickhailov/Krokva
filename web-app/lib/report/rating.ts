// House Score — TypeScript port of ReportRating.swift. Computes five weighted
// section scores (Property, Safety, Mobility, Liveability, Risk) from the report,
// each an average of explainable 0–100 signals, then an overall weighted score
// with the weight of zero-data sections redistributed. The on-property permit
// history signal is skipped (that feature isn't ported to the web yet).

import { AddressReport, ReportModule } from "./types";

export interface Signal {
  label: string;
  score: number;
  detail: string;
}

export interface SectionScore {
  signals: Signal[];
  capacity: number;
}

export interface ReportRating {
  property: SectionScore;
  safety: SectionScore;
  mobility: SectionScore;
  liveability: SectionScore;
  risk: SectionScore;
  overall: number;
}

export const SECTION_WEIGHTS: Record<string, number> = {
  Property: 0.25,
  Safety: 0.2,
  Mobility: 0.2,
  Liveability: 0.2,
  Risk: 0.15,
};

export function sectionScore(s: SectionScore): number {
  return s.signals.length === 0
    ? 50
    : s.signals.reduce((a, x) => a + x.score, 0) / s.signals.length;
}
export const isUnavailable = (s: SectionScore) => s.signals.length === 0;
export const isPartial = (s: SectionScore) => s.signals.length > 0 && s.signals.length < s.capacity;

export function grade(overall: number): string {
  if (overall >= 90) return "A+";
  if (overall >= 80) return "A";
  if (overall >= 70) return "B";
  if (overall >= 60) return "C";
  if (overall >= 50) return "D";
  return "F";
}

export function totalDataPoints(r: ReportRating): number {
  return (
    r.property.signals.length +
    r.safety.signals.length +
    r.mobility.signals.length +
    r.liveability.signals.length +
    r.risk.signals.length
  );
}

/** Effective weight a section carries after zero-data sections are dropped. */
export function effectiveWeight(r: ReportRating, name: string): number {
  const sections: [string, SectionScore][] = [
    ["Property", r.property],
    ["Safety", r.safety],
    ["Mobility", r.mobility],
    ["Liveability", r.liveability],
    ["Risk", r.risk],
  ];
  const available = sections.filter(([, s]) => !isUnavailable(s));
  const totalWeight = available.reduce((a, [n]) => a + (SECTION_WEIGHTS[n] ?? 0), 0);
  const base = SECTION_WEIGHTS[name];
  if (totalWeight <= 0 || base == null || !available.some(([n]) => n === name)) return 0;
  return base / totalWeight;
}

const clamped = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

function relativeToAverage(ratio: number, noun: string, referent = "average"): string {
  if (Math.abs(ratio - 1) < 0.05) return `About the citywide ${referent} for ${noun}`;
  if (ratio < 1) return `${Math.round((1 - ratio) * 100)}% below the citywide ${referent} for ${noun}`;
  return `${Math.round((ratio - 1) * 100)}% above the citywide ${referent} for ${noun}`;
}

function trendDetail(delta: number, unit: string): string {
  const n = Math.round(Math.abs(delta));
  if (n === 0) return "Holding steady year over year";
  return delta < 0 ? `Down ${n} ${unit} over recent years` : `Up ${n} ${unit} over recent years`;
}

/** Parse "230 m" / "1.2 km" / "450m" into metres. */
export function parseMeters(text: string): number | undefined {
  const t = text.toLowerCase();
  const m = /(\d+(?:\.\d+)?)/.exec(t);
  if (!m) return undefined;
  const value = parseFloat(m[1]);
  if (!Number.isFinite(value)) return undefined;
  return t.includes("km") ? value * 1000 : value;
}

const plural = (n: number, s = "s") => (n === 1 ? "" : s);
const capFirst = (s: string) => (s.length ? s[0].toUpperCase() + s.slice(1) : s);
const failed = (d: AddressReport, m: ReportModule) => d.failedModules.includes(m);

function computeProperty(d: AddressReport): SectionScore {
  const signals: Signal[] = [];
  const p = d.property;

  if (p?.totalAssessedValue != null && d.neighbourhoodValues.length > 0) {
    const sorted = [...d.neighbourhoodValues].sort((a, b) => a.midpoint - b.midpoint);
    const below = sorted.filter((b) => b.midpoint < p.totalAssessedValue!).length;
    const pct = (below / sorted.length) * 100;
    signals.push({
      label: "Value vs neighbourhood",
      score: pct,
      detail: `Assessed above ${Math.round(pct)}% of nearby value bands`,
    });
  }

  if (p?.livingArea != null) {
    const area = p.livingArea;
    const s = area < 800 ? 25 : area < 1200 ? 50 : area < 1800 ? 75 : 100;
    signals.push({ label: "Living area", score: s, detail: `${Math.round(area)} sq ft of finished space` });
  }

  if (p?.yearBuilt != null) {
    const age = new Date().getUTCFullYear() - p.yearBuilt;
    const s = age < 10 ? 100 : age < 30 ? 80 : age < 60 ? 60 : 40;
    signals.push({ label: "Building age", score: s, detail: `Built ${p.yearBuilt} · ${age} years old` });
  }

  if (p != null) {
    let bonus = 40;
    const present: string[] = [];
    if (p.garage != null) {
      bonus += 20;
      present.push("garage");
    }
    if (p.basement != null) {
      bonus += 20;
      present.push("basement");
    }
    if (p.airConditioning != null) {
      bonus += 20;
      present.push("A/C");
    }
    signals.push({
      label: "Key features",
      score: Math.min(bonus, 100),
      detail: present.length === 0 ? "No garage, basement or A/C on record" : capFirst(present.join(", ")),
    });
  }

  return { signals, capacity: 4 };
}

function computeSafety(d: AddressReport): SectionScore {
  const signals: Signal[] = [];

  const lastCrime = d.policeCrime?.yearlyCounts.at(-1);
  if (lastCrime && lastCrime.citywideAverage > 0) {
    const ratio = lastCrime.neighbourhood / lastCrime.citywideAverage;
    signals.push({
      label: "Crime vs city",
      score: clamped(100 - (ratio - 1) * 80, 0, 100),
      detail: relativeToAverage(ratio, "crime"),
    });
  }

  if (d.policeCrime && d.policeCrime.yearlyCounts.length >= 2) {
    const recent = d.policeCrime.yearlyCounts.slice(-3);
    const delta = recent[recent.length - 1].neighbourhood - recent[0].neighbourhood;
    const s = delta < -10 ? 90 : delta < 0 ? 70 : delta < 10 ? 55 : 30;
    signals.push({ label: "Crime trend", score: s, detail: trendDetail(delta, "incidents") });
  }

  const em = d.emergency;
  if (em && em.citywideMedian != null && em.citywideMedian > 0) {
    const ratio = em.totalLastYear / em.citywideMedian;
    signals.push({
      label: "Emergency calls",
      score: clamped(100 - (ratio - 1) * 80, 0, 100),
      detail: relativeToAverage(ratio, "fire/medical calls", "median"),
    });
  }

  const lastHealth = d.publicHealth?.yearlyEvents.at(-1);
  if (lastHealth && lastHealth.citywideAverage > 0) {
    const ratio = lastHealth.neighbourhood / lastHealth.citywideAverage;
    signals.push({
      label: "Public health",
      score: clamped(100 - (ratio - 1) * 80, 0, 100),
      detail: relativeToAverage(ratio, "health events"),
    });
  }

  if (!failed(d, "vacantOrders")) {
    const count = d.vacantOrders.length;
    const vacantScore = count === 0 ? 100 : count === 1 ? 70 : count === 2 ? 45 : 15;
    signals.push({
      label: "Vacant buildings",
      score: vacantScore,
      detail:
        count === 0 ? "None ordered vacant on this street" : `${count} vacant-building order${plural(count)} nearby`,
    });
  }

  const bylawCount = d.bylaw?.yearly.at(-1)?.count;
  if (bylawCount != null) {
    signals.push({
      label: "Bylaw cases",
      score: clamped(100 - bylawCount * 0.5, 0, 100),
      detail: `${bylawCount} investigation${plural(bylawCount)} in the area last year`,
    });
  }

  return { signals, capacity: 6 };
}

function computeMobility(d: AddressReport): SectionScore {
  const signals: Signal[] = [];
  const transit = d.transit;
  if (transit) {
    if (transit.onTimePercentage != null) {
      signals.push({
        label: "On-time transit",
        score: transit.onTimePercentage,
        detail: `${Math.round(transit.onTimePercentage)}% of buses run on time`,
      });
    }
    if (transit.nearestStop) {
      const m = parseMeters(transit.nearestStop.distanceDescription);
      if (m != null) {
        const s = m < 200 ? 100 : m < 400 ? 80 : m < 700 ? 60 : m < 1000 ? 35 : 15;
        signals.push({ label: "Nearest stop", score: s, detail: `${Math.round(m)} m to the closest stop` });
      }
    }
    const rc = transit.routes.length;
    const routeScore = rc === 0 ? 0 : rc === 1 ? 30 : rc === 2 ? 55 : rc === 3 ? 75 : 100;
    signals.push({ label: "Route choice", score: routeScore, detail: `${rc} bus route${plural(rc)} within reach` });

    const pu = transit.passUpsLastYear;
    const passUpScore = pu === 0 ? 100 : pu <= 3 ? 80 : pu <= 10 ? 55 : 20;
    signals.push({
      label: "Pass-ups",
      score: passUpScore,
      detail: pu === 0 ? "No full-bus pass-ups recorded" : `${pu} full-bus pass-up${plural(pu)} last year`,
    });
  }

  const street = d.streetAccess;
  if (street) {
    const cr = street.cyclingRoutesNearby;
    const cyclingScore = cr === 0 ? 10 : cr === 1 ? 40 : cr === 2 ? 70 : 100;
    signals.push({
      label: "Cycling routes",
      score: cyclingScore,
      detail: cr === 0 ? "No mapped cycling routes nearby" : `${cr} cycling route${plural(cr)} nearby`,
    });
    if (street.pavementCondition) {
      const c = street.pavementCondition.toLowerCase();
      const s =
        c.includes("good") || c.includes("excellent") ? 100 : c.includes("fair") ? 60 : c.includes("poor") ? 20 : 50;
      signals.push({ label: "Road condition", score: s, detail: `Pavement rated ${c}` });
    }
  }

  return { signals, capacity: 6 };
}

function computeLiveability(d: AddressReport): SectionScore {
  const signals: Signal[] = [];
  const parks = d.parks;
  if (parks) {
    const pc = parks.nearbyParks.length;
    const parkScore = pc === 0 ? 0 : pc === 1 ? 40 : pc === 2 ? 65 : pc === 3 ? 80 : 100;
    signals.push({
      label: "Parks nearby",
      score: parkScore,
      detail: pc === 0 ? "No parks within walking distance" : `${pc} park${plural(pc)} within reach`,
    });

    const amenities = parks.nearbyParks.reduce((a, p) => a + p.playgrounds + p.fields + p.courts, 0);
    const amenityScore = amenities === 0 ? 10 : amenities <= 3 ? 40 : amenities <= 8 ? 70 : 100;
    signals.push({
      label: "Park facilities",
      score: amenityScore,
      detail: `${amenities} playground${plural(amenities)}, field${plural(amenities)} & court${plural(amenities)}`,
    });

    if (parks.neighbourhoodHectares != null) {
      const ha = parks.neighbourhoodHectares;
      const s = ha < 10 ? 30 : ha < 30 ? 55 : ha < 80 ? 80 : 100;
      signals.push({ label: "Green space", score: s, detail: `${Math.round(ha)} ha of parkland in the area` });
    }
  }

  const library = d.library;
  if (library) {
    let libScore = 50;
    const m = parseMeters(library.distanceDescription);
    if (m != null) {
      if (m < 500) libScore += 15;
      else if (m < 1000) libScore += 8;
    }
    if (library.wifi) libScore += 8;
    if (library.accessibility) libScore += 8;
    if (library.parkingLot) libScore += 7;
    signals.push({
      label: "Library access",
      score: Math.min(libScore, 100),
      detail: `Nearest branch ${library.distanceDescription}`,
    });
  }

  const sr = d.serviceRequests;
  if (sr) {
    const total = sr.totalLastYear;
    const openRate = total > 0 ? sr.openLastYear / total : 0;
    const base = total <= 50 ? 90 : total <= 150 ? 70 : total <= 400 ? 50 : 30;
    signals.push({
      label: "311 requests",
      score: clamped(base - openRate * 20, 0, 100),
      detail: `${total} service request${plural(total)} last year · ${Math.round(openRate * 100)}% still open`,
    });
  }

  return { signals, capacity: 5 };
}

function computeRisk(d: AddressReport): SectionScore {
  const signals: Signal[] = [];

  // On-property permit-history signal is omitted (feature not ported to web).

  if (d.permitActivity.length >= 2) {
    const recent = d.permitActivity.slice(-3);
    const first = recent[0]?.count ?? 0;
    const last = recent[recent.length - 1]?.count ?? 0;
    const s = first === 0 ? 50 : last > first * 1.1 ? 85 : last >= first * 0.85 ? 65 : 35;
    signals.push({ label: "Area development", score: s, detail: trendDetail(last - first, "permits") });
  }

  const infra = d.infrastructure;
  if (infra && !failed(d, "infrastructure")) {
    const p = infra.potholes;
    const potholeScore = p === 0 ? 100 : p <= 3 ? 80 : p <= 10 ? 55 : 20;
    signals.push({
      label: "Road repairs",
      score: potholeScore,
      detail: p === 0 ? "No pothole repairs on this street" : `${p} pothole repair${plural(p)} on this street`,
    });

    if (infra.publicTrees > 0) {
      const ratio = infra.taggedTrees / infra.publicTrees;
      signals.push({
        label: "Tree health",
        score: clamped(100 - ratio * 200, 0, 100),
        detail: `${infra.taggedTrees} of ${infra.publicTrees} public trees disease-tagged`,
      });
    } else if (infra.taggedTrees === 0) {
      signals.push({ label: "Tree health", score: 100, detail: "No diseased public trees recorded" });
    }
  }

  const street = d.streetAccess;
  if (street && !failed(d, "streetAccess")) {
    const count = street.activeDisruptions.length + street.activeLaneClosures.length;
    const s = count === 0 ? 100 : count === 1 ? 75 : count === 2 ? 50 : 20;
    signals.push({
      label: "Street disruptions",
      score: s,
      detail: count === 0 ? "No active construction or closures" : `${count} active disruption${plural(count)} on the route`,
    });
  }

  return { signals, capacity: 5 };
}

export function computeRating(d: AddressReport): ReportRating {
  const property = computeProperty(d);
  const safety = computeSafety(d);
  const mobility = computeMobility(d);
  const liveability = computeLiveability(d);
  const risk = computeRisk(d);

  const sections: [SectionScore, number][] = [
    [property, SECTION_WEIGHTS.Property],
    [safety, SECTION_WEIGHTS.Safety],
    [mobility, SECTION_WEIGHTS.Mobility],
    [liveability, SECTION_WEIGHTS.Liveability],
    [risk, SECTION_WEIGHTS.Risk],
  ];
  const available = sections.filter(([s]) => !isUnavailable(s));
  const totalWeight = available.reduce((a, [, w]) => a + w, 0);
  const overall =
    totalWeight === 0
      ? 50
      : available.reduce((a, [s, w]) => a + sectionScore(s) * w, 0) / totalWeight;

  return { property, safety, mobility, liveability, risk, overall };
}
