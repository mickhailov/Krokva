# Krokva

> **Status (2026-07-05): data backend decommissioned.** The self-hosted Socrata
> mirror this app pointed at (`krokva.144.217.5.174.sslip.io`, gunicorn :8889,
> `wnpg_*` tables) was shut down on 2026-07-05 — all data cards except permit
> history (which hits `data.winnipeg.ca` directly) are empty. The mirror docs
> below are historical. To revive the app: point `SocrataProvider` at the CDS
> Socrata facade (`civic.144.217.5.174.sslip.io/resource/{id}.json`, same SoQL
> dialect — see `~/Documents/CivicData/docs/API.md`) and widen CDS retention
> windows per dataset where deep history is needed; or query `data.winnipeg.ca`
> directly for the long-tail history. A pre-decommission DB backup lives at
> `~/backups/winnipeg_pre_decommission_20260705.dump` on the OVH host.
> The krokva.com landing + email-subscribe service (:8891) are separate and
> still running.

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
http://krokva.144.217.5.174.sslip.io/resource/{dataset}.json
```

The mirror lives on the shared OVH VPS (`144.217.5.174`) and serves City of Winnipeg
Open Data from local PostgreSQL 16 + PostGIS tables via the `krokva` nginx vhost
(proxying to gunicorn on `127.0.0.1:8889` — not exposed directly on that port). This
avoids hitting `data.winnipeg.ca` during every report build and keeps address reports
responsive even when the upstream portal is slow or temporarily returns `503`.

Runtime wiring:

- `WinnipegProvider` points Socrata reads at `krokva.144.217.5.174.sslip.io`.
- `DataStatusService` reads `http://krokva.144.217.5.174.sslip.io/api/status`.
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
| Trade Permits | `urbd-qygv` |
| Park Asset Inventory | `dk7c-zxyd` |
| Parks and Open Space | `tx3d-pfxq` |
| Transit On-Time Performance | `gp3k-am4u` |
| Transit Pass-ups | `mer2-irmb` |
| Transit Passenger Activity | `bv6q-du26` |
| By-Law Investigations | `eye3-guud` |
| Detailed Development Permits | `w842-cdeb` |
| River Water Levels | `tgrf-v2zc` |
| Libraries | `bt47-pkkm` |
| Neighbourhoods | `8k6x-xxsy` |
| 311 Service Requests | `u7f6-5326` |
| Public Notices | `gnxp-9hpt` |
| School Zone Signage | `5298-dhjx` |
| School Divisions | `capx-4rye` |
| Recreation Complexes | `bmi4-vvs2` |
| LeisureONLINE Activities | `a2fq-ufu6` |
| Snow Clearing / Winter Parking Bans | `g3p4-h83y` |
| Plow Zones | `39ur-higg` |
| Waste Collection Days | `6rcy-9uik` |
| Business Licenses | `d5k3-sfzx` |
| Seasonal Patios | `cd49-nk9h` |
| Water Quality Test Results | `a5ix-gnny` |
| Midblock Traffic Counts | `buvf-b9wp` |
| Permanent Traffic Count Stations | `46sc-6jrs` |
| Census — Population By Age | `hiqy-dd38` |
| Census — Households | `nmk5-uwfw` |
| Census — Language | `wgmu-db32` |
| Census — Mode of Transportation | `ijxa-tybv` |
| Census — Citizenship & Immigration | `g66p-wwve` |
| Higher Poverty Areas (2021 Census) | `ige9-5jxk` |
| Electoral Wards | `t4cg-yaxs` |
| Community Committees | `dvqz-nw8j` |
| Swimming Pools (Indoor / Outdoor / Wading / Spray) | `rnpn-3qku` / `dqfv-rh5e` / `npmi-43db` / `uwfj-6mt2` |
| Public Wi-Fi Sites | `rzm8-wh6x` |
| Off-Leash Dog Areas (via Park Assets) | `dk7c-zxyd` |
| Vacant Property Fires | `tnm5-yaem` |
| Rooming House Enforcement | `vk2f-xwp7` |
| Rush-Hour Towing | `8phf-9kb6` |
| Paid Parking | `rmsh-97k4` |
| Capital Projects | `9xar-v8xm` |
| Public AEDs | `osm-aeds` |
| Health Protection Facility Closures | `fxcw-yyy2` |
| WPS Crime Maps | `d920a305d0024913a64e61ee1ef1d2a3` (ArcGIS) |

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
| Version | `0.2.7` (set `MARKETING_VERSION` in `project.yml`) |
| Build number | `CURRENT_PROJECT_VERSION` |
| Device family | iPhone only (`TARGETED_DEVICE_FAMILY: "1"`) |
| UI style | Light mode only |

## Guardrails

Krokva is not a real-estate marketplace, market valuation tool, safety-score tool, or redlining tool.

- Assessment values are municipal records, not market values — never label them as such.
- Public-health datasets (naloxone, substance use) are anonymized emergency-response records and must never be displayed as scores, grades, or risk predictions.
- Speed limits, pothole counts, and similar infrastructure data are factual records, not neighbourhood quality rankings.
