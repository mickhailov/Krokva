// Home / address search. Submitting navigates to /report?address=… which
// server-renders the dossier (good for SEO and shareable URLs).

export default function HomePage() {
  return (
    <main className="wrap" style={{ paddingTop: 80, paddingBottom: 80 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
        <svg width="30" height="30" viewBox="0 0 32 32" aria-hidden>
          <path
            d="M6 25 L16 7 L26 25"
            fill="none"
            stroke="var(--gold)"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <circle cx="16" cy="18" r="1.6" fill="var(--gold)" />
        </svg>
        <span className="eyebrow">Krokva · Winnipeg</span>
      </div>
      <h1 style={{ fontSize: 40, fontWeight: 800, letterSpacing: "-0.02em", lineHeight: 1.1 }}>
        The foundation of every address.
      </h1>
      <p style={{ color: "var(--ink3)", marginTop: 12, fontSize: 17, maxWidth: 560 }}>
        A clear civic dossier for any Winnipeg address — assessment, taxes, permits, safety, amenities
        and more, assembled from municipal open data.
      </p>

      <form action="/report" method="get" style={{ marginTop: 28, display: "flex", gap: 10 }}>
        <input
          name="address"
          required
          placeholder="e.g. 510 Main St, Winnipeg"
          autoComplete="off"
          style={{
            flex: 1,
            padding: "14px 16px",
            fontSize: 16,
            borderRadius: "var(--radius-sm)",
            border: "1px solid var(--line)",
            background: "var(--surface)",
            color: "var(--ink)",
          }}
        />
        <button
          type="submit"
          style={{
            padding: "14px 22px",
            fontSize: 16,
            fontWeight: 700,
            borderRadius: "var(--radius-sm)",
            border: "none",
            background: "var(--gold)",
            color: "#1B1E25",
            cursor: "pointer",
          }}
        >
          Build report
        </button>
      </form>

      <p className="card__subtitle" style={{ marginTop: 16 }}>
        Try: <a href="/report?address=510%20Main%20St">510 Main St</a>
      </p>
    </main>
  );
}
