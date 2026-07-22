// Address normalisation — port of Krokva/Core/AddressNormalizer.swift and the
// `streetCore` helper in WinnipegProvider. Kept behaviourally identical so the
// same SoQL joins resolve the same rows.

export interface NormalizedAddress {
  raw: string;
  civicNumber?: number;
  streetName: string;
  cityName: string;
  provinceCode?: string;
}

/** DefaultAddressNormalizer.normalize */
export function normalizeAddress(input: string): NormalizedAddress {
  const parts = input.split(",").map((s) => s.trim());
  const streetPart = parts[0] ?? input;
  const numberMatch = streetPart.split(/\s+/)[0];
  const civicNumber = numberMatch && /^\d+$/.test(numberMatch) ? parseInt(numberMatch, 10) : undefined;
  const streetName = streetPart.replace(/^\d+\s+/, "").trim();
  const cityName = parts[1] ?? "";
  return { raw: input, civicNumber, streetName, cityName, provinceCode: undefined };
}

// Suffix set shared by streetCore. `line` is stripped as a suffix (see CLAUDE.md
// "Street suffix normalisation") so "8 Solstice Line" resolves to "SOLSTICE".
const STREET_CORE_SUFFIXES =
  "avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|lane|ln|line|court|crt|ct|trail|trl|close|bay|bv|terrace|terr|circle|cir|grove|grv|heights|hts|bend|glen|mews|run";

/** WinnipegProvider.streetCore — strip a trailing suffix, trim, uppercase. */
export function streetCore(name: string): string {
  const re = new RegExp(`\\s+(${STREET_CORE_SUFFIXES})\\.?$`, "i");
  return name.replace(re, "").trim().toUpperCase();
}

// streetVariants uses a slightly different (word-boundary) suffix list than
// streetCore — ported as-is.
const VARIANT_SUFFIXES =
  "avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|lane|ln|line|court|crt|ct|trail|trl|close|bay|bv|terrace|terr|circle|cir|grove|grv|heights|hts|run|bend|glen|mews";

/** WinnipegAddressNormalizer.streetVariants */
export function streetVariants(address: NormalizedAddress): string[] {
  const base = address.streetName;
  const upperNoSuffix = base
    .replace(new RegExp(`\\b(${VARIANT_SUFFIXES})\\b`, "gi"), "")
    .trim()
    .toUpperCase();
  const av = base.replace(/Avenue/gi, "Av");
  const ave = base.replace(/Avenue/gi, "Ave");
  const lane = base.replace(/\bLn\b/gi, "Lane");
  return Array.from(new Set([base, av, ave, lane, upperNoSuffix])).filter((s) => s.length > 0);
}
