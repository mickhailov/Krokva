// KrokvaCard — the Civic Modernist container used by every dossier module,
// matching the app's KrokvaCard (eyebrow label + title + body).

export function KrokvaCard({
  eyebrow,
  title,
  subtitle,
  accent,
  children,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  accent?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="card">
      <div className="card__eyebrow">
        <span className="eyebrow">{eyebrow}</span>
        {accent ? <span className="pill">{accent}</span> : null}
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
