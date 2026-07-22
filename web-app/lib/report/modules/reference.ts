// Static metro-wide reference figures — not per-address lookups. Ported verbatim
// from WinnipegProvider.winnipegRadon / winnipegRentalMarket. Filled only when an
// assessment resolved (i.e. the address is a real Winnipeg property).

import { RadonSummary, RentalMarketSummary } from "../types";

export const WINNIPEG_RADON: RadonSummary = {
  region: "Manitoba",
  percentAboveGuideline: 19,
  surveyName: "Health Canada Cross-Canada Survey of Radon Concentrations in Homes",
};

export const WINNIPEG_RENTAL_MARKET: RentalMarketSummary = {
  area: "Winnipeg CMA",
  year: 2025,
  vacancyRate: 2.8,
  brackets: [
    { bedrooms: "Bachelor", averageRent: 1000 },
    { bedrooms: "1 bedroom", averageRent: 1230 },
    { bedrooms: "2 bedroom", averageRent: 1480 },
    { bedrooms: "3 bedroom+", averageRent: 1700 },
  ],
};
