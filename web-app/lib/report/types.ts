// Report model types — TypeScript port of ReportModels.swift. Dates are carried
// as ISO strings (JSON has no Date); coordinates use the shared Coordinate shape.
// Every module summary is optional on AddressReport: a nil/empty summary renders
// nothing, so thin/rural addresses degrade gracefully.

import { Coordinate } from "./row";

/** ReportModule — one per fan-out module; drives the "Database error" state. */
export type ReportModule =
  | "property"
  | "infrastructure"
  | "permits"
  | "vacantOrders"
  | "neighbourhoodValues"
  | "comparables"
  | "permitActivity"
  | "parks"
  | "transit"
  | "bylaw"
  | "development"
  | "river"
  | "library"
  | "serviceRequests"
  | "planning"
  | "streetAccess"
  | "emergency"
  | "publicHealth"
  | "policeCrime"
  | "civicContext"
  | "shortTermRentals"
  | "recreation"
  | "schools"
  | "waste"
  | "demographics"
  | "localGovernment"
  | "localBusiness"
  | "aquatics"
  | "traffic"
  | "neighbourhoodRisk"
  | "waterQuality"
  | "capitalWorks"
  | "facilityClosures"
  | "heritage"
  | "mosquito";

export interface PropertyAssessment {
  fullAddress: string;
  neighbourhood: string;
  postalCode?: string;
  useCode?: string;
  totalAssessedValue?: number;
  propertyTax?: number;
  propertyTaxIsEstimated: boolean;
  livingArea?: number;
  landArea?: number;
  yearBuilt?: number;
  rooms?: string;
  basement?: string;
  garage?: string;
  airConditioning?: string;
  fireplace?: string;
  swimmingPool?: string;
  zoning?: string;
  rollNumber?: string;
  houseStyle?: string;
  storeys?: string;
  coordinate?: Coordinate;
  assessmentYear?: number;
  propertyTaxYear?: number;
}

export interface AssessmentValueBin {
  bucket: string;
  count: number;
  midpoint: number;
}

export interface ComparableProperty {
  address: string;
  value: number;
  livingArea: number;
  yearBuilt?: number;
}

export interface BuildingPermit {
  issuedDate?: string;
  type: string;
  subType?: string;
  workType?: string;
  address: string;
  status?: string;
  isAdjacentStructural: boolean;
  coordinate?: Coordinate;
}

export interface YearCount {
  year: number;
  count: number;
  citywideAverage: number;
}

export interface VacantOrder {
  issuedDate?: string;
  address: string;
  orderType: string;
  distanceDescription?: string;
  coordinate?: Coordinate;
}

export interface InfrastructureSummary {
  speedLimit?: string;
  potholes: number;
  publicTrees: number;
  taggedTrees: number;
  topTreeSpecies?: string;
}

export interface ParkAmenity {
  parkID: string;
  name: string;
  distanceDescription: string;
  coordinate?: Coordinate;
  playgrounds: number;
  fields: number;
  courts: number;
  washrooms: number;
  benches: number;
}

export interface DogParkAmenity {
  parkID: string;
  name: string;
  distanceDescription: string;
  classification?: string;
  coordinate?: Coordinate;
}

export interface ParksSummary {
  nearestPark?: ParkAmenity;
  nearbyParks: ParkAmenity[];
  neighbourhoodParkCount: number;
  neighbourhoodHectares?: number;
  nearestDogPark?: DogParkAmenity;
}

export interface TransitStop {
  stopNumber: string;
  distanceDescription: string;
}

export interface TransitRouteSummary {
  routeNumber: string;
  routeName: string;
}

export interface TransitAccessSummary {
  nearestStop?: TransitStop;
  routes: TransitRouteSummary[];
  averageDeviationSeconds?: number;
  onTimePercentage?: number;
  passUpsLastYear: number;
  averageDailyBoardings?: number;
}

export interface IncidentBreakdown {
  incidentType: string;
  count: number;
  citywideAverage: number;
}

export interface BylawInvestigationSummary {
  neighbourhood: string;
  yearly: YearCount[];
  complaintTypes: IncidentBreakdown[];
}

export interface DevelopmentPermit {
  issuedDate?: string;
  permitNumber?: string;
  type: string;
  subType?: string;
  workType?: string;
  address: string;
  status?: string;
  coordinate?: Coordinate;
}

export interface PermitProcessingMetric {
  description: string;
  month?: string;
  averageBusinessDays: number;
  serviceStandardDays?: number;
  percentMetTarget?: number;
}

export interface PermitIntakeMetric {
  description: string;
  month?: string;
  approved: number;
  notApproved: number;
}

export interface DevelopmentContextSummary {
  recentPermits: DevelopmentPermit[];
  reviewProcessing: PermitProcessingMetric[];
  intake: PermitIntakeMetric[];
}

export interface RiverGaugeSummary {
  riverName: string;
  location: string;
  distanceDescription: string;
  jamesFeet?: number;
  geodeticFeet?: number;
  geodeticMetric?: number;
  readingDate?: string;
  notes?: string;
  coordinate?: Coordinate;
}

export interface LibraryAmenity {
  name: string;
  address: string;
  distanceDescription: string;
  wifi: boolean;
  accessibility: boolean;
  parkingLot: boolean;
  parkingStalls?: number;
  roomRentals: boolean;
  notes?: string;
  coordinate?: Coordinate;
}

export interface ServiceRequestMonth {
  year: number;
  month: number;
  count: number;
}

export interface ServiceRequestRecord {
  caseID?: string;
  interactionID?: string;
  channel?: string;
  subject?: string;
  reason?: string;
  type?: string;
  openDate?: string;
  closedDate?: string;
  status?: string;
  ward?: string;
  coordinate?: Coordinate;
}

export interface ServiceRequestSummary {
  neighbourhood: string;
  totalLastYear: number;
  openLastYear: number;
  closedLastYear: number;
  statusBreakdown: IncidentBreakdown[];
  channelBreakdown: IncidentBreakdown[];
  topSubjects: IncidentBreakdown[];
  topReasons: IncidentBreakdown[];
  topTypes: IncidentBreakdown[];
  monthlyTrend: ServiceRequestMonth[];
  recentRequests: ServiceRequestRecord[];
}

export interface PublicNotice {
  noticeType: string;
  address: string;
  description?: string;
  decision?: string;
  meetingDate?: string;
  distanceDescription?: string;
  coordinate?: Coordinate;
}

export interface PlanningContextSummary {
  zoningCode?: string;
  zoningDescription?: string;
  zoningIntent?: string;
  publicNotices: PublicNotice[];
}

export interface SchoolSpeedLimit {
  school: string;
  speedLimit: string;
  effectiveDays?: string;
  effectiveTime?: string;
}

export interface StreetDisruption {
  title: string;
  detail?: string;
  status?: string;
  startDate?: string;
  endDate?: string;
  distanceDescription?: string;
  coordinate?: Coordinate;
}

export interface StreetAccessSummary {
  pavementCondition?: string;
  pavementSurface?: string;
  roadType?: string;
  schoolSpeedLimit?: SchoolSpeedLimit;
  cyclingRoutesNearby: number;
  activeDisruptions: StreetDisruption[];
  activeLaneClosures: StreetDisruption[];
}

export interface EmergencyMonth {
  year: number;
  month: number;
  count: number;
}

export interface EmergencyIncidentRecord {
  incidentNumber?: string;
  incidentType: string;
  callTime?: string;
  closedTime?: string;
  motorVehicleIncident?: string;
  units?: string;
  ward?: string;
}

export interface EmergencySummary {
  neighbourhood: string;
  totalLastYear: number;
  motorVehicleLastYear: number;
  averageDurationMinutes?: number;
  yearlyCalls: YearCount[];
  monthlyTrend: EmergencyMonth[];
  last12Months: IncidentBreakdown[];
  breakdownByYear: Record<number, IncidentBreakdown[]>;
  wardBreakdown: IncidentBreakdown[];
  motorVehicleBreakdown: IncidentBreakdown[];
  unitBreakdown: IncidentBreakdown[];
  recentIncidents: EmergencyIncidentRecord[];
  citywideMedian?: number;
  neighbourhoodRank?: number;
  neighbourhoodCount?: number;
}

export interface HealthFacilityAccess {
  name: string;
  address?: string;
  city?: string;
  province?: string;
  driveMinutes?: number;
  avgWaitMinutes?: number;
  currentWaitMinutes?: number;
  waitingPatients?: number;
  treatingPatients?: number;
  waitTimeUpdatedAt?: string;
  waitTimeAttribution?: string;
}

export interface DefibrillatorAccess {
  name: string;
  locationDescription?: string;
  access?: string;
  indoor?: boolean;
  distanceDescription: string;
  coordinate?: Coordinate;
  source?: string;
}

export interface PublicHealthYear {
  year: number;
  neighbourhood: number;
  citywideAverage: number;
}

export interface PublicHealthSummary {
  yearlyEvents: PublicHealthYear[];
  ageGroups: IncidentBreakdown[];
  ageGroupsByYear: Record<number, IncidentBreakdown[]>;
  substances: IncidentBreakdown[];
  substancesByYear: Record<number, IncidentBreakdown[]>;
  nearestER?: HealthFacilityAccess;
  nearestWalkIn?: HealthFacilityAccess;
  walkInClinicsNearby?: number;
  nearestAED?: DefibrillatorAccess;
  aedsNearby?: number;
}

export interface PoliceCrimeYear {
  year: number;
  neighbourhood: number;
  citywideAverage: number;
}

export interface PoliceCrimeMonth {
  year: number;
  month: number;
}

export interface PoliceCrimeSummary {
  neighbourhood: string;
  latestMonth?: PoliceCrimeMonth;
  yearlyCounts: PoliceCrimeYear[];
  crimeTypes: IncidentBreakdown[];
  crimeTypesByYear: Record<number, IncidentBreakdown[]>;
  offenceTypes: IncidentBreakdown[];
  offenceTypesByYear: Record<number, IncidentBreakdown[]>;
}

export interface SchoolAmenity {
  name: string;
  address: string;
  distanceDescription: string;
  distanceMeters?: number;
  walkingTimeDescription?: string;
  grades?: string;
  schoolType?: string;
  programs: string[];
  isAssigned: boolean;
  source?: string;
  coordinate?: Coordinate;
}

export interface ShortTermRentalRecord {
  address: string;
  primaryStatus?: string;
  issuedDate?: string;
  ward?: string;
}

export interface ShortTermRentalSummary {
  total: number;
  primaryCount: number;
  nonPrimaryCount: number;
  recent: ShortTermRentalRecord[];
}

export interface AddressCivicContext {
  addressID?: string;
  ward?: string;
  neighbourhood?: string;
  postalCode?: string;
  plowZone?: string;
  schoolDivision?: string;
  schoolDivisionBoundaryName?: string;
  schoolDivisionCode?: string;
  schoolDivisionWard?: string;
  schoolDivisionWebsite?: string;
}

export interface RecreationComplex {
  name: string;
  address?: string;
  distanceDescription?: string;
  amenities: string[];
  coordinate?: Coordinate;
}

export interface CommunityCentre {
  name: string;
  address?: string;
  distanceDescription?: string;
  coordinate?: Coordinate;
}

export interface RecreationActivity {
  name: string;
  placeName?: string;
  category?: string;
  activityType?: string;
  status?: string;
  startDate?: string;
  endDate?: string;
  openSpaces?: string;
  publicURL?: string;
}

export interface RecreationSummary {
  nearestComplex?: RecreationComplex;
  complexes: RecreationComplex[];
  activities: RecreationActivity[];
  communityCentres: CommunityCentre[];
}

export interface SnowBanInfo {
  description: string;
  start?: string;
  end?: string;
}

export interface WasteCollectionSummary {
  garbageDay?: string;
  recycleDay?: string;
  yardWasteDay?: string;
  matchedAddress?: string;
  plowZone?: string;
  nextPlowWindow?: string;
  activeSnowBan?: SnowBanInfo;
}

export interface DemographicsSummary {
  boundaryName: string;
  totalPopulation?: number;
  childrenPercent?: number;
  seniorsPercent?: number;
  medianHouseholdIncome?: number;
  averageHouseholdSize?: number;
  immigrantPercent?: number;
  topNonOfficialLanguage?: string;
  commuteModes: IncidentBreakdown[];
  isHighPovertyArea?: boolean;
  giniIndex?: number;
}

export interface LocalGovernmentSummary {
  wardName?: string;
  councillor?: string;
  councillorPhone?: string;
  councillorWebsite?: string;
  communityCommittee?: string;
}

export interface LocalBusinessRecord {
  name: string;
  category?: string;
  distanceDescription?: string;
  coordinate?: Coordinate;
}

export interface LocalBusinessSummary {
  totalNearby: number;
  topCategories: IncidentBreakdown[];
  recent: LocalBusinessRecord[];
  patios: LocalBusinessRecord[];
}

export interface PoolAmenity {
  name: string;
  kind: string;
  address?: string;
  isOpen?: boolean;
  distanceDescription?: string;
  features: string[];
  website?: string;
  coordinate?: Coordinate;
}

export interface NamedAmenity {
  name: string;
  distanceDescription?: string;
  coordinate?: Coordinate;
}

export interface AquaticsAmenitiesSummary {
  pools: PoolAmenity[];
  walkwaysNearby: number;
  nearestWifi?: NamedAmenity;
}

export interface TrafficStudy {
  locationDescription: string;
  vehiclesCounted?: number;
  countDate?: string;
  direction?: string;
  distanceDescription?: string;
  countMetricLabel?: string;
  countSummaryUnit?: string;
  countNote?: string;
}

export interface TrafficSummary {
  streetStudy?: TrafficStudy;
  nearestPermanentStation?: TrafficStudy;
}

export interface RoomingHouseActivity {
  year: number;
  complaintDriven?: number;
  proactive?: number;
  inProgress?: number;
  completed?: number;
}

export interface NeighbourhoodRiskSummary {
  roomingHouse?: RoomingHouseActivity;
  vacantFireTrend: YearCount[];
  towingNearby: number;
  paidParkingNearby: number;
  nearestPaidParking?: string;
  graffitiReports?: number;
}

export interface WaterQualityReading {
  parameter: string;
  average?: number;
  minimum?: number;
  maximum?: number;
  units?: string;
}

export interface WaterQualitySummary {
  year?: number;
  area?: string;
  parameters: WaterQualityReading[];
}

export interface CapitalProject {
  name: string;
  detail?: string;
  status?: string;
  budget?: number;
  year?: string;
  funded?: boolean;
}

export interface CapitalWorksSummary {
  projects: CapitalProject[];
}

export interface FacilityClosureRecord {
  name: string;
  establishmentType?: string;
  reason?: string;
  closureDate?: string;
  reopenDate?: string;
}

export interface FacilityClosureSummary {
  closures: FacilityClosureRecord[];
}

export interface HeritageBuilding {
  name: string;
  address?: string;
  grade?: string;
  listType?: string;
  constructionYear?: string;
  distanceDescription?: string;
}

export interface HeritageSummary {
  subjectDesignation?: HeritageBuilding;
  nearby: HeritageBuilding[];
}

export interface MosquitoSummary {
  quadrant: string;
  quadrantCount?: number;
  cityWideAverage?: number;
  countDate?: string;
  foggingThresholdReached: boolean;
}

export interface RadonSummary {
  region: string;
  percentAboveGuideline: number;
  surveyName: string;
}

export interface RentBracket {
  bedrooms: string;
  averageRent?: number;
}

export interface RentalMarketSummary {
  area: string;
  year: number;
  vacancyRate?: number;
  brackets: RentBracket[];
}

export interface DatasetSource {
  name: string;
  datasetID: string;
  url: string;
}

export interface AddressReport {
  query: string;
  attribution: string;
  property?: PropertyAssessment;
  neighbourhoodValues: AssessmentValueBin[];
  comparables: ComparableProperty[];
  permits: BuildingPermit[];
  permitActivity: YearCount[];
  vacantOrders: VacantOrder[];
  infrastructure?: InfrastructureSummary;
  parks?: ParksSummary;
  transit?: TransitAccessSummary;
  bylaw?: BylawInvestigationSummary;
  development?: DevelopmentContextSummary;
  river?: RiverGaugeSummary;
  library?: LibraryAmenity;
  serviceRequests?: ServiceRequestSummary;
  planning?: PlanningContextSummary;
  streetAccess?: StreetAccessSummary;
  emergency?: EmergencySummary;
  publicHealth?: PublicHealthSummary;
  policeCrime?: PoliceCrimeSummary;
  shortTermRentals?: ShortTermRentalSummary;
  civicContext?: AddressCivicContext;
  recreation?: RecreationSummary;
  nearbySchools: SchoolAmenity[];
  waste?: WasteCollectionSummary;
  demographics?: DemographicsSummary;
  localGovernment?: LocalGovernmentSummary;
  localBusiness?: LocalBusinessSummary;
  aquatics?: AquaticsAmenitiesSummary;
  traffic?: TrafficSummary;
  neighbourhoodRisk?: NeighbourhoodRiskSummary;
  waterQuality?: WaterQualitySummary;
  capitalWorks?: CapitalWorksSummary;
  facilityClosures?: FacilityClosureSummary;
  heritage?: HeritageSummary;
  mosquito?: MosquitoSummary;
  radon?: RadonSummary;
  rentalMarket?: RentalMarketSummary;
  /** Modules whose fetch threw — render "Database error", not "No data". */
  failedModules: ReportModule[];
  /** True when the keystone lookups errored (source unreachable). */
  dataSourceUnavailable: boolean;
}
