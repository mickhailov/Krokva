# Krokva

Krokva is a native SwiftUI iOS app for Canadian civic address dossiers. The name comes from Ukrainian `krokva`, the rafter beam that holds up a roof. The brand promise is the structural truth about an address, drawn from municipal open data.

## Current Scope

- iOS 17+, SwiftUI, Swift Charts, MapKit, SwiftData.
- Bundle ID: `ca.krokva.app`.
- Launch city: Winnipeg.
- Architecture is provider-based rather than hardcoded to Winnipeg.
- Phase-2 shells are included for Calgary, Toronto, Edmonton, Vancouver, and Ottawa.

## Architecture

`CityDataProvider` is the city contract. A provider declares dataset IDs, field mappings, attribution, address normalization, and its city bounding box. `SocrataProvider` and `CKANProvider` contain portal mechanics. City-specific providers keep city quirks close to the datasets.

Adding a city should be one provider file plus dataset mapping:

1. Add a provider under `Krokva/Cities/Providers`.
2. Fill `CityDatasets` and `FieldMappings`.
3. Implement or reuse an `AddressNormalizer`.
4. Register it in `CityRegistry`.
5. Add licence text to Settings if needed.

## Winnipeg Data Sources

All Winnipeg data is fetched from `https://data.winnipeg.ca/resource/{dataset}.json`.

- Assessment Parcels: `d4mq-wa44`
- Detailed Building Permits: `it4w-cpf4`
- Active Vacant Building By-law Compliance Orders: `qe3f-4r3j`
- LRS Speed Limits: `j5wn-5wz7`
- Pothole Repairs: `4mat-mb3w`
- Tree Inventory: `hfwk-jp4h`
- Short Term Rental Accommodations: `74hr-f8ai`
- WFPS Call Logs: `yg42-q284`
- Naloxone Administrations: `qd6b-q49i`
- Substance Use: `6x82-bz5y`

Contains information licensed under the Open Government Licence - Winnipeg.

## Guardrails

Krokva is not a real-estate marketplace, market valuation, safety-score tool, or redlining tool. Assessment values are municipal records, not market values. Public-health datasets are anonymized emergency-response records and must never be displayed as scores, grades, or risk predictions.

## Build

Generate the Xcode project:

```sh
xcodegen generate
```

Then open `Krokva.xcodeproj` in Xcode and run the `Krokva` scheme on an iOS 17+ simulator.
