// Capital works module — active capital projects and infrastructure-plan funding
// matched to the address street core. Ports fetchCapitalWorks from WinnipegProvider.

import { NormalizedAddress, streetCore } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, rowDouble, rowString } from "../row";
import { CapitalProject, CapitalWorksSummary, PropertyAssessment } from "../types";
import { plainText } from "../util";

export async function fetchCapitalWorks(
  address: NormalizedAddress,
  _property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<CapitalWorksSummary | undefined> {
  const core = escaped(streetCore(address.streetName));
  if (core.length < 3) return undefined;

  // Primary determining fetch — let it throw so the orchestrator marks the module failed.
  const projectsRaw = await fetchDataset(
    WINNIPEG_DATASETS.capitalProjects,
    {
      select:
        "project_description,project_status,project_year,adopted_budget,amended_budget,report_date",
      where: `upper(project_description) like '%${core}%' AND upper(project_status) not like '%CLOSED%'`,
      order: "report_date DESC",
      limit: 8,
    },
    init,
  );

  // Auxiliary enrichment — degrade to [] on failure.
  const fundingRaw = await fetchDataset(
    WINNIPEG_DATASETS.infrastructureFunding,
    {
      select: "investment_name,project_details,capital_cost,funding_year,funded",
      where: `upper(project_details) like '%${core}%' OR upper(investment_name) like '%${core}%'`,
      limit: 5,
    },
    init,
  ).catch(() => []);

  const projects: CapitalProject[] = [];

  for (const row of projectsRaw) {
    const name = rowString(row, "project_description");
    if (!name) continue;
    projects.push({
      name,
      detail: rowString(row, "project_status"),
      status: rowString(row, "project_status"),
      budget: rowDouble(row, "amended_budget") ?? rowDouble(row, "adopted_budget"),
      year: rowString(row, "project_year"),
      funded: undefined,
    });
  }

  for (const row of fundingRaw) {
    const name = rowString(row, "investment_name");
    if (!name) continue;
    const funded = (rowDouble(row, "funded") ?? 0) > 0;
    projects.push({
      name,
      detail: plainText(rowString(row, "project_details")),
      status: undefined,
      budget: rowDouble(row, "capital_cost"),
      year: rowString(row, "funding_year"),
      funded,
    });
  }

  if (projects.length === 0) return undefined;
  return { projects: projects.slice(0, 8) };
}
