"use client";

// Save-as-PDF — triggers the browser's print dialog, which every browser can
// render straight to a PDF. The print stylesheet in globals.css lays the report
// out cleanly for the page. Hidden from the printed output itself (.no-print).

export function PrintButton() {
  return (
    <button
      type="button"
      className="no-print"
      onClick={() => window.print()}
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
