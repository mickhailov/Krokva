// "What matters here" — the report's lede. Two short lists distilled from the
// House Score signals: things worth a look, and standout strengths. Each row
// links to the page section that carries the backing cards, so the reader can
// jump straight to the detail.

import { KrokvaCard } from "../KrokvaCard";
import { computeDigest, DigestItem } from "@/lib/report/digest";
import { AddressReport } from "@/lib/report/types";

function DigestRow({ item, tone }: { item: DigestItem; tone: "warn" | "good" }) {
  return (
    <a href={`#${item.sectionId}`} className={`digest-row digest-row--${tone}`}>
      <span className="digest-row__dot" aria-hidden />
      <span className="digest-row__text">{item.detail}</span>
      <span className="digest-row__section">{item.sectionTitle} ↓</span>
    </a>
  );
}

export function DigestCard({ report }: { report: AddressReport }) {
  const { concerns, strengths } = computeDigest(report);
  if (concerns.length === 0 && strengths.length === 0) return null;

  return (
    <KrokvaCard wide eyebrow="Krokva · Summary" title="What matters here">
      <div className="digest-grid">
        {concerns.length ? (
          <div>
            <span className="eyebrow">Worth a look</span>
            <div style={{ marginTop: 8 }}>
              {concerns.map((c, i) => (
                <DigestRow key={i} item={c} tone="warn" />
              ))}
            </div>
          </div>
        ) : null}
        {strengths.length ? (
          <div>
            <span className="eyebrow">Strengths</span>
            <div style={{ marginTop: 8 }}>
              {strengths.map((s, i) => (
                <DigestRow key={i} item={s} tone="good" />
              ))}
            </div>
          </div>
        ) : null}
      </div>
    </KrokvaCard>
  );
}
