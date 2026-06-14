# Krokva

Krokva is a native SwiftUI iOS app for Canadian civic address dossiers. The name comes from Ukrainian *krokva* (кро́ква) — the rafter beam that holds up a roof. The brand promise is the structural truth about an address, drawn from municipal open data.

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15.2+ |
| iOS Deployment Target | 17.0+ |
| Swift | 5.9 |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | 2.40+ |

Install XcodeGen via Homebrew:

```sh
brew install xcodegen
```

## Quick Start

```sh
git clone git@github.com:mickhailov/Krokva.git
cd Krokva
xcodegen generate
open Krokva.xcodeproj
```

Select the **Krokva** scheme, choose an iOS 17+ simulator, and press Run.

## Project Structure

```
Krokva/
├── App/
│   ├── Branding/          # Design tokens, colours, typography
│   ├── KrokvaApp.swift    # App entry point
│   └── RootTabView.swift  # Tab bar root
├── Cities/
│   ├── CityDataProvider.swift   # Protocol + CityDatasets / FieldMappings structs
│   ├── CityRegistry.swift       # Singleton list of all providers
│   └── Providers/
│       ├── SocrataProvider.swift   # Socrata Open Data portal mechanics
│       ├── CKANProvider.swift      # CKAN portal mechanics
│       ├── WinnipegProvider.swift  # Live implementation
│       └── StubProviders.swift     # Phase-2 shells (Calgary, Toronto, …)
├── Core/
│   ├── AddressNormalizer.swift  # Address parsing contract
│   └── Cache/
│       └── LocalModels.swift    # SwiftData models
├── Features/
│   ├── Dossier/           # Address dossier screen + cards
│   ├── Map/               # City map tab
│   ├── PermitHistory/     # Permit history card
│   ├── Search/            # Search screen + view model
│   └── Settings/          # Settings screen
├── Resources/
│   ├── Assets.xcassets/   # App icon, colour assets
│   ├── Info.plist
│   ├── PrivacyInfo.xcprivacy
│   └── *.lproj/           # Localizations: en, fr-CA, ru, uk
Scripts/
└── make_icon.swift        # Regenerates AppIcon-1024.png
project.yml                # XcodeGen project definition
```

## Architecture

`CityDataProvider` is the city contract. Each provider declares:

- `cityID` / `displayName` — used by `CityRegistry` for lookup
- `datasets` — `CityDatasets` struct with Socrata / CKAN dataset IDs
- `fieldMappings` — maps portal field names to canonical Krokva field names
- `addressNormalizer` — city-specific `AddressNormalizer` implementation
- `boundingBox` — `MKMapRect` used to scope map and validation
- `implementationState` — `.live` or `.comingSoon`
- `fetchDossier(for:)` — main data-fetch entry point

`SocrataProvider` and `CKANProvider` contain portal mechanics shared across cities. City-specific providers keep city quirks close to the datasets.

`CityRegistry.shared.providers` is the ordered list of all registered providers. Address lookup walks this list and matches on `cityID` or `displayName`.

## Adding a City

1. Create `Krokva/Cities/Providers/YourCityProvider.swift`.
2. Conform to `CityDataProvider` — fill `CityDatasets` with your portal's dataset IDs and `FieldMappings` with field-name translations.
3. Implement (or reuse) an `AddressNormalizer` for the city's address format.
4. Register it in `CityRegistry` by appending `YourCityProvider()` to the `providers` array.
5. Set `implementationState` to `.comingSoon` until data is validated; flip to `.live` when ready.
6. Add licence attribution text to `SettingsView` if the portal requires it.

## Winnipeg Data Mirror

The iOS app reads Winnipeg data from the self-hosted Socrata-compatible mirror:

```text
http://3.99.123.190:8889/resource/{dataset}.json
```

The mirror lives on AWS Lightsail and serves City of Winnipeg Open Data from local
PostgreSQL 16 + PostGIS tables. This avoids hitting `data.winnipeg.ca` during every
report build and keeps address reports responsive even when the upstream portal is
slow or temporarily returns `503`.

Runtime wiring:

- `WinnipegProvider` points Socrata reads at `3.99.123.190:8889`.
- `DataStatusService` reads `http://3.99.123.190:8889/api/status`.
- `OpenDataClient` uses a 30-second timeout because some aggregate/geospatial mirror
  queries can be slower during cold cache or maintenance windows.
- Report cards distinguish empty data from fetch failures through `DataSourceHealth`.

Server maintenance:

- Daily delta sync runs at `03:00 UTC` / `10:00 PM CDT`.
- Weekly full sync runs Sunday at `02:00 UTC`.
- Sync retries transient upstream `429/500/502/503/504`, timeout, and connection errors.
- Each successful dataset sync runs `ANALYZE` for that table.
- Final maintenance can run `ANALYZE` across all `wnpg_%` tables.
- Hot report paths are indexed for assessment lookup, 311 aggregations, traffic
  street lookups, and nearby PostGIS queries.

The canonical upstream source remains City of Winnipeg Open Data:
`https://data.winnipeg.ca/resource/{dataset}.json`.

| Dataset | ID |
|---|---|
| Assessment Parcels | `d4mq-wa44` |
| Detailed Building Permits | `it4w-cpf4` |
| Active Vacant Building By-law Compliance Orders | `qe3f-4r3j` |
| LRS Speed Limits | `j5wn-5wz7` |
| Pothole Repairs | `4mat-mb3w` |
| Tree Inventory | `hfwk-jp4h` |
| Short Term Rental Accommodations | `74hr-f8ai` |
| WFPS Call Logs | `yg42-q284` |
| Naloxone Administrations | `qd6b-q49i` |
| Substance Use | `6x82-bz5y` |

Contains information licensed under the Open Government Licence — Winnipeg.

## Regenerating the App Icon

The icon is a procedurally drawn rafter glyph. To regenerate after changing colours or geometry:

```sh
swift Scripts/make_icon.swift
```

This overwrites `Krokva/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Requires macOS (uses `AppKit`).

## Localization

String tables live in `Krokva/Resources/*.lproj/Localizable.strings`. Supported locales:

- `en` — English (default)
- `fr-CA` — Canadian French
- `ru` — Russian
- `uk` — Ukrainian

## Build Configuration

`project.yml` (XcodeGen) is the source of truth. Do not edit `Krokva.xcodeproj` by hand — regenerate with `xcodegen generate` after any structural change.

| Key | Value |
|-----|-------|
| Bundle ID | `ca.krokva.app` |
| Version | `0.2.5` (set `MARKETING_VERSION` in `project.yml`) |
| Build number | `CURRENT_PROJECT_VERSION` |
| Device family | iPhone only (`TARGETED_DEVICE_FAMILY: "1"`) |
| UI style | Light mode only |

## Guardrails

Krokva is not a real-estate marketplace, market valuation tool, safety-score tool, or redlining tool.

- Assessment values are municipal records, not market values — never label them as such.
- Public-health datasets (naloxone, substance use) are anonymized emergency-response records and must never be displayed as scores, grades, or risk predictions.
- Speed limits, pothole counts, and similar infrastructure data are factual records, not neighbourhood quality rankings.
