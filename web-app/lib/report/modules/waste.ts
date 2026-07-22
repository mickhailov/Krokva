// Waste & winter module — garbage/recycling/yard-waste collection days, plow
// zone + next plow window, and any active snow-route parking ban. Ports
// fetchWasteCollection (+ fetchWasteRow, fetchPlowZoneRaw, fetchNextPlowWindow,
// fetchActiveSnowBan) from WinnipegProvider.

import { NormalizedAddress, streetCore } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql, SocrataRow } from "../../socrata";
import { escaped, rowString } from "../row";
import { PropertyAssessment, SnowBanInfo, WasteCollectionSummary } from "../types";
import { parseDate, plainText } from "../util";

/** ISO8601 timestamp without fractional seconds or trailing Z (WinnipegProvider.isoNow). */
function isoNow(): string {
  return new Date().toISOString().replace(/\.\d+Z$/, "");
}

/** Title-case each whitespace-separated word (Swift String.capitalized). */
function capitalized(value: string): string {
  return value
    .split(/(\s+)/)
    .map((part) => (/\s/.test(part) || part.length === 0 ? part : part[0].toUpperCase() + part.slice(1).toLowerCase()))
    .join("");
}

/** Format a plow-window start like Swift's "MMM d, h a" (e.g. "Jul 21, 3 PM"). */
function formatPlowWindow(iso: string): string {
  const d = new Date(iso);
  const month = new Intl.DateTimeFormat("en-US", { month: "short" }).format(d);
  const day = d.getDate();
  let hour = d.getHours();
  const meridiem = hour < 12 ? "AM" : "PM";
  hour = hour % 12;
  if (hour === 0) hour = 12;
  return `${month} ${day}, ${hour} ${meridiem}`;
}

/** The waste-collection row for this address — matched on full address, then civic + street core. */
async function fetchWasteRow(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<SocrataRow | undefined> {
  const dataset = WINNIPEG_DATASETS.wasteCollection;

  const full = property?.fullAddress;
  if (full && full.length > 0) {
    const rows = await fetchDataset(
      dataset,
      { where: `upper(combined_address)='${escaped(full.toUpperCase())}'`, limit: 1 },
      init,
    );
    if (rows[0]) return rows[0];
  }

  const civic = address.civicNumber;
  if (civic == null) return undefined;
  const core = escaped(streetCore(address.streetName));
  if (core.length === 0) return undefined;

  const rows = await fetchDataset(
    dataset,
    { where: `upper(combined_address) like '${civic} ${core}%'`, limit: 1 },
    init,
  );
  return rows[0];
}

/** Plow zone the address sits in (point-in-polygon). */
async function fetchPlowZoneRaw(
  coordinate: PropertyAssessment["coordinate"],
  init?: { signal?: AbortSignal },
): Promise<string | undefined> {
  if (!coordinate) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.plowZones,
    {
      select: "plow_zone",
      where: soql.intersectsPoint("the_geom", coordinate.longitude, coordinate.latitude),
      limit: 1,
    },
    init,
  ).catch(() => []);
  return rows[0] ? rowString(rows[0], "plow_zone") : undefined;
}

/** Next scheduled plow window for the given zone, formatted for display. */
async function fetchNextPlowWindow(
  zone: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<string | undefined> {
  if (!zone || zone.length === 0) return undefined;
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.plowZoneSchedule,
    {
      select: "shift_number,shift_start,shift_end,plow_zone",
      where: `upper(plow_zone)='${escaped(zone.toUpperCase())}' AND shift_end >= '${isoNow()}'`,
      order: "shift_start ASC",
      limit: 1,
    },
    init,
  ).catch(() => []);
  const start = rows[0] ? parseDate(rowString(rows[0], "shift_start")) : undefined;
  if (!start) return undefined;
  return formatPlowWindow(start);
}

/** Currently active snow-route parking ban, if any. */
async function fetchActiveSnowBan(init?: { signal?: AbortSignal }): Promise<SnowBanInfo | undefined> {
  const now = isoNow();
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.snowParkingBans,
    {
      select: "description,ban_start,ban_end",
      where: `ban_start <= '${now}' AND (ban_end IS NULL OR ban_end >= '${now}')`,
      order: "ban_start DESC",
      limit: 1,
    },
    init,
  ).catch(() => []);
  const row = rows[0];
  const description = row ? rowString(row, "description") : undefined;
  if (!description) return undefined;
  return {
    description: plainText(description) ?? description,
    start: parseDate(rowString(row!, "ban_start")),
    end: parseDate(rowString(row!, "ban_end")),
  };
}

export async function fetchWasteCollection(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<WasteCollectionSummary | undefined> {
  // Primary determining fetch — let it throw so the module is marked failed on
  // a real transport/HTTP error. The plow/snow-ban lookups are enrichment.
  const [row, plowZone, activeBan] = await Promise.all([
    fetchWasteRow(address, property, init),
    fetchPlowZoneRaw(property?.coordinate, init),
    fetchActiveSnowBan(init),
  ]);
  const nextWindow = await fetchNextPlowWindow(plowZone, init);

  const garbage = row ? rowString(row, "garbage_collection_day") : undefined;
  const recycle = row ? rowString(row, "recycle_collection_day") : undefined;
  const yard = row ? rowString(row, "yard_waste_collection_day") : undefined;

  if (garbage == null && recycle == null && yard == null && plowZone == null && activeBan == null) {
    return undefined;
  }

  return {
    garbageDay: garbage != null ? capitalized(garbage) : undefined,
    recycleDay: recycle != null ? capitalized(recycle) : undefined,
    yardWasteDay: yard != null ? capitalized(yard) : undefined,
    matchedAddress: row ? rowString(row, "combined_address") : undefined,
    plowZone,
    nextPlowWindow: nextWindow,
    activeSnowBan: activeBan,
  };
}
