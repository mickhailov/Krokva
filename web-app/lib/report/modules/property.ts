// Property assessment module — port of WinnipegProvider.fetchAssessment plus its
// tax helpers. Resolves an address to the assessment row (value, facts,
// coordinate, neighbourhood) that the rest of the report keys off of.

import { NormalizedAddress, streetVariants } from "../../address";
import { fetchDataset, SocrataRow } from "../../socrata";
import { WINNIPEG_DATASETS } from "../../datasets";
import { escaped, parseCoordinate, rowDouble, rowInt, rowString } from "../row";
import { PropertyAssessment } from "../types";

const TAX_FIELDS = [
  "property_tax",
  "property_taxes",
  "annual_property_tax",
  "tax_amount",
  "taxes",
  "total_taxes",
  "gross_taxes",
  "gross_property_tax",
  "municipal_taxes",
  "net_property_tax",
];

function directPropertyTax(row: SocrataRow): number | undefined {
  for (const f of TAX_FIELDS) {
    const v = rowDouble(row, f);
    if (v != null) return v;
  }
  return undefined;
}

function isTaxableResidential(row: SocrataRow): boolean {
  const classFields = [
    rowString(row, "property_class_1"),
    rowString(row, "proposed_property_class_1"),
    rowString(row, "property_use_code"),
  ];
  const statusFields = [rowString(row, "status_1"), rowString(row, "proposed_status_1")];
  const isResidential = classFields.some(
    (v) => v != null && (/residential/i.test(v) || /ressd/i.test(v)),
  );
  const isTaxable = statusFields.some((v) => v != null && /taxable/i.test(v));
  return isResidential && isTaxable;
}

function estimatedPropertyTax(row: SocrataRow): number | undefined {
  const assessedValue = rowDouble(row, "total_assessed_value");
  if (assessedValue == null || assessedValue <= 0 || !isTaxableResidential(row)) return undefined;
  // Average 2026 residential combined mill rate across Winnipeg school divisions.
  const residentialPortion = 0.45;
  const averageCombinedResidentialMillRate = 27.405;
  return (assessedValue * residentialPortion * averageCombinedResidentialMillRate) / 1000;
}

function garageLabel(row: SocrataRow): string | undefined {
  const attached = rowString(row, "attached_garage")?.toLowerCase();
  const detached = rowString(row, "detached_garage")?.toLowerCase();
  if (attached === "yes" && detached === "yes") return "Attached + Detached";
  if (attached === "yes") return "Attached";
  if (detached === "yes") return "Detached";
  if (attached === "no" && detached === "no") return "No";
  return rowString(row, "garage");
}

const FALLBACK_SUFFIXES =
  "avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|lane|ln|line|court|crt|ct|trail|trl|close|bay|bv|terrace|terr|circle|cir|grove|grv|heights|hts|bend|glen|mews|run";

export async function fetchAssessment(
  address: NormalizedAddress,
  init?: { signal?: AbortSignal },
): Promise<PropertyAssessment | undefined> {
  const dataset = WINNIPEG_DATASETS.assessment;
  const streetClauses = streetVariants(address)
    .map((s) => `upper(street_name)='${escaped(s.toUpperCase())}'`)
    .join(" OR ");
  const clauses: string[] = [];
  if (address.civicNumber != null) clauses.push(`street_number='${address.civicNumber}'`);
  if (streetClauses.length) clauses.push(`(${streetClauses})`);
  if (clauses.length === 0) return undefined;

  let rows = await fetchDataset(dataset, { where: clauses.join(" AND "), limit: 1 }, init);

  if (rows.length === 0) {
    const streetOnly = address.streetName
      .replace(new RegExp(`\\b(${FALLBACK_SUFFIXES})\\b`, "gi"), "")
      .trim()
      .toUpperCase();
    if (streetOnly.length) {
      const likeClause = `upper(full_address) like '%${escaped(streetOnly)}%'`;
      const fallback =
        address.civicNumber != null ? `street_number='${address.civicNumber}' AND ${likeClause}` : likeClause;
      rows = await fetchDataset(dataset, { where: fallback, limit: 1 }, init);
    }
  }

  const row = rows[0];
  if (!row) return undefined;

  const direct = directPropertyTax(row);
  const estimated = direct == null ? estimatedPropertyTax(row) : undefined;
  const assessmentYear = rowInt(row, "assessment_year") ?? rowInt(row, "roll_year") ?? rowInt(row, "year");

  return {
    fullAddress: rowString(row, "full_address") ?? address.raw,
    neighbourhood: rowString(row, "neighbourhood_area") ?? "Unknown",
    useCode: rowString(row, "property_use_code"),
    totalAssessedValue: rowDouble(row, "total_assessed_value"),
    propertyTax: direct ?? estimated,
    propertyTaxIsEstimated: direct == null && estimated != null,
    livingArea: rowDouble(row, "total_living_area"),
    landArea: rowDouble(row, "assessed_land_area") ?? rowDouble(row, "land_area_in_sq_feet"),
    yearBuilt: rowInt(row, "year_built"),
    rooms: rowString(row, "rooms"),
    basement: rowString(row, "basement"),
    garage: garageLabel(row),
    airConditioning: rowString(row, "air_conditioning"),
    fireplace: rowString(row, "fire_place") ?? rowString(row, "fireplace"),
    swimmingPool: rowString(row, "pool") ?? rowString(row, "swimming_pool"),
    zoning: rowString(row, "zoning"),
    rollNumber: rowString(row, "roll_number"),
    houseStyle: rowString(row, "building_type") ?? rowString(row, "house_style"),
    storeys: undefined,
    coordinate: parseCoordinate(row),
    assessmentYear,
    propertyTaxYear: 2026,
  };
}
