// Report digest — a 10-second "what matters here" read, distilled from the
// House Score signals that ReportRating already computes. Each signal carries a
// 0–100 score (higher is always better), so we split the strongest and weakest
// into "worth a look" vs "strengths" and anchor each back to its page section.

import { AddressReport } from "./types";
import { computeRating, grade, Signal, totalDataPoints } from "./rating";

/** Page-section anchors (must match the ids rendered in app/report/page.tsx). */
export const SECTION_IDS = {
  property: "sec-property",
  permits: "sec-permits",
  safety: "sec-safety",
  daily: "sec-daily",
  amenities: "sec-amenities",
  reference: "sec-reference",
} as const;

export type SectionId = (typeof SECTION_IDS)[keyof typeof SECTION_IDS];

export interface DigestItem {
  detail: string;
  score: number;
  sectionId: SectionId;
  sectionTitle: string;
}

// Rating sections don't map 1:1 to page sections; point each at the page
// section where the reader will find the backing cards.
const RATING_TO_PAGE: Record<string, { id: SectionId; title: string }> = {
  property: { id: SECTION_IDS.property, title: "Property" },
  safety: { id: SECTION_IDS.safety, title: "Safety & health" },
  mobility: { id: SECTION_IDS.amenities, title: "Amenities & street" },
  liveability: { id: SECTION_IDS.amenities, title: "Amenities & street" },
  risk: { id: SECTION_IDS.amenities, title: "Amenities & street" },
};

const CONCERN_MAX = 45; // score at or below this reads as "worth a look"
const STRENGTH_MIN = 82; // score at or above this reads as a strength

export interface Digest {
  concerns: DigestItem[];
  strengths: DigestItem[];
  /** Page-section ids that contain at least one concern (drives the nav dot). */
  concernSections: Set<string>;
  /** Page-section ids that contain at least one standout strength. */
  strengthSections: Set<string>;
}

/** Traffic-light tone for a page section, from its concern/strength membership. */
export type SectionTone = "good" | "warn" | "bad" | "none";

export function sectionTone(digest: Digest, id: string): SectionTone {
  if (digest.concernSections.has(id)) return "bad";
  if (digest.strengthSections.has(id)) return "good";
  return "none";
}

export function computeDigest(report: AddressReport): Digest {
  const rating = computeRating(report);
  const groups: [string, Signal[]][] = [
    ["property", rating.property.signals],
    ["safety", rating.safety.signals],
    ["mobility", rating.mobility.signals],
    ["liveability", rating.liveability.signals],
    ["risk", rating.risk.signals],
  ];

  const concerns: DigestItem[] = [];
  const strengths: DigestItem[] = [];

  for (const [key, signals] of groups) {
    const page = RATING_TO_PAGE[key];
    for (const s of signals) {
      const item: DigestItem = {
        detail: s.detail,
        score: s.score,
        sectionId: page.id,
        sectionTitle: page.title,
      };
      if (s.score <= CONCERN_MAX) concerns.push(item);
      else if (s.score >= STRENGTH_MIN) strengths.push(item);
    }
  }

  // Worst-first for concerns, best-first for strengths; cap each to a scannable
  // handful so the digest stays a highlights reel, not a second full report.
  concerns.sort((a, b) => a.score - b.score);
  strengths.sort((a, b) => b.score - a.score);

  const concernSections = new Set(concerns.map((c) => c.sectionId));
  const strengthSections = new Set(strengths.map((s) => s.sectionId));

  return {
    concerns: concerns.slice(0, 5),
    strengths: strengths.slice(0, 5),
    concernSections,
    strengthSections,
  };
}

// ---------------------------------------------------------------- verdict

/** One-line, human-readable "should I keep looking?" read for the top of the
 *  report — the plain-language companion to the House Score number. */
export interface Verdict {
  overall: number;
  grade: string;
  tone: "good" | "warn" | "bad";
  /** Headline sentence, e.g. "Solid overall, with a few things to check." */
  headline: string;
  /** Strongest single point, phrased as a clause (may be absent). */
  strength?: string;
  /** Most notable concern, phrased as a clause (may be absent). */
  concern?: string;
}

export function computeVerdict(report: AddressReport): Verdict | null {
  const rating = computeRating(report);
  if (totalDataPoints(rating) === 0) return null;
  const overall = rating.overall;
  const { concerns, strengths } = computeDigest(report);

  const headline =
    overall >= 85
      ? "Strong across the board for Winnipeg"
      : overall >= 72
        ? "Solid overall, with a few things to check"
        : overall >= 58
          ? "Mixed — real trade-offs to weigh here"
          : overall >= 45
            ? "Below par — read the flags before you commit"
            : "Weak on several fronts";

  return {
    overall: Math.round(overall),
    grade: grade(overall),
    tone: overall >= 72 ? "good" : overall >= 55 ? "warn" : "bad",
    headline,
    strength: strengths[0]?.detail,
    concern: concerns[0]?.detail,
  };
}
