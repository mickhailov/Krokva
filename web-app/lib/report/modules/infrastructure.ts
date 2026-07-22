// Infrastructure module — street speed limit, pothole repairs, and public tree
// counts for the address's street. Ports fetchInfrastructure/fetchSpeedLimit/
// fetchPotholes/fetchTrees from WinnipegProvider.

import { NormalizedAddress, streetCore } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { escaped, rowDouble, rowInt, rowString } from "../row";
import { InfrastructureSummary } from "../types";

async function fetchSpeedLimit(address: NormalizedAddress, init?: { signal?: AbortSignal }) {
  const token = escaped(streetCore(address.streetName));
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.speedLimits,
    { where: `upper(street_name) like '${token}%'`, limit: 1 },
    init,
  ).catch(() => []);
  const row = rows[0];
  if (!row) return undefined;
  const raw = rowString(row, "speed_limit");
  if (raw) return `${raw} km/h`;
  return rowString(row, "speed_limit_description");
}

async function fetchPotholes(address: NormalizedAddress, init?: { signal?: AbortSignal }) {
  const token = escaped(streetCore(address.streetName));
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.potholes,
    { select: "sum(potholes) as cnt", where: `upper(street_name) like '${token}%'` },
    init,
  ).catch(() => []);
  return Math.trunc(rowDouble(rows[0] ?? {}, "cnt") ?? 0);
}

async function fetchTrees(address: NormalizedAddress, init?: { signal?: AbortSignal }) {
  const token = escaped(streetCore(address.streetName));
  const streetClause = `upper(street) like '${token}%'`;
  const [totalRows, taggedRows, speciesRows] = await Promise.all([
    fetchDataset(WINNIPEG_DATASETS.trees, { select: "count(*) as cnt", where: streetClause }, init).catch(() => []),
    fetchDataset(
      WINNIPEG_DATASETS.trees,
      { select: "count(*) as cnt", where: `${streetClause} AND ded_tag_number IS NOT NULL` },
      init,
    ).catch(() => []),
    fetchDataset(
      WINNIPEG_DATASETS.trees,
      {
        select: "common_name, count(*) as cnt",
        where: `${streetClause} AND common_name IS NOT NULL`,
        group: "common_name",
        order: "cnt DESC",
        limit: 1,
      },
      init,
    ).catch(() => []),
  ]);
  return {
    public: rowInt(totalRows[0] ?? {}, "cnt") ?? 0,
    tagged: rowInt(taggedRows[0] ?? {}, "cnt") ?? 0,
    topSpecies: rowString(speciesRows[0] ?? {}, "common_name"),
  };
}

export async function fetchInfrastructure(
  address: NormalizedAddress,
  init?: { signal?: AbortSignal },
): Promise<InfrastructureSummary> {
  const [speedLimit, potholes, trees] = await Promise.all([
    fetchSpeedLimit(address, init),
    fetchPotholes(address, init),
    fetchTrees(address, init),
  ]);
  return {
    speedLimit,
    potholes,
    publicTrees: trees.public,
    taggedTrees: trees.tagged,
    topTreeSpecies: trees.topSpecies,
  };
}
