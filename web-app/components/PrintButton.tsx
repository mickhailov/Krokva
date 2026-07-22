"use client";

// Save-as-PDF — triggers the browser's print dialog, which every browser can
// render straight to a PDF. The print stylesheet in globals.css lays the report
// out cleanly for the page. Hidden from the printed output itself (.no-print).

import { useEffect } from "react";

/** Expand every collapsed card while printing, then restore afterwards, so the
 *  PDF carries the full report even though quiet cards ship collapsed on screen. */
function useExpandOnPrint() {
  useEffect(() => {
    const toggled: HTMLDetailsElement[] = [];
    const expand = () => {
      document.querySelectorAll("details:not([open])").forEach((d) => {
        (d as HTMLDetailsElement).open = true;
        toggled.push(d as HTMLDetailsElement);
      });
    };
    const restore = () => {
      toggled.forEach((d) => (d.open = false));
      toggled.length = 0;
    };
    window.addEventListener("beforeprint", expand);
    window.addEventListener("afterprint", restore);
    return () => {
      window.removeEventListener("beforeprint", expand);
      window.removeEventListener("afterprint", restore);
    };
  }, []);
}

export function PrintButton() {
  useExpandOnPrint();
  const print = () => {
    // Expand collapsed cards before the (synchronous) print dialog opens, in
    // case beforeprint doesn't fire (older Safari); afterprint restores them.
    document.querySelectorAll("details:not([open])").forEach((d) => {
      (d as HTMLDetailsElement).open = true;
    });
    window.print();
  };
  return (
    <button
      type="button"
      className="no-print"
      onClick={print}
      style={{
        border: "1px solid var(--line)",
        background: "var(--surface)",
        color: "var(--ink)",
        borderRadius: "var(--radius-sm)",
        padding: "6px 12px",
        fontSize: 12,
        fontWeight: 700,
        letterSpacing: "0.04em",
        cursor: "pointer",
      }}
    >
      Save as PDF
    </button>
  );
}
