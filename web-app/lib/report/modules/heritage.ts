// Heritage / historical resources module — designated heritage buildings within
// 500 m of the subject, split into the subject's own designation (if the civic
// number + street core match) and the nearest 8 others. Ports fetchHeritage
// from WinnipegProvider.

import { NormalizedAddress, streetCore } from "../../address";
import { WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset, soql } from "../../socrata";
import { parseCoordinate, rowString } from "../row";
import { HeritageBuilding, HeritageSummary, PropertyAssessment } from "../types";
import { distanceDescription, distanceMeters } from "../util";

export async function fetchHeritage(
  address: NormalizedAddress,
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<HeritageSummary | undefined> {
  const subject = property?.coordinate;
  if (!subject) return undefined;

  const rows = await fetchDataset(
    WINNIPEG_DATASETS.heritage,
    {
      select:
        "historical_name,street_number,street_name,grade,sub_code,construction_date,point",
      where: soql.withinCircle("point", subject.latitude, subject.longitude, 500),
      limit: 40,
    },
    init,
  );
  if (rows.length === 0) return undefined;

  const subjectNumber =
    address.civicNumber != null ? String(address.civicNumber) : undefined;
  const subjectStreet = streetCore(address.streetName);

  let subjectDesignation: HeritageBuilding | undefined;
  const nearby: { building: HeritageBuilding; distance: number }[] = [];

  for (const row of rows) {
    const name = rowString(row, "historical_name");
    if (!name) continue;
    const coordinate = parseCoordinate(row);
    if (!coordinate) continue;
    const distance = distanceMeters(coordinate, subject);
    const number = rowString(row, "street_number");
    const streetName = rowString(row, "street_name");
    const addressLabel = [number, streetName].filter((x): x is string => !!x).join(" ");
    const gradeRaw = rowString(row, "grade");
    const grade = gradeRaw === "N/A" ? undefined : gradeRaw;
    const building: HeritageBuilding = {
      name,
      address: addressLabel.length === 0 ? undefined : addressLabel,
      grade,
      listType: rowString(row, "sub_code"),
      constructionYear: rowString(row, "construction_date"),
      distanceDescription: distanceDescription(distance),
    };
    const isSubject =
      subjectNumber != null &&
      number === subjectNumber &&
      subjectStreet.length > 0 &&
      streetCore(streetName ?? "") === subjectStreet;
    if (isSubject && subjectDesignation == null) {
      subjectDesignation = building;
    } else {
      nearby.push({ building, distance });
    }
  }

  const nearbySorted = nearby
    .sort((a, b) => a.distance - b.distance)
    .slice(0, 8)
    .map((n) => n.building);

  if (subjectDesignation == null && nearbySorted.length === 0) return undefined;
  return { subjectDesignation, nearby: nearbySorted };
}
