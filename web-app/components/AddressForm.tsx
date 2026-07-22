"use client";

// Address form for the landing page. Submitting navigates client-side to
// /report?address=… so Next's app/report/loading.tsx shows instantly (the
// dossier is server-rendered and takes a few seconds to assemble). The button
// flips to a spinner on submit so the site never looks frozen.

import { useState } from "react";
import { useRouter } from "next/navigation";

export function AddressForm({ cta = "Build my report" }: { cta?: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  return (
    <form
      className="lp-form"
      onSubmit={(e) => {
        e.preventDefault();
        const address = String(new FormData(e.currentTarget).get("address") || "").trim();
        if (!address || loading) return;
        setLoading(true);
        router.push(`/report?address=${encodeURIComponent(address)}`);
      }}
    >
      <input
        name="address"
        required
        className="lp-form__input"
        placeholder="e.g. 50 Ash St, Winnipeg"
        autoComplete="off"
        aria-label="Winnipeg address"
        disabled={loading}
      />
      <button type="submit" className="lp-btn lp-btn--primary" disabled={loading}>
        {loading ? (
          <>
            <span className="lp-spinner" aria-hidden />
            Building…
          </>
        ) : (
          cta
        )}
      </button>
    </form>
  );
}
