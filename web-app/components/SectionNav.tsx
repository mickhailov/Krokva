"use client";

// Sticky section navigation for the report. Highlights the section currently in
// view (IntersectionObserver) and flags sections that hold a concern with a
// dot. Client-only so it can track scroll; hidden in print.

import { useEffect, useState } from "react";

export interface NavSection {
  id: string;
  title: string;
  hasConcern: boolean;
}

export function SectionNav({ sections }: { sections: NavSection[] }) {
  const [active, setActive] = useState<string>(sections[0]?.id ?? "");

  useEffect(() => {
    const els = sections
      .map((s) => document.getElementById(s.id))
      .filter((el): el is HTMLElement => el != null);
    if (!els.length) return;

    // Track which section headers are near the top of the viewport; the last
    // one to cross the trigger line is the active section.
    const visible = new Map<string, number>();
    const observer = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) visible.set(e.target.id, e.intersectionRatio);
          else visible.delete(e.target.id);
        }
        // Pick the visible section closest to the top of the document order.
        const firstVisible = sections.find((s) => visible.has(s.id));
        if (firstVisible) setActive(firstVisible.id);
      },
      { rootMargin: "-88px 0px -70% 0px", threshold: [0, 1] },
    );
    els.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, [sections]);

  return (
    <nav className="section-nav no-print" aria-label="Report sections">
      <div className="section-nav__inner">
        {sections.map((s) => (
          <a
            key={s.id}
            href={`#${s.id}`}
            className={`section-nav__link${active === s.id ? " is-active" : ""}`}
          >
            {s.hasConcern ? <span className="section-nav__dot" aria-label="has a flag" /> : null}
            {s.title}
          </a>
        ))}
      </div>
    </nav>
  );
}
