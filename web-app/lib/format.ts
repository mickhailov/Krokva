// Presentation formatters — mirror the number/currency formatting the app's
// cards use (whole-dollar currency, comma-grouped areas).

export function currency(value?: number): string | undefined {
  if (value == null || !Number.isFinite(value)) return undefined;
  return new Intl.NumberFormat("en-CA", {
    style: "currency",
    currency: "CAD",
    maximumFractionDigits: 0,
  }).format(value);
}

export function area(value?: number, unit = "sq ft"): string | undefined {
  if (value == null || !Number.isFinite(value)) return undefined;
  return `${new Intl.NumberFormat("en-CA", { maximumFractionDigits: 0 }).format(value)} ${unit}`;
}

export function shortDate(iso?: string): string | undefined {
  if (!iso) return undefined;
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return undefined;
  return new Intl.DateTimeFormat("en-CA", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(new Date(t));
}

export function titleCase(value?: string): string | undefined {
  if (!value) return undefined;
  return value
    .toLowerCase()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}
