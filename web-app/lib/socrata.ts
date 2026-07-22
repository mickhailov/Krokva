// Socrata client — port of the app's SocrataProvider/OpenDataClient. Builds
// `/resource/{id}.json` URLs against the CDS facade and issues SoQL queries.
// Runs server-side only (Next.js route handlers / server components), which
// sidesteps browser CORS and keeps the data host out of the client bundle.

import { CDS_DOMAIN, CDS_SCHEME, DatasetKey, WINNIPEG_DATASETS } from "./datasets";

export type SoQLValue = string | number;
export type SocrataRow = Record<string, any>;

/** SoQL query parameters. Keys map to Socrata's $-prefixed params + column filters. */
export interface SoQLQuery {
  select?: string;
  where?: string;
  order?: string;
  limit?: number;
  offset?: number;
  group?: string;
  q?: string; // full-text
  /** Plain column=value equality filters. */
  filters?: Record<string, SoQLValue>;
}

function buildURL(datasetID: string, query: SoQLQuery): string {
  const url = new URL(`${CDS_SCHEME}://${CDS_DOMAIN}/resource/${datasetID}.json`);
  const p = url.searchParams;
  if (query.select) p.set("$select", query.select);
  if (query.where) p.set("$where", query.where);
  if (query.order) p.set("$order", query.order);
  if (query.limit != null) p.set("$limit", String(query.limit));
  if (query.offset != null) p.set("$offset", String(query.offset));
  if (query.group) p.set("$group", query.group);
  if (query.q) p.set("$q", query.q);
  if (query.filters) {
    for (const [k, v] of Object.entries(query.filters)) p.set(k, String(v));
  }
  return url.toString();
}

export class SocrataError extends Error {
  constructor(
    message: string,
    readonly datasetID: string,
    readonly status?: number,
  ) {
    super(message);
    this.name = "SocrataError";
  }
}

/**
 * Fetch rows from a dataset. Throws SocrataError on transport/HTTP failure so a
 * caller can distinguish a fetch error from a loaded-but-empty `[]` result —
 * the same distinction the app draws between "Database error" and "No data".
 */
/**
 * Per-fetch timeout. The CDS facade ignores column projection, so dense
 * within_circle / neighbourhood queries can return multi-MB geometry payloads
 * and occasionally stall. Like the app's 10s module timeout, a timed-out fetch
 * degrades to an empty result ("No data") rather than throwing ("Database
 * error") — a slow query is a completeness gap, not a source outage.
 */
export const FETCH_TIMEOUT_MS = 12_000;

export async function fetchDataset(
  datasetID: string,
  query: SoQLQuery = {},
  init?: { signal?: AbortSignal },
): Promise<SocrataRow[]> {
  const url = buildURL(datasetID, query);
  const timer = new AbortController();
  const timeout = setTimeout(() => timer.abort(), FETCH_TIMEOUT_MS);
  const signal = init?.signal
    ? anySignal([init.signal, timer.signal])
    : timer.signal;

  let res: Response;
  try {
    res = await fetch(url, {
      signal,
      headers: { Accept: "application/json" },
      // Report data is time-sensitive but not real-time; cache briefly at the
      // server to keep repeat report loads cheap.
      next: { revalidate: 60 * 30 },
    });
  } catch (e) {
    clearTimeout(timeout);
    // Our own timeout fired (not the caller cancelling): degrade to empty.
    if (timer.signal.aborted && !(init?.signal?.aborted ?? false)) return [];
    throw new SocrataError(`Network error fetching ${datasetID}: ${String(e)}`, datasetID);
  }
  clearTimeout(timeout);
  if (!res.ok) {
    throw new SocrataError(`HTTP ${res.status} fetching ${datasetID}`, datasetID, res.status);
  }
  try {
    return (await res.json()) as SocrataRow[];
  } catch (e) {
    // The facade returned a non-JSON body (e.g. an HTML error page).
    throw new SocrataError(`Non-JSON response from ${datasetID}: ${String(e)}`, datasetID);
  }
}

/** Combine several AbortSignals into one that aborts when any input aborts. */
function anySignal(signals: AbortSignal[]): AbortSignal {
  const controller = new AbortController();
  for (const s of signals) {
    if (s.aborted) {
      controller.abort();
      break;
    }
    s.addEventListener("abort", () => controller.abort(), { once: true });
  }
  return controller.signal;
}

/** Convenience: fetch by registry key. */
export function fetchByKey(
  key: DatasetKey,
  query: SoQLQuery = {},
  init?: { signal?: AbortSignal },
): Promise<SocrataRow[]> {
  return fetchDataset(WINNIPEG_DATASETS[key], query, init);
}

/** SoQL geo helpers, matching the joins documented in feature-opendata-expansion. */
export const soql = {
  /** Point-in-polygon test against a geometry column. */
  intersectsPoint(geomColumn: string, lon: number, lat: number): string {
    return `intersects(${geomColumn}, 'POINT(${lon} ${lat})')`;
  },
  /** Rows whose point column falls within `meters` of (lat, lon). */
  withinCircle(pointColumn: string, lat: number, lon: number, meters: number): string {
    return `within_circle(${pointColumn}, ${lat}, ${lon}, ${meters})`;
  },
  /** Escape a single-quoted SoQL string literal. */
  str(value: string): string {
    return `'${value.replace(/'/g, "''")}'`;
  },
};
