# Krokva data backend — what the server is and how we use it

> **Purpose of this file.** It documents the data backend Krokva depends on, so a
> **second app can connect to the same databases without breaking Krokva.**
> The iOS app reads from these sources **read-only**. If you add another app,
> keep it read-only too, and do **not** rename datasets, change field names, or
> alter the query contract described here — Krokva's report cards are keyed to
> them and will silently render empty (or show "Database error") if they change.

---

## 1. The server

Krokva does **not** talk to the City of Winnipeg's public open-data portal
directly. It talks to a **self-hosted, Socrata-compatible mirror** that we run.

| Property        | Value |
|-----------------|-------|
| Host            | `3.99.123.190` |
| Port            | `8889` |
| Scheme          | `http` (plain HTTP, **not** HTTPS) |
| API style       | Socrata SODA 2.x compatible (SoQL query params) |
| Auth            | **None** — no app token, no API key, no `Authorization` header |
| Response format | JSON array of flat objects: `[ { "field": "value", ... }, ... ]` |

Defined in code at `Krokva/Cities/Providers/WinnipegProvider.swift`:

```swift
init() {
    super.init(domain: "3.99.123.190:8889", scheme: "http")
}
```

URL building lives in `Krokva/Cities/Providers/SocrataProvider.swift`
(`resourceURL` / `fetch`) and the HTTP layer in
`Krokva/Core/Networking/OpenDataClient.swift`.

> ⚠️ The mirror can be **slow** (10–20 s) for aggregate/geospatial queries when
> warming up or when a dataset lacks an index. The client uses a **30 s timeout**
> and retries **once** on transport failures (timeout/connection lost), but not
> on HTTP error codes or decode errors. Any new client should budget similar
> timeouts.

---

## 2. The request contract

### Standard dataset reads (Socrata `/resource`)

```
GET http://3.99.123.190:8889/resource/{datasetID}.json?{SoQL query params}
```

- `{datasetID}` is a Socrata-style 4×4 id (e.g. `d4mq-wa44`), or one of our
  custom ids (`osm-aeds`, etc.). The full list is in section 4.
- A successful read returns a JSON **array**. An **empty array `[]` means "no
  rows matched"** (a normal, expected state) — it is *not* an error.
- A non-2xx HTTP status is treated as a **database/transport error**
  (`OpenDataError.badResponse`). Krokva distinguishes these: empty → "No data"
  card; error → "Database error" card. Keep that semantics if you reuse the API.

### SoQL parameters we rely on

| Param      | Used for | Example |
|------------|----------|---------|
| `$select`  | column projection + aggregates | `count(*) as cnt`, `date_extract_y(issue_date) as year` |
| `$where`   | filtering | `neighbourhood_area='RIVER HEIGHTS'` |
| `$group`   | aggregation | `$group=year` |
| `$order`   | sorting | `issue_date DESC` |
| `$limit`   | row cap | `$limit=2000` |

### Geospatial filters (must be supported by the backend)

- **Radius / proximity:**
  `within_circle({geomColumn}, {lat}, {lon}, {meters})`
  e.g. `within_circle(location, 49.88, -97.15, 500)`
- **Point-in-polygon:**
  `intersects({geomColumn}, 'POINT ({lon} {lat})')`
  Used for ward, community committee, plow zone, higher-poverty lookups.

Geometry column names vary by dataset (`location`, `point`, `coordinate`,
`the_geom`, `geometry`) — Krokva already hard-codes the right one per query, so
a second app should copy the exact column from the matching query in
`WinnipegProvider.swift`.

### Custom server endpoint (not Socrata)

The mirror also serves an app-specific schools endpoint:

```
GET http://3.99.123.190:8889/api/schools/nearby?{params}
```

Returns `{ "assigned": [...], "nearby": [...] }` (see `ServerSchoolsResponse` in
`WinnipegProvider.swift`). If your second app needs school data, prefer this
endpoint over re-deriving it.

---

## 3. Things to NOT change (so Krokva keeps working)

The iOS app is tightly coupled to the backend's **shape**. Treat these as a
frozen contract; if the second app needs something different, **add** alongside
rather than mutate:

1. **Host / port / scheme** (`3.99.123.190:8889`, http). Changing any of these
   breaks every report card.
2. **Dataset IDs** (section 4). Krokva references them by id in
   `CityDatasets`.
3. **Field/column names.** Field name mappings are pinned in `FieldMappings`
   and in dozens of `$select` / `$where` clauses. Renaming a column orphans the
   cards that read it.
4. **Geometry column names** per dataset (used by `within_circle` / `intersects`).
5. **Empty-vs-error semantics**: `[]` for no rows, non-2xx for failures. Never
   return a 200 with an error body — Krokva would treat it as "no data".
6. **Read-only access.** Krokva never writes. Don't point a write-capable app at
   the same datasets without isolating it (separate creds/instance), or you risk
   mutating rows the app reads.

If you must evolve a dataset, prefer **additive** changes (new columns, new
datasets) and keep old fields populated until the app is updated.

---

## 4. Datasets in use (Winnipeg)

All ids resolve under `/resource/{id}.json` on the mirror. Source of truth is
`CityDatasets(...)` in `Krokva/Cities/Providers/WinnipegProvider.swift`.

| Module group | Datasets (id) |
|---|---|
| **Property** | assessment `d4mq-wa44`, addresses `cam2-ii3u`, zoning parcels `dxrp-w6re`, neighbourhoods `8k6x-xxsy` |
| **Permits & development** | permits `it4w-cpf4`, trade permits `urbd-qygv`, development permits `w842-cdeb`, dev processing times `3ij3-3hnj`, dev intake `jman-p4ya`, vacant orders `qe3f-4r3j`, short-term rentals `74hr-f8ai`, bylaw investigations `eye3-guud`, public notices `gnxp-9hpt` |
| **Safety & health** | emergency calls `yg42-q284`, naloxone `qd6b-q49i`, substance use `6x82-bz5y`, service requests `u7f6-5326`, vacant-property fires `tnm5-yaem`, rooming-house enforcement `vk2f-xwp7`, rush-hour towing `8phf-9kb6`, paid parking `rmsh-97k4`, public AEDs `osm-aeds` |
| **Daily living** | waste collection `6rcy-9uik`, plow zones `39ur-higg`, plow zone schedule `tix9-r5tc`, snow route addresses `g3p4-h83y`, snow parking bans `mfzv-893p`, electoral wards `t4cg-yaxs`, community committees `dvqz-nw8j`, business licenses `d5k3-sfzx`, seasonal patios `cd49-nk9h` |
| **Census / demographics** | age `hiqy-dd38`, households `nmk5-uwfw`, language `wgmu-db32`, transport mode `ijxa-tybv`, immigration `g66p-wwve`, higher-poverty areas `ige9-5jxk` |
| **Amenities & street** | park assets `dk7c-zxyd`, parks/open space `tx3d-pfxq`, recreation complexes `bmi4-vvs2`, leisure activities `a2fq-ufu6`, libraries `bt47-pkkm`, river levels `tgrf-v2zc`, transit on-time `gp3k-am4u`, transit pass-ups `mer2-irmb`, transit passenger activity `bv6q-du26`, pools indoor `rnpn-3qku` / outdoor `dqfv-rh5e` / wading `npmi-43db` / spray `uwfj-6mt2`, walkways `jdeq-xf3y`, public wifi `rzm8-wh6x` |
| **Street / infrastructure** | speed limits `j5wn-5wz7`, school speed limits `k56t-9dvi`, pavement condition `enpg-8cug`, cycling network `kjd9-dvf5`, potholes `4mat-mb3w`, trees `hfwk-jp4h`, accessibility disruptions `fxq5-ign2`, lane closures `h367-iifg`, midblock traffic `buvf-b9wp`, permanent traffic `46sc-6jrs`, water quality `a5ix-gnny`, capital projects `9xar-v8xm`, infrastructure funding `rwrz-d7hc`, facility closures `fxcw-yyy2`, heritage `ptpx-kgiu`, mosquito traps `du7c-8488` |
| **Schools** | schools `5298-dhjx`, school divisions `capx-4rye` (plus the `/api/schools/nearby` endpoint) |

---

## 5. External sources NOT on our server

These come from third-party hosts, not the mirror. A second app should hit them
directly the same way (they are public), not through our backend:

| Source | URL | Used for |
|---|---|---|
| ArcGIS | `https://www.arcgis.com/sharing/rest/content/items/d920a305d0024913a64e61ee1ef1d2a3/data` | Police crime maps (CSV) |
| Manitoba schools directory | `https://web.gov.mb.ca/school/school` (POST) | Provincial school directory |
| WRHA | `https://wrha.mb.ca/wait-times/emergency/` (HTML scrape) | ER wait times — see `Krokva/Core/Networking/WRHAWaitTimesClient.swift` |

---

## 6. Quick smoke test

```sh
# Should return a small JSON array (one assessment row)
curl 'http://3.99.123.190:8889/resource/d4mq-wa44.json?$limit=1'

# Geospatial: bus stops within 500 m of a point
curl 'http://3.99.123.190:8889/resource/gp3k-am4u.json?$where=within_circle(location,49.88,-97.15,500)&$limit=5'

# Custom endpoint
curl 'http://3.99.123.190:8889/api/schools/nearby?lat=49.88&lon=-97.15'
```

If these return JSON arrays, the backend is healthy and your second app can use
the exact same calls.
