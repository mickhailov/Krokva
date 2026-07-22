// Landing / home. The address form submits GET to /report?address=… which
// server-renders the dossier (good for SEO and shareable URLs). Two CTAs:
// "See a sample report" (a real rendered dossier) and "Build a report" (free,
// no payment yet — just enter an address).

import Link from "next/link";

// A real, well-populated residential dossier used as the public sample.
const SAMPLE_ADDRESS = "50 Ash St";
const SAMPLE_HREF = `/report?address=${encodeURIComponent(SAMPLE_ADDRESS)}`;

function Logo({ size = 26 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden>
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
  );
}

// The six report sections, framed as the questions a buyer actually asks.
const FEATURES: {
  q: string;
  title: string;
  icon: React.ReactNode;
  points: string[];
}[] = [
  {
    q: "What's it worth?",
    title: "Value & property",
    icon: <IconTag />,
    points: [
      "Assessed value & estimated property tax",
      "Year built, size, structure & lot facts",
      "Sold comparables and $/sq ft",
      "Where it sits in the neighbourhood value band",
    ],
  },
  {
    q: "Anything flagged here?",
    title: "Permits & development",
    icon: <IconFlag />,
    points: [
      "Building, development & trade permits",
      "Vacant-building orders and bylaw files",
      "Nearby planning & rezoning notices",
      "Registered short-term rentals",
    ],
  },
  {
    q: "Is it safe here?",
    title: "Safety & health",
    icon: <IconShield />,
    points: [
      "Police crime vs. the citywide average",
      "Fire & emergency call history",
      "Public-health signals nearby",
      "Neighbourhood risk & enforcement",
    ],
  },
  {
    q: "What's daily life like?",
    title: "Daily living",
    icon: <IconHome />,
    points: [
      "Garbage, recycling & snow-plow schedule",
      "Who lives here — census demographics",
      "Your ward councillor & committee",
      "Licensed businesses within 500 m",
    ],
  },
  {
    q: "Getting around?",
    title: "Schools & travel",
    icon: <IconRoute />,
    points: [
      "Nearest schools & catchments",
      "Transit routes and on-time rate",
      "Cycling network & traffic counts",
      "Parks, pools, library & recreation",
    ],
  },
  {
    q: "Good to know",
    title: "Reference & utilities",
    icon: <IconBook />,
    points: [
      "Drinking-water quality readings",
      "Radon zone & rental-market context",
      "Heritage status",
      "Capital projects on your street",
    ],
  },
];

const STEPS = [
  {
    title: "Enter any Winnipeg address",
    body: "No account, no card. Just type the address you want to understand.",
  },
  {
    title: "We assemble the civic record",
    body: "Krokva pulls ~30 municipal open-data sources — assessment, permits, safety, transit and more — and scores them.",
  },
  {
    title: "Read it, share it, save the PDF",
    body: "A single dossier with a House Score, plain-language verdict and a shareable link. Print to PDF in one click.",
  },
];

function AddressForm({ cta = "Build my report" }: { cta?: string }) {
  return (
    <form action="/report" method="get" className="lp-form">
      <input
        name="address"
        required
        className="lp-form__input"
        placeholder="e.g. 50 Ash St, Winnipeg"
        autoComplete="off"
        aria-label="Winnipeg address"
      />
      <button type="submit" className="lp-btn lp-btn--primary">
        {cta}
      </button>
    </form>
  );
}

export default function HomePage() {
  return (
    <>
      <div className="lp">
        {/* Nav */}
        <nav className="lp-nav">
          <Link href="/" className="lp-brand">
            <Logo />
            <span className="lp-brand__name">Krokva</span>
          </Link>
          <div className="lp-nav__links">
            <Link href={SAMPLE_HREF} className="lp-navlink">
              Sample report
            </Link>
            <a href="#inside" className="lp-navlink">
              What's inside
            </a>
            <a href="#order" className="lp-btn lp-btn--ghost lp-btn--sm">
              Build a report
            </a>
          </div>
        </nav>

        {/* Hero */}
        <header className="lp-hero">
          <span className="lp-badge">
            <span className="lp-badge__dot" />
            Winnipeg · free while in beta
          </span>
          <h1 className="lp-headline">
            The foundation of <em>every address.</em>
          </h1>
          <p className="lp-sub">
            Before you buy, rent or make an offer, know the whole civic story of a home —
            assessment, taxes, permits, safety, schools and amenities — in one clear dossier
            built from Winnipeg&rsquo;s open data.
          </p>

          <div id="order">
            <AddressForm />
          </div>

          <div className="lp-secondary">
            <Link href={SAMPLE_HREF}>See a sample report →</Link>
            <span>or type your own address above</span>
          </div>

          <div className="lp-trust">
            <span>
              <IconCheck /> No signup, no payment
            </span>
            <span>
              <IconCheck /> ~30 municipal data sources
            </span>
            <span>
              <IconCheck /> Ready in seconds · shareable link
            </span>
          </div>
        </header>

        {/* What's inside */}
        <section id="inside" className="lp-section">
          <div className="lp-section__eyebrow">What&rsquo;s inside a report</div>
          <h2 className="lp-section__title">Every question, one dossier</h2>
          <p className="lp-section__lead">
            Each report answers the six questions that actually decide a home — organised so the
            things that matter surface first.
          </p>

          <div className="lp-features">
            {FEATURES.map((f) => (
              <article className="lp-feature" key={f.title}>
                <div className="lp-feature__icon">{f.icon}</div>
                <div className="lp-feature__q">{f.q}</div>
                <div className="lp-feature__title">{f.title}</div>
                <ul className="lp-feature__list">
                  {f.points.map((p) => (
                    <li key={p}>{p}</li>
                  ))}
                </ul>
              </article>
            ))}
          </div>
        </section>

        {/* How it works */}
        <section className="lp-section">
          <div className="lp-section__eyebrow">How it works</div>
          <h2 className="lp-section__title">Address in, dossier out</h2>

          <div className="lp-steps">
            {STEPS.map((s, i) => (
              <div className="lp-step" key={s.title}>
                <div className="lp-step__num">{i + 1}</div>
                <div className="lp-step__title">{s.title}</div>
                <div className="lp-step__body">{s.body}</div>
              </div>
            ))}
          </div>

          {/* Sample band */}
          <div className="lp-band">
            <div>
              <div className="lp-band__title">See exactly what you get</div>
              <p className="lp-band__sub">
                A full sample dossier for a real Winnipeg home — House Score, assessment, safety,
                schools and 30+ cards. No address required.
              </p>
            </div>
            <div className="lp-band__actions">
              <Link href={SAMPLE_HREF} className="lp-btn lp-btn--primary">
                View sample report →
              </Link>
            </div>
          </div>
        </section>

        {/* Final CTA */}
        <section className="lp-final">
          <div className="lp-section__eyebrow">Order a report</div>
          <h2 className="lp-final__title">Build a report for your address</h2>
          <p className="lp-sub" style={{ marginTop: 12 }}>
            Free while we&rsquo;re in beta — no card, no account.
          </p>
          <AddressForm cta="Build report" />
          <p className="lp-trust" style={{ marginTop: 14 }}>
            <span>
              Try&nbsp;
              <Link href={SAMPLE_HREF} style={{ color: "var(--gold-deep)", fontWeight: 650 }}>
                {SAMPLE_ADDRESS}
              </Link>
            </span>
          </p>
        </section>

        {/* Footer */}
        <footer className="lp-footer">
          <span className="lp-brand" style={{ gap: 8 }}>
            <Logo size={20} />
            <span style={{ fontWeight: 700, color: "var(--ink2)" }}>Krokva</span>
          </span>
          <span>Built from City of Winnipeg &amp; partner open data · Winnipeg, MB</span>
        </footer>
      </div>
    </>
  );
}

/* --- Inline icons (stroke = currentColor, inherits the tile colour) --- */
function IconTag() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0l-7.2-7.2A2 2 0 0 1 2.8 12V4.8A2 2 0 0 1 4.8 2.8H12a2 2 0 0 1 1.4.6l7.2 7.2a2 2 0 0 1 0 2.8Z" />
      <circle cx="7.5" cy="7.5" r="1.2" />
    </svg>
  );
}
function IconFlag() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V4s-1 1-4 1-5-2-8-2-4 1-4 1Z" />
      <line x1="4" y1="22" x2="4" y2="15" />
    </svg>
  );
}
function IconShield() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
      <path d="m9 12 2 2 4-4" />
    </svg>
  );
}
function IconHome() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 10.5 12 3l9 7.5" />
      <path d="M5 9.5V21h14V9.5" />
      <path d="M9 21v-6h6v6" />
    </svg>
  );
}
function IconRoute() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="6" cy="19" r="2.4" />
      <circle cx="18" cy="5" r="2.4" />
      <path d="M8.4 19H14a3.5 3.5 0 0 0 0-7H10a3.5 3.5 0 0 1 0-7h5.6" />
    </svg>
  );
}
function IconBook() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 4.5A1.5 1.5 0 0 1 5.5 3H20v15H5.5A1.5 1.5 0 0 0 4 19.5Z" />
      <path d="M4 19.5A1.5 1.5 0 0 1 5.5 21H20" />
    </svg>
  );
}
function IconCheck() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--sage)" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
      <path d="m5 12 4.5 4.5L19 7" />
    </svg>
  );
}
