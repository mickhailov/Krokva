// KrokvaCard — the Civic Modernist container used by every dossier module,
// matching the app's KrokvaCard (eyebrow label + title + body).

/** At-a-glance traffic-light for a card, shown as a dot + short label in the
 *  eyebrow row so the reader can scan a column of cards without reading each. */
export interface CardStatus {
  tone: "good" | "warn" | "bad";
  label: string;
}

export function KrokvaCard({
  eyebrow,
  title,
  subtitle,
  accent,
  status,
  wide,
  collapsible,
  collapsedSummary,
  children,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  accent?: string;
  /** Traffic-light status chip in the eyebrow row (good / warn / bad). */
  status?: CardStatus;
  /** Span the full dashboard-grid width (maps, hero modules). */
  wide?: boolean;
  /** Render as a collapsed <details> (quiet/reference cards) that expands on
   *  click and while printing. Requires collapsedSummary for the closed line. */
  collapsible?: boolean;
  /** One-line status shown in the collapsed header (e.g. "All in range · 2025"). */
  collapsedSummary?: React.ReactNode;
  children: React.ReactNode;
}) {
  const statusChip = status ? (
    <span className={`card__status card__status--${status.tone}`}>
      <span className="card__status-dot" aria-hidden />
      {status.label}
    </span>
  ) : null;
  const className = [
    "card",
    wide ? "card--wide" : "",
    collapsible ? "card--collapsible" : "",
  ]
    .filter(Boolean)
    .join(" ");

  if (collapsible) {
    return (
      <details className={className}>
        <summary className="card__summary">
          <div style={{ minWidth: 0 }}>
            <div className="card__eyebrow" style={{ marginBottom: 6 }}>
              <span className="eyebrow">{eyebrow}</span>
              {accent ? <span className="pill">{accent}</span> : null}
              {statusChip}
            </div>
            <h2 className="card__title">{title}</h2>
            {collapsedSummary ? (
              <p className="card__subtitle card__collapsed-summary">{collapsedSummary}</p>
            ) : null}
          </div>
          <span className="card__chevron" aria-hidden>
            ›
          </span>
        </summary>
        <div className="card__body">
          {subtitle ? <p className="card__subtitle">{subtitle}</p> : null}
          <div style={{ marginTop: 12 }}>{children}</div>
        </div>
      </details>
    );
  }

  return (
    <section className={className}>
      <div className="card__eyebrow">
        <span className="eyebrow">{eyebrow}</span>
        {accent ? <span className="pill">{accent}</span> : null}
        {statusChip}
      </div>
      <h2 className="card__title">{title}</h2>
      {subtitle ? <p className="card__subtitle">{subtitle}</p> : null}
      <div style={{ marginTop: 12 }}>{children}</div>
    </section>
  );
}

/** Loaded-but-empty state (EmptyCardState). */
export function EmptyState({ label = "No data for this address." }: { label?: string }) {
  return <p className="state">{label}</p>;
}

/** Fetch failure state — distinct from empty, matching the app's rule. */
export function ErrorState({ label = "Database error — couldn't reach the data source." }: { label?: string }) {
  return <p className="state state--error">{label}</p>;
}

/** Key/value fact row. Renders nothing when the value is absent. */
export function Fact({ label, value }: { label: string; value?: string | number }) {
  if (value == null || value === "") return null;
  return (
    <div className="kv">
      <span className="kv__key">{label}</span>
      <span className="kv__val">{value}</span>
    </div>
  );
}
