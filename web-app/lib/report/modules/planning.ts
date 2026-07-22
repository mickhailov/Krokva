// Planning context module — zoning by-law description for the parcel's zoning
// code plus nearby public planning notices. Ports fetchPlanningContext,
// fetchZoningDescription, and fetchPublicNotices from WinnipegProvider.

import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { escaped, parseCoordinate, rowString } from "../row";
import { PlanningContextSummary, PropertyAssessment, PublicNotice } from "../types";
import { distanceDescription, distanceMeters, parseDate, plainText } from "../util";

const NEARBY_RADIUS_METERS = 500;

/** Zoning short/long description for a zoning code (enrichment — degrades). */
async function fetchZoningDescription(
  zoningCode: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<{ short?: string; long?: string }> {
  if (!zoningCode || zoningCode.length === 0) return {};
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.zoningParcels,
    {
      select: "short_description,long_description",
      where: `upper(zoning)='${escaped(zoningCode.toUpperCase())}'`,
      limit: 1,
    },
    init,
  ).catch(() => []);
  const short = rows[0] ? rowString(rows[0], "short_description") : undefined;
  const long = rows[0] ? rowString(rows[0], "long_description") : undefined;
  // Don't repeat the same text in both slots — the card shows them separately.
  return { short, long: long === short ? undefined : long };
}

/** Nearby public planning notices — the primary geo fetch (allowed to throw). */
async function fetchPublicNotices(
  property: PropertyAssessment,
  init?: { signal?: AbortSignal },
): Promise<PublicNotice[]> {
  const subject = property.coordinate;
  if (!subject) return [];
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.publicNotices,
    {
      select: "notice_type,address,description,decision,meeting_date,point",
      where: soql.withinCircle("point", subject.latitude, subject.longitude, NEARBY_RADIUS_METERS),
      order: "meeting_date DESC",
      limit: 20,
    },
    init,
  );

  return rows
    .flatMap((row): { notice: PublicNotice; distance: number }[] => {
      const noticeType = rowString(row, "notice_type");
      if (!noticeType) return [];
      const coordinate = parseCoordinate(row);
      if (!coordinate) return [];
      const distance = distanceMeters(coordinate, subject);
      const notice: PublicNotice = {
        noticeType,
        address: rowString(row, "address") ?? "Address unavailable",
        description: plainText(rowString(row, "description") ?? rowString(row, "plain_language")),
        decision: rowString(row, "decision"),
        meetingDate: parseDate(rowString(row, "meeting_date")),
        distanceDescription: distanceDescription(distance),
        coordinate,
      };
      return [{ notice, distance }];
    })
    .sort((a, b) => a.distance - b.distance)
    .map((x) => x.notice);
}

export async function fetchPlanningContext(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<PlanningContextSummary | undefined> {
  if (!property) return undefined;

  const [zoningInfo, publicNotices] = await Promise.all([
    fetchZoningDescription(property.zoning, init),
    fetchPublicNotices(property, init),
  ]);

  if (
    property.zoning == null &&
    zoningInfo.short == null &&
    zoningInfo.long == null &&
    publicNotices.length === 0
  ) {
    return undefined;
  }

  return {
    zoningCode: property.zoning,
    zoningDescription: zoningInfo.short ?? zoningInfo.long,
    zoningIntent: zoningInfo.long,
    publicNotices,
  };
}
