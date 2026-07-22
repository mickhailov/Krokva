// Development module — recent development permits on nearby streets plus citywide
// development-permit processing times and intake outcomes. Port of
// fetchDevelopmentContext / fetchDevelopmentPermits / fetchDevelopmentProcessingTimes /
// fetchDevelopmentIntake from WinnipegProvider.

import { NormalizedAddress } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, parseCoordinate, rowDouble, rowInt, rowString } from "../row";
import {
  DevelopmentContextSummary,
  DevelopmentPermit,
  PermitIntakeMetric,
  PermitProcessingMetric,
} from "../types";
import { limitedStreetCores, parseDate, yearOffset } from "../util";

/**
 * Recent development permits on nearby streets — the PRIMARY fetch: it is allowed
 * to throw so the orchestrator marks the module failed on a transport/DB error.
 */
async function fetchDevelopmentPermits(
  address: NormalizedAddress,
  cores: string[],
  init?: { signal?: AbortSignal },
): Promise<DevelopmentPermit[]> {
  const nearbyCores = limitedStreetCores(cores);
  const streetClauses = nearbyCores.map((c) => `upper(street_name)='${escaped(c)}'`).join(" OR ");
  if (!streetClauses) return [];
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.developmentPermits,
    {
      where: `(${streetClauses}) AND issue_date > '${yearOffset(-2)}-01-01T00:00:00'`,
      order: "issue_date DESC",
      limit: 30,
    },
    init,
  );
  return rows.map((row) => {
    const addressParts = [
      rowString(row, "street_number"),
      rowString(row, "street_name"),
      rowString(row, "street_type"),
    ].filter((p): p is string => p != null);
    return {
      issuedDate: parseDate(rowString(row, "issue_date")),
      permitNumber: rowString(row, "permit_number"),
      type: rowString(row, "permit_type") ?? rowString(row, "permit_group") ?? "Development permit",
      subType: rowString(row, "sub_type"),
      workType: rowString(row, "work_type"),
      address: addressParts.length === 0 ? address.raw : addressParts.join(" "),
      status: rowString(row, "status"),
      coordinate: parseCoordinate(row),
    } satisfies DevelopmentPermit;
  });
}

/** Citywide processing-time metrics — enrichment, degrades to []. */
async function fetchDevelopmentProcessingTimes(
  init?: { signal?: AbortSignal },
): Promise<PermitProcessingMetric[]> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.developmentPermitProcessingTimes,
    { order: "month DESC", limit: 4 },
    init,
  ).catch(() => []);
  return rows.flatMap((row) => {
    const description = rowString(row, "description");
    const average = rowDouble(row, "average_number_of_business_days");
    if (description == null || average == null) return [];
    return [
      {
        description,
        month: parseDate(rowString(row, "month")),
        averageBusinessDays: average,
        serviceStandardDays: rowDouble(row, "city_service_level_standard"),
        percentMetTarget: rowDouble(row, "city_percent_met_target"),
      } satisfies PermitProcessingMetric,
    ];
  });
}

/** Citywide intake outcomes — enrichment, degrades to []. */
async function fetchDevelopmentIntake(
  init?: { signal?: AbortSignal },
): Promise<PermitIntakeMetric[]> {
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.developmentPermitIntake,
    { order: "month DESC", limit: 4 },
    init,
  ).catch(() => []);
  return rows.flatMap((row) => {
    const description = rowString(row, "description");
    const approved = rowInt(row, "number_approved");
    const notApproved = rowInt(row, "number_not_approved");
    if (description == null || approved == null || notApproved == null) return [];
    return [
      {
        description,
        month: parseDate(rowString(row, "month")),
        approved,
        notApproved,
      } satisfies PermitIntakeMetric,
    ];
  });
}

export async function fetchDevelopmentContext(
  address: NormalizedAddress,
  cores: string[],
  init?: { signal?: AbortSignal },
): Promise<DevelopmentContextSummary | undefined> {
  const [recentPermits, reviewProcessing, intake] = await Promise.all([
    fetchDevelopmentPermits(address, cores, init),
    fetchDevelopmentProcessingTimes(init),
    fetchDevelopmentIntake(init),
  ]);
  if (recentPermits.length === 0 && reviewProcessing.length === 0 && intake.length === 0) {
    return undefined;
  }
  return { recentPermits, reviewProcessing, intake };
}
