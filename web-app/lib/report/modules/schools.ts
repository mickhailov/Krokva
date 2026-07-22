// Nearby schools module — port of WinnipegProvider.fetchNearbySchools and its
// helpers. Prefers the CDS schools facade (/api/schools/nearby); otherwise
// collapses School Zone Signage points into one entry per school, enriches each
// against the Manitoba school directory (web.gov.mb.ca), and re-geocodes the
// directory addresses against the assessment roll.
//
// The School Zone Signage dataset fetch is the PRIMARY determining fetch — it is
// deliberately NOT wrapped in try/catch, so a transport/HTTP failure propagates
// and the orchestrator marks the module "Database error". The server facade,
// directory scrape, and geocoding are enrichment and degrade quietly.
//
// Parity note: the app also blends in Apple MapKit POI results
// (fetchMapKitNearbySchools). MapKit has no server-side equivalent, so that
// candidate source is dropped here — school-zone signage + directory only.

import { streetCore } from "../../address";
import { CDS_DOMAIN, CDS_SCHEME, WINNIPEG_DATASETS } from "../../datasets";
import { fetchDataset } from "../../socrata";
import { Coordinate, escaped, parseCoordinate, rowString } from "../row";
import { PropertyAssessment, SchoolAmenity } from "../types";
import { distanceDescription, distanceMeters, htmlDecoded } from "../util";

// MARK: - Public entry point

export async function fetchNearbySchools(
  property: PropertyAssessment | undefined,
  init?: { signal?: AbortSignal },
): Promise<SchoolAmenity[]> {
  const subject = property?.coordinate;
  if (!subject) return [];

  // 1. CDS schools facade — the preferred, pre-assembled source. Enrichment
  //    only, so it degrades to the signage path on any error.
  const serverSchools = await fetchServerNearbySchools(subject, property?.fullAddress, init).catch(() => null);
  if (serverSchools && serverSchools.length > 0) return serverSchools;

  // 2. School Zone Signage carries one Point per sign, so a single school appears
  //    as many rows. Pull every sign within range, then collapse to one entry per
  //    school using the averaged sign location as the school's approximate
  //    position. This is the primary determining fetch — let it throw.
  const rows = await fetchDataset(
    WINNIPEG_DATASETS.schools,
    {
      select: "school,street_name,location",
      where: `within_circle(location,${subject.latitude},${subject.longitude},3500) AND school IS NOT NULL`,
      limit: 900,
    },
    init,
  );

  interface Accumulator {
    latSum: number;
    lonSum: number;
    count: number;
    street?: string;
  }
  const bySchool = new Map<string, Accumulator>();
  for (const row of rows) {
    const rawName = rowString(row, "school")?.trim();
    const name = rawName ? repairedFrenchCivicName(rawName) : undefined;
    const coordinate = parseCoordinate(row);
    if (!name || !coordinate) continue;
    const acc = bySchool.get(name) ?? { latSum: 0, lonSum: 0, count: 0, street: undefined };
    acc.latSum += coordinate.latitude;
    acc.lonSum += coordinate.longitude;
    acc.count += 1;
    if (acc.street == null) acc.street = rowString(row, "street_name");
    bySchool.set(name, acc);
  }

  const signageCandidates: Candidate[] = [];
  for (const [name, acc] of bySchool) {
    if (acc.count <= 0) continue;
    const coordinate: Coordinate = {
      latitude: acc.latSum / acc.count,
      longitude: acc.lonSum / acc.count,
    };
    const distance = distanceMeters(coordinate, subject);
    signageCandidates.push({
      school: {
        name,
        address: acc.street ?? "Winnipeg, MB",
        distanceDescription: distanceDescription(distance),
        distanceMeters: distance,
        walkingTimeDescription: walkingTimeDescription(distance),
        programs: [],
        isAssigned: false,
        source: "Winnipeg school-zone signs",
        coordinate,
      },
      distance,
    });
  }

  // 3. MapKit candidates are unavailable server-side (parity gap) — signage only.
  const candidates = mergedSchoolCandidates(signageCandidates)
    .sort((a, b) => a.distance - b.distance)
    .slice(0, 24);

  // 4. Enrich each candidate against the Manitoba school directory.
  const enriched = await Promise.all(
    candidates.map(async (candidate): Promise<Candidate> => {
      const info = await fetchSchoolDirectoryInfo(candidate.school, init).catch(() => undefined);
      if (!info) return candidate;
      const school: SchoolAmenity = {
        ...candidate.school,
        address: info.address ?? candidate.school.address,
        grades: info.grades,
        schoolType: schoolTypeLabel(info.division),
        programs: programTags(info.program),
        source: "Manitoba school directory",
      };
      return { school, distance: candidate.distance };
    }),
  );

  // 5. Re-geocode the directory addresses against the assessment roll and
  //    recompute distances from the more precise building coordinate.
  const addressCoordinates = await geocodeSchoolAddresses(enriched.map((c) => c.school.address), init).catch(
    () => new Map<string, Coordinate>(),
  );
  const regeocoded = enriched.map((candidate): Candidate => {
    const coordinate = addressCoordinates.get(addressSearchKey(candidate.school.address));
    if (!coordinate) return candidate;
    const distance = distanceMeters(coordinate, subject);
    return {
      school: {
        ...candidate.school,
        coordinate,
        distanceMeters: distance,
        distanceDescription: distanceDescription(distance),
        walkingTimeDescription: walkingTimeDescription(distance),
      },
      distance,
    };
  });

  return regeocoded
    .sort((a, b) => a.distance - b.distance)
    .slice(0, 6)
    .map((c) => c.school);
}

interface Candidate {
  school: SchoolAmenity;
  distance: number;
}

// MARK: - CDS schools facade

interface ServerCoordinate {
  latitude: number;
  longitude: number;
}
interface ServerSchool {
  id?: string;
  name: string;
  address: string;
  distanceDescription: string;
  distanceMeters?: number;
  walkingTimeDescription?: string;
  grades?: string;
  schoolType?: string;
  programs?: string[];
  isAssigned?: boolean;
  source?: string;
  coordinate?: ServerCoordinate;
}
interface ServerSchoolsResponse {
  assigned: ServerSchool[];
  nearby: ServerSchool[];
}

async function fetchServerNearbySchools(
  subject: Coordinate,
  address: string | undefined,
  init?: { signal?: AbortSignal },
): Promise<SchoolAmenity[] | null> {
  const url = new URL(`${CDS_SCHEME}://${CDS_DOMAIN}/api/schools/nearby`);
  url.searchParams.set("lat", String(subject.latitude));
  url.searchParams.set("lon", String(subject.longitude));
  url.searchParams.set("radius", "3000");
  url.searchParams.set("limit", "8");
  if (address && address.trim().length > 0) url.searchParams.set("address", address);

  const res = await fetch(url.toString(), {
    signal: init?.signal,
    headers: { Accept: "application/json" },
    next: { revalidate: 60 * 30 },
  });
  if (!res.ok) return null;
  const decoded = (await res.json()) as ServerSchoolsResponse;
  return [...(decoded.assigned ?? []), ...(decoded.nearby ?? [])].map((row) => ({
    name: row.name,
    address: row.address,
    distanceDescription: row.distanceDescription,
    distanceMeters: row.distanceMeters,
    walkingTimeDescription: row.walkingTimeDescription,
    grades: row.grades,
    schoolType: row.schoolType,
    programs: row.programs ?? [],
    isAssigned: row.isAssigned ?? false,
    source: row.source,
    coordinate: row.coordinate
      ? { latitude: row.coordinate.latitude, longitude: row.coordinate.longitude }
      : undefined,
  }));
}

// MARK: - Manitoba school directory (web.gov.mb.ca)

interface SchoolDirectoryInfo {
  name: string;
  address?: string;
  grades?: string;
  division?: string;
  program?: string;
}

async function fetchSchoolDirectoryInfo(
  school: SchoolAmenity,
  init?: { signal?: AbortSignal },
): Promise<SchoolDirectoryInfo | undefined> {
  let ids: string[] = [];
  for (const term of schoolDirectorySearchTerms(school.name)) {
    ids.push(...(await fetchManitobaSchoolIDs(term, init).catch(() => [])));
  }
  ids = [...new Set(ids)];
  if (ids.length === 0) return undefined;

  const details = await Promise.all(
    ids.slice(0, 8).map((id) => fetchManitobaSchoolDetail(id, init).catch(() => undefined)),
  );
  const matches = details.filter((d): d is SchoolDirectoryInfo => d != null);

  const schoolName = normalizedSchoolName(school.name);
  const street = streetCore(school.address);
  return matches
    .filter((info) => {
      if (!info.address) return false;
      return (
        info.address.toLowerCase().includes("winnipeg") ||
        (info.division?.toLowerCase().includes("winnipeg") ?? false) ||
        streetCore(info.address) === street
      );
    })
    .sort(
      (lhs, rhs) =>
        scoreSchoolDirectoryMatch(rhs, schoolName, street) - scoreSchoolDirectoryMatch(lhs, schoolName, street),
    )[0];
}

async function fetchManitobaSchoolIDs(name: string, init?: { signal?: AbortSignal }): Promise<string[]> {
  const body = `SchoolText=${formEncoded(name)}&SchoolSearch=Submit`;
  const res = await fetch("https://web.gov.mb.ca/school/school?action=school", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded; charset=utf-8" },
    body,
    signal: init?.signal,
  });
  if (!res.ok) return [];
  const html = await res.text();
  return regexCaptures(/singleschool&name=(\d+)"/gi, html);
}

async function fetchManitobaSchoolDetail(
  id: string,
  init?: { signal?: AbortSignal },
): Promise<SchoolDirectoryInfo | undefined> {
  const res = await fetch(`https://web.gov.mb.ca/school/school?action=singleschool&name=${id}`, {
    signal: init?.signal,
  });
  if (!res.ok) return undefined;
  const html = await res.text();

  const rawName = firstRegexCapture(/<div class="sc_name">([^<]+)<\/div>/gi, html);
  const name = rawName
    ? htmlDecoded(rawName)
        .replace(/\s*#\d+$/, "")
        .trim()
    : undefined;
  if (!name) return undefined;

  const address = firstRegexCapture(/<div class="sc_name">[^<]+<\/div><div>([\s\S]*?)<br \/>/gi, html);
  const addressClean = address ? htmlDecoded(address).trim() : undefined;
  const city = firstRegexCapture(/<br \/>([^<]*Manitoba)<br \/>/gi, html);
  const cityClean = city ? htmlDecoded(city).trim() : undefined;
  const fullAddress = [addressClean, cityClean].filter((s): s is string => !!s && s.length > 0).join(", ");

  const gradesRaw = firstRegexCapture(/<strong>Grades:<\/strong>(?:&nbsp;|\s)*([^<]+)<br \/>/gi, html);
  const grades = gradesRaw ? htmlDecoded(gradesRaw).replace(/ to /g, "-").trim() : undefined;
  const programRaw = firstRegexCapture(/<strong>Program:<\/strong>(?:&nbsp;|\s)*([^<]+)<\/div>/gi, html);
  const program = programRaw ? htmlDecoded(programRaw).trim() : undefined;
  const divisionRaw = firstRegexCapture(/<div class="sc_div">\s*([^<]+)<\/div>/gi, html);
  const division = divisionRaw ? htmlDecoded(divisionRaw).trim() : undefined;

  return {
    name,
    address: fullAddress.length > 0 ? fullAddress : undefined,
    grades: grades && grades.length > 0 ? grades : undefined,
    division: division && division.length > 0 ? division : undefined,
    program: program && program.length > 0 ? program : undefined,
  };
}

// MARK: - Re-geocoding against the assessment roll

async function geocodeSchoolAddresses(
  addresses: string[],
  init?: { signal?: AbortSignal },
): Promise<Map<string, Coordinate>> {
  const keys = new Set(addresses.map(addressSearchKey).filter((k) => k.length > 0));
  const byStreet = new Map<string, Set<string>>();
  for (const key of keys) {
    const idx = key.indexOf(" ");
    if (idx < 0) continue;
    const num = key.slice(0, idx);
    const street = key.slice(idx + 1);
    if (!num || !street) continue;
    if (!byStreet.has(street)) byStreet.set(street, new Set());
    byStreet.get(street)!.add(num);
  }

  const result = new Map<string, Coordinate>();
  const groups = await Promise.all(
    [...byStreet.entries()].map(async ([street, nums]) => {
      const numList = [...nums].map((n) => `'${n}'`).join(",");
      const token = escaped(street);
      const rows = await fetchDataset(
        WINNIPEG_DATASETS.assessment,
        {
          select: "street_number,street_name,centroid_lat,centroid_lon,geometry",
          where: `upper(street_name)='${token}' AND street_number in (${numList})`,
          limit: 50,
        },
        init,
      ).catch(() => []);
      const pairs: [string, Coordinate][] = [];
      for (const row of rows) {
        const number = rowString(row, "street_number");
        const coordinate = parseCoordinate(row);
        if (!number || !coordinate) continue;
        pairs.push([`${number} ${street}`, coordinate]);
      }
      return pairs;
    }),
  );

  for (const pairs of groups) {
    for (const [key, coordinate] of pairs) {
      if (!result.has(key)) result.set(key, coordinate);
    }
  }
  return result;
}

// MARK: - Candidate merging + label helpers

function mergedSchoolCandidates(candidates: Candidate[]): Candidate[] {
  const byName = new Map<string, Candidate>();
  for (const candidate of candidates) {
    const key = normalizedSchoolName(candidate.school.name);
    if (!key) continue;
    const existing = byName.get(key);
    if (existing && existing.distance <= candidate.distance) continue;
    byName.set(key, candidate);
  }
  return [...byName.values()];
}

function walkingTimeDescription(meters: number): string {
  const minutes = Math.max(1, Math.ceil(meters / 80.0));
  return `${minutes} min walk`;
}

function schoolTypeLabel(division?: string): string | undefined {
  const d = division?.trim();
  if (!d) return undefined;
  const lower = d.toLowerCase();
  if (lower.includes("independent")) return "Independent";
  if (lower.includes("catholic")) return "Catholic";
  if (lower.includes("winnipeg school division")) return "Public · Winnipeg SD";
  if (lower.includes("louis riel school division")) return "Public · Louis Riel SD";
  return d.replace(/School Division/g, "SD").trim();
}

function programTags(value?: string): string[] {
  if (!value) return [];
  const raw = value
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  const tags: string[] = [];
  const append = (tag: string) => {
    if (!tags.includes(tag)) tags.push(tag);
  };
  for (const item of raw) {
    const lower = item.toLowerCase();
    if (lower.includes("early immersion")) append("Early Immersion");
    else if (lower.includes("late immersion")) append("Late Immersion");
    else if (lower.includes("middle immersion")) append("Middle Immersion");
    else if (lower.includes("french")) append("French");
    else if (lower.includes("english")) append("English");
    else if (lower.includes("montessori")) append("Montessori");
    else if (item.length <= 22) append(item);
  }
  return tags.slice(0, 4);
}

function schoolDirectorySearchTerms(name: string): string[] {
  const terms: string[] = [];
  const append = (value: string) => {
    const trimmed = value.trim();
    if (trimmed.length > 0 && !terms.includes(trimmed)) terms.push(trimmed);
  };
  append(name);
  const withoutParenthetical = name.replace(/\s*\([^)]*\)/g, "").trim();
  append(withoutParenthetical);
  append(replaceCaseInsensitive(withoutParenthetical, "Savior", "Saviour"));
  append(replaceCaseInsensitive(withoutParenthetical, "Saviour", "Savior"));
  return terms;
}

function addressSearchKey(address: string): string {
  const firstLine = address.split(",", 1)[0] ?? address;
  const trimmed = firstLine.trim();
  const idx = trimmed.indexOf(" ");
  if (idx < 0) return "";
  const num = trimmed.slice(0, idx);
  const rest = trimmed.slice(idx + 1);
  if (!/^\d+$/.test(num)) return "";
  const street = streetCore(rest);
  if (!street) return "";
  return `${num} ${street}`;
}

function normalizedSchoolName(value: string): string {
  return htmlDecoded(value)
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/^ecole\s+/i, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function scoreSchoolDirectoryMatch(info: SchoolDirectoryInfo, schoolName: string, street: string): number {
  const candidateName = normalizedSchoolName(info.name);
  let score = 0;
  if (candidateName === schoolName) score += 100;
  if (candidateName.includes(schoolName) || schoolName.includes(candidateName)) score += 30;
  if (info.address && streetCore(info.address) === street) score += 25;
  if (info.address?.toLowerCase().includes("winnipeg")) score += 10;
  if (info.division?.toLowerCase().includes("winnipeg")) score += 10;
  return score;
}

// MARK: - Small local utilities

/** String.repairedFrenchCivicName — recover French letters lost to bad decoding. */
function repairedFrenchCivicName(value: string): string {
  if (!value.includes("�")) return value;
  let result = value;
  if (result.startsWith("�cole")) result = "É" + result.slice(1);
  result = result.replace(/�re/g, "ère");
  result = result.replace(/�/g, "é");
  return result;
}

function replaceCaseInsensitive(value: string, search: string, replacement: string): string {
  return value.replace(new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "gi"), replacement);
}

function formEncoded(value: string): string {
  // Swift removes &+=? from the allowed set; encodeURIComponent already encodes
  // all of those (plus spaces), matching the app's form-body encoding.
  return encodeURIComponent(value);
}

function regexCaptures(pattern: RegExp, text: string): string[] {
  const out: string[] = [];
  for (const match of text.matchAll(pattern)) {
    if (match[1] != null) out.push(match[1]);
  }
  return out;
}

function firstRegexCapture(pattern: RegExp, text: string): string | undefined {
  return regexCaptures(pattern, text)[0];
}
