// Report assembly — port of WinnipegProvider.fetchReport's parallel fan-out.
// Each module runs concurrently and degrades independently: a module that throws
// is recorded in `failedModules` (→ "Database error"); one that returns empty
// degrades quietly (→ "No data").

import { normalizeAddress } from "../address";
import { WINNIPEG_ATTRIBUTION } from "../datasets";
import { AddressReport, ReportModule } from "./types";

import { fetchAssessment } from "./modules/property";
import { fetchInfrastructure } from "./modules/infrastructure";
import { fetchEmergency } from "./modules/emergency";
import {
  fetchNearbyStreetCores,
  fetchPermitActivity,
  fetchPermits,
  fetchVacantOrders,
} from "./modules/permits";
import { fetchNeighbourhoodValues } from "./modules/neighbourhoodValues";
import { fetchComparables } from "./modules/comparables";
import { fetchParks } from "./modules/parks";
import { fetchTransit } from "./modules/transit";
import { fetchBylaw } from "./modules/bylaw";
import { fetchDevelopmentContext } from "./modules/development";
import { fetchRiverGauge } from "./modules/river";
import { fetchLibrary } from "./modules/library";
import { fetchServiceRequests } from "./modules/serviceRequests";
import { fetchPlanningContext } from "./modules/planning";
import { fetchStreetAccess } from "./modules/streetAccess";
import { fetchPublicHealth } from "./modules/publicHealth";
import { fetchPoliceCrime } from "./modules/policeCrime";
import { fetchCivicContext } from "./modules/civicContext";
import { fetchShortTermRentals } from "./modules/shortTermRentals";
import { fetchRecreation } from "./modules/recreation";
import { fetchNearbySchools } from "./modules/schools";
import { fetchWasteCollection } from "./modules/waste";
import { fetchDemographics } from "./modules/demographics";
import { fetchLocalGovernment } from "./modules/localGovernment";
import { fetchLocalBusiness } from "./modules/localBusiness";
import { fetchAquatics } from "./modules/aquatics";
import { fetchTraffic } from "./modules/traffic";
import { fetchNeighbourhoodRisk } from "./modules/neighbourhoodRisk";
import { fetchWaterQuality } from "./modules/waterQuality";
import { fetchCapitalWorks } from "./modules/capitalWorks";
import { fetchFacilityClosures } from "./modules/facilityClosures";
import { fetchHeritage } from "./modules/heritage";
import { fetchMosquito } from "./modules/mosquito";
import { WINNIPEG_RADON, WINNIPEG_RENTAL_MARKET } from "./modules/reference";

function emptyReport(query: string): AddressReport {
  return {
    query,
    attribution: WINNIPEG_ATTRIBUTION,
    property: undefined,
    neighbourhoodValues: [],
    comparables: [],
    permits: [],
    permitActivity: [],
    vacantOrders: [],
    nearbySchools: [],
    failedModules: [],
    dataSourceUnavailable: false,
  };
}

/** Run a module, recording failure without aborting the rest of the report. */
async function runModule<T>(
  module: ReportModule,
  failed: Set<ReportModule>,
  op: () => Promise<T>,
): Promise<T | undefined> {
  try {
    return await op();
  } catch (e) {
    if (process.env.KROKVA_DEBUG) console.error(`[module:${module}]`, e);
    failed.add(module);
    return undefined;
  }
}

export async function buildWinnipegReport(query: string, signal?: AbortSignal): Promise<AddressReport> {
  const address = normalizeAddress(query);
  const failed = new Set<ReportModule>();
  const report = emptyReport(query);
  const init = { signal };

  // Keystone: assessment resolves the coordinate + neighbourhood the rest key off.
  const infrastructureP = runModule("infrastructure", failed, () => fetchInfrastructure(address, init));
  report.property = await runModule("property", failed, () => fetchAssessment(address, init));
  const property = report.property;
  const neighbourhood = property?.neighbourhood;
  const coordinate = property?.coordinate;

  // Nearby street cores gate the proximity fetches; resolved from the assessment.
  const streetCores = await runModule("property", failed, () =>
    fetchNearbyStreetCores(address, property, init),
  );
  const cores = streetCores ?? [];

  const r = <T>(m: ReportModule, op: () => Promise<T>) => runModule(m, failed, op);
  const [
    infrastructure,
    permits,
    vacantOrders,
    permitActivity,
    emergency,
    neighbourhoodValues,
    comparables,
    parks,
    transit,
    bylaw,
    development,
    river,
    library,
    serviceRequests,
    planning,
    streetAccess,
    publicHealth,
    policeCrime,
    civicContext,
    shortTermRentals,
    recreation,
    nearbySchools,
    waste,
    demographics,
    localGovernment,
    localBusiness,
    aquatics,
    traffic,
    neighbourhoodRisk,
    waterQuality,
    capitalWorks,
    facilityClosures,
    heritage,
    mosquito,
  ] = await Promise.all([
    infrastructureP,
    r("permits", () => fetchPermits(address, cores, init)),
    r("vacantOrders", () => fetchVacantOrders(cores, init)),
    r("permitActivity", () => fetchPermitActivity(neighbourhood, init)),
    r("emergency", () => fetchEmergency(neighbourhood, init)),
    r("neighbourhoodValues", () => fetchNeighbourhoodValues(neighbourhood, init)),
    r("comparables", () => fetchComparables(address, property, init)),
    r("parks", () => fetchParks(property, init)),
    r("transit", () => fetchTransit(property, init)),
    r("bylaw", () => fetchBylaw(neighbourhood, init)),
    r("development", () => fetchDevelopmentContext(address, cores, init)),
    r("river", () => fetchRiverGauge(property, init)),
    r("library", () => fetchLibrary(property, init)),
    r("serviceRequests", () => fetchServiceRequests(neighbourhood, init)),
    r("planning", () => fetchPlanningContext(property, init)),
    r("streetAccess", () => fetchStreetAccess(address, property, init)),
    r("publicHealth", () => fetchPublicHealth(neighbourhood, coordinate, init)),
    r("policeCrime", () => fetchPoliceCrime(neighbourhood, init)),
    r("civicContext", () => fetchCivicContext(address, property, init)),
    r("shortTermRentals", () => fetchShortTermRentals(address, cores, init)),
    r("recreation", () => fetchRecreation(property, init)),
    r("schools", () => fetchNearbySchools(property, init)),
    r("waste", () => fetchWasteCollection(address, property, init)),
    r("demographics", () => fetchDemographics(address, property, init)),
    r("localGovernment", () => fetchLocalGovernment(address, property, init)),
    r("localBusiness", () => fetchLocalBusiness(property, init)),
    r("aquatics", () => fetchAquatics(property, init)),
    r("traffic", () => fetchTraffic(address, property, init)),
    r("neighbourhoodRisk", () => fetchNeighbourhoodRisk(property, init)),
    r("waterQuality", () => fetchWaterQuality(init)),
    r("capitalWorks", () => fetchCapitalWorks(address, property, init)),
    r("facilityClosures", () => fetchFacilityClosures(address, property, init)),
    r("heritage", () => fetchHeritage(address, property, init)),
    r("mosquito", () => fetchMosquito(property, init)),
  ]);

  report.infrastructure = infrastructure;
  report.permits = permits ?? [];
  report.vacantOrders = vacantOrders ?? [];
  report.permitActivity = permitActivity ?? [];
  report.emergency = emergency;
  report.neighbourhoodValues = neighbourhoodValues ?? [];
  report.comparables = comparables ?? [];
  report.parks = parks;
  report.transit = transit;
  report.bylaw = bylaw;
  report.development = development;
  report.river = river;
  report.library = library;
  report.serviceRequests = serviceRequests;
  report.planning = planning;
  report.streetAccess = streetAccess;
  report.publicHealth = publicHealth;
  report.policeCrime = policeCrime;
  report.civicContext = civicContext;
  report.shortTermRentals = shortTermRentals;
  report.recreation = recreation;
  report.nearbySchools = nearbySchools ?? [];
  report.waste = waste;
  report.demographics = demographics;
  report.localGovernment = localGovernment;
  report.localBusiness = localBusiness;
  report.aquatics = aquatics;
  report.traffic = traffic;
  report.neighbourhoodRisk = neighbourhoodRisk;
  report.waterQuality = waterQuality;
  report.capitalWorks = capitalWorks;
  report.facilityClosures = facilityClosures;
  report.heritage = heritage;
  report.mosquito = mosquito;

  // Radon and rental-market figures are metro-wide references, filled statically
  // (not fetched) whenever the address resolved to a real property.
  if (report.property) {
    report.radon = WINNIPEG_RADON;
    report.rentalMarket = WINNIPEG_RENTAL_MARKET;
  }

  // Backfill postal code from civic context (the assessment feed has none).
  if (report.property && report.property.postalCode == null && civicContext?.postalCode) {
    report.property.postalCode = civicContext.postalCode;
  }

  // The whole data source counts as unavailable only when the keystone lookups
  // errored (transport failure), not merely when the address wasn't found.
  report.dataSourceUnavailable =
    (failed.has("property") || failed.has("civicContext")) &&
    report.property == null &&
    report.civicContext == null;
  report.failedModules = [...failed];
  return report;
}
