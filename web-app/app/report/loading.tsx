// Shown instantly while /report server-renders the dossier (assembling ~30
// municipal sources takes a few seconds). A branded shimmer skeleton that
// mirrors the real report layout — score block, KPI strip, card grid — so the
// wait reads as "working", not "frozen".

function SkeletonCard({ lines = 3 }: { lines?: number }) {
  return (
    <div className="card">
      <div className="skeleton" style={{ height: 12, width: 96, marginBottom: 14 }} />
      <div className="skeleton" style={{ height: 18, width: "70%", marginBottom: 12 }} />
      {Array.from({ length: lines }).map((_, i) => (
        <div
          key={i}
          className="skeleton"
          style={{ height: 12, width: `${90 - i * 12}%`, marginTop: 9 }}
        />
      ))}
    </div>
  );
}

export default function ReportLoading() {
  return (
    <main className="wrap wrap--wide" style={{ paddingTop: 28, paddingBottom: 64 }}>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: 8,
        }}
      >
        <span className="eyebrow">← Krokva</span>
        <span className="eyebrow">Winnipeg, MB</span>
      </div>

      {/* Working banner */}
      <div className="loading-head">
        <span className="lp-spinner" style={{ borderTopColor: "var(--gold-deep)" }} aria-hidden />
        <div>
          <div className="loading-head__title">
            Assembling the dossier
            <span className="loading-head__dots">
              <span>.</span>
              <span>.</span>
              <span>.</span>
            </span>
          </div>
          <div className="loading-head__sub">
            Pulling assessment, permits, safety and amenity data from ~30 municipal sources.
          </div>
        </div>
      </div>

      {/* Score block skeleton */}
      <div className="card" style={{ marginBottom: 14 }}>
        <div className="skeleton" style={{ height: 12, width: 140, marginBottom: 16 }} />
        <div style={{ display: "flex", gap: 24, flexWrap: "wrap", alignItems: "center" }}>
          <div className="skeleton" style={{ height: 72, width: 120 }} />
          <div style={{ flex: 1, minWidth: 220, display: "grid", gap: 10 }}>
            <div className="skeleton" style={{ height: 12, width: "80%" }} />
            <div className="skeleton" style={{ height: 12, width: "65%" }} />
            <div className="skeleton" style={{ height: 12, width: "72%" }} />
          </div>
        </div>
      </div>

      {/* KPI strip skeleton */}
      <div className="stat-row" style={{ marginBottom: 18 }}>
        {Array.from({ length: 6 }).map((_, i) => (
          <div className="stat" key={i}>
            <div className="skeleton" style={{ height: 10, width: 70 }} />
            <div className="skeleton" style={{ height: 20, width: "70%", marginTop: 8 }} />
            <div className="skeleton" style={{ height: 10, width: "55%", marginTop: 8 }} />
          </div>
        ))}
      </div>

      {/* Card grid skeleton */}
      <div className="report-grid">
        <SkeletonCard lines={4} />
        <SkeletonCard lines={3} />
        <SkeletonCard lines={5} />
        <SkeletonCard lines={3} />
        <SkeletonCard lines={4} />
        <SkeletonCard lines={2} />
      </div>
    </main>
  );
}
