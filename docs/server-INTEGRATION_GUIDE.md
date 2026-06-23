# krokva-data — integration guide for a second app

> Read `README.md` first for operations (sync schedule, processes, maintenance).
> **This file is specifically for adding ANOTHER app on top of these databases
> without damaging how the Krokva iOS app uses them.** The golden rule:
> **the Krokva app is a read-only consumer of a frozen contract — add, never mutate.**

---

## 1. What is actually running here

```
                         ┌─────────────────────────────────────────┐
  Krokva iOS app  ─────► │ nginx :80/:443        (reverse proxy)    │
  (http, no auth)  ─────►│ gunicorn :8889  →  Flask  api:app        │  ← the API
                         │ python dashboard :8888 (internal)        │
                         │ PostgreSQL 16 + PostGIS  (db: winnipeg)  │  ← the data
                         └─────────────────────────────────────────┘
                                    AWS Lightsail, ca-central-1
                                    /home/ubuntu/projects/krokva-data
```

- **The API** (`api.py`) is a **Socrata-compatible** Flask app. It speaks the
  same `/resource/{id}.json?$where=...&$limit=...` dialect as data.winnipeg.ca, so
  the iOS app only had to change a base URL. Served by gunicorn on **`0.0.0.0:8889`**
  (publicly reachable), 4 workers, 30 s timeout.
- **The data** is PostgreSQL 16 + PostGIS, database **`winnipeg`**, ~70 tables
  named **`wnpg_*`**. It is a *mirror* — the source of truth upstream is the City
  of Winnipeg Open Data portal; `sync/sync_all.py` refreshes it (daily delta,
  weekly full). **Local edits to these tables get overwritten by the next sync.**
- Dataset id → table mapping is `ID_TO_TABLE` in `api.py`
  (mirrored in `sync/datasets.py`). This is the single source of truth.

---

## 2. Two ways a second app can connect

### Option A (recommended) — go through the HTTP API on :8889

This is exactly what the iOS app does, and it is the safest because it is
**read-only by construction** (the API only issues `SELECT`s) and it can't break
the schema.

```
GET http://3.99.123.190:8889/resource/{datasetID}.json?$select=...&$where=...&$limit=...
GET http://3.99.123.190:8889/api/schools/nearby?lat=..&lon=..
GET http://3.99.123.190:8889/api/status        # health / row counts
```

Supported SoQL params: `$select`, `$where`, `$group`, `$order`, `$limit`
(plus PostGIS-backed `within_circle(geomcol,lat,lon,m)` and
`intersects(the_geom,'POINT (lon lat)')`). Returns a JSON **array**; empty `[]`
means "no rows matched" (normal), non-2xx means error.

**Pros:** zero schema risk, no DB credentials to manage, already battle-tested.
**Cons:** read-only, and limited to the SoQL subset the API implements.

> If the second app is high-traffic, prefer giving it its **own** nginx route /
> path rather than hammering :8889 directly, so you can rate-limit it without
> touching the iOS traffic.

### Option B — connect directly to PostgreSQL (same box only)

Today Postgres is locked down: `listen_addresses = localhost` and `pg_hba.conf`
allows only `127.0.0.1/32` and `::1/128`. So **direct DB access only works for an
app running on this same Lightsail instance.**

```
postgresql://<role>:<pw>@localhost/winnipeg
```

**Do NOT reuse the `krokva` role for the new app.** `krokva` has write access and
is what the sync job uses. Create a dedicated **read-only** role instead (see §3).

If the second app must connect *from another machine*, that means opening Postgres
to the network — do this deliberately, not casually (see §5 "Don't break it").

---

## 3. Read-only role for the second app — ALREADY CREATED

A dedicated read-only role **`app2`** has been created. It has SELECT on every
`public` table (and on future tables, via default privileges) and **nothing
else** — verified: it can read, but `INSERT/UPDATE/DELETE` and `CREATE TABLE` are
denied, so it can never corrupt the data the iOS app reads.

The second app connects as:
```
postgresql://app2:oke2SR35yiexEvLPvuxsBNhCg6Yx@localhost/winnipeg
```

> ⚠️ Treat that password as a secret — store it in the second app's env/secret
> store, not in source control. Rotate with:
> `sudo -u postgres psql -c "ALTER ROLE app2 PASSWORD 'new_pw';"`

The grants that were applied (for reference / to re-apply on a rebuild):
```sql
CREATE ROLE app2 LOGIN PASSWORD '********';
GRANT CONNECT ON DATABASE winnipeg TO app2;
GRANT USAGE ON SCHEMA public TO app2;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app2;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app2;
```

If the second app needs its **own** writable data, give it a **separate schema**
or a **separate database** — never add columns/tables inside the `wnpg_*` space:

```sql
CREATE SCHEMA app2 AUTHORIZATION app2;   -- app2 owns and writes only here
-- or:  CREATE DATABASE app2_db OWNER app2;
```

---

## 4. The frozen contract (what the iOS app depends on)

Changing any of these silently breaks report cards in production. Treat as
read-only / append-only:

1. **Host/port/scheme of the API:** `http://3.99.123.190:8889`, plain HTTP.
2. **`/resource/{id}.json` behaviour** and the SoQL params in §2.
3. **Empty-vs-error semantics:** `[]` = no data, non-2xx = error. Never return
   200 + error body.
4. **Dataset IDs** and their **`ID_TO_TABLE`** mapping.
5. **Table & column names** under `wnpg_*`, and **geometry columns**
   (`location`, `point`, `coordinate`, `the_geom`, …) used by the geo filters.
6. **The `krokva` DB role and its password** (used by gunicorn + sync). Don't
   repurpose it.
7. **The sync cadence** — the daily/weekly cron in `README.md` overwrites table
   contents, so anything the second app writes *into* `wnpg_*` tables will be lost.

Safe changes are **additive**: new datasets/tables, new API routes, a new schema
for app2, new indexes for slow query shapes (see README's index guidance).

---

## 5. Don't break it — checklist before you connect a second app

- [ ] Second app uses **Option A (HTTP)** OR a **dedicated read-only role**
      (§3) — never the `krokva` write role.
- [ ] Second app's own data lives in its **own schema/database**, not in `wnpg_*`.
- [ ] If exposing Postgres beyond localhost: edit `listen_addresses` and add a
      **scoped** `pg_hba.conf` line (specific source CIDR + that one role + the
      `winnipeg` db, `scram-sha-256`), open the firewall/Lightsail port only to
      that source, and use a strong password. Don't broaden `all all`.
- [ ] Watch resource use: this box also runs `justcalories-api` (pm2),
      `telegram-assistant`, the dashboard (:8888) and an app on :8080. Postgres
      and gunicorn share the instance — load-test the second app before relying
      on it so it doesn't starve the iOS API.
- [ ] After any change, verify the iOS path still works:
      ```sh
      curl -sS http://127.0.0.1:8889/api/status
      curl -sS 'http://127.0.0.1:8889/resource/d4mq-wa44.json?$limit=1'
      ```

---

## 6. Quick reference

| Thing | Value |
|---|---|
| Project path | `/home/ubuntu/projects/krokva-data` |
| API | Flask `api.py` via gunicorn, `0.0.0.0:8889`, 4 workers, 30s timeout |
| DB | PostgreSQL 16 + PostGIS, database `winnipeg` |
| DB write role (Krokva/sync) | `krokva` — **do not reuse** |
| DB read-only role (second app) | `app2` — SELECT only, created & verified |
| DB local DSN (Krokva) | `postgresql://krokva:krokva2024@localhost/winnipeg` |
| DB local DSN (second app) | `postgresql://app2:oke2SR35yiexEvLPvuxsBNhCg6Yx@localhost/winnipeg` |
| DB remote access | **closed** (localhost-only) until you open it deliberately |
| Dataset→table map | `ID_TO_TABLE` in `api.py`, `sync/datasets.py` |
| Tables | ~70 `wnpg_*` tables (mirror — overwritten by sync) |
| Sync | daily delta 03:00 UTC, weekly full Sun 02:00 UTC (crontab) |
| External (not mirrored) | ArcGIS police-crime, gov.mb.ca schools, wrha.mb.ca ER waits |
