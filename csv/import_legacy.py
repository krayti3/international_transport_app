#!/usr/bin/env python3
# -*- coding: cp1252 -*-
"""One-time import of legacy CSV data into Supabase."""
import csv
import json
import re
import time
import urllib.request
import urllib.error
import urllib.parse
from typing import Any

SUPABASE_URL = "https://jgehdsmrmcpnvcnfrjai.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpnZWhkc21ybWNwbnZjbmZyamFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTMxMzQsImV4cCI6MjA5OTI2OTEzNH0.GurwFyegBNqiImJGUfwxEUuR2epzLlII1BwpBDPH1Kg"
HEADERS = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation,resolution=merge-duplicates",
}
BATCH_SIZE = 300
MAX_RETRIES = 3
RETRY_DELAY = 1.0
CSV_DIR = r"D:\trans\international_transport_app\csv"

# Stats
stats = {
    "clients": 0,
    "trucks": 0,
    "trailers": 0,
    "drivers": 0,
    "trip_orders": 0,
    "truck_maintenance": 0,
}
skipped = {"clients": 0, "trucks": 0, "trailers": 0, "drivers": 0, "trip_orders": 0, "truck_maintenance": 0}
errors = []


def log(msg: str):
    print(msg, flush=True)


def parse_number(val: str) -> float | int | None:
    if not val or val.strip() == "":
        return None
    v = val.strip().replace(" ", "")
    if not v:
        return None
    # French format: thousands sep '.', decimal ','
    v = v.replace(".", "").replace(",", ".")
    try:
        f = float(v)
        if f == int(f):
            return int(f)
        return f
    except ValueError:
        return 0


def parse_date(val: str) -> str | None:
    if not val or val.strip() == "":
        return None
    v = val.strip()
    m = re.match(r"^(\d{2})/(\d{2})/(\d{4})$", v)
    if not m:
        return None
    return f"{m.group(3)}-{m.group(2)}-{m.group(1)}"


def nullify(val: Any) -> Any:
    if val is None:
        return None
    if isinstance(val, str):
        v = val.strip()
        return v if v else None
    return val


def supabase_post(table: str, body: list[dict], retries: int = MAX_RETRIES) -> tuple[list[dict] | None, str | None]:
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    data = json.dumps(body).encode("utf-8")
    for attempt in range(retries):
        req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST")
        try:
            with urllib.request.urlopen(req) as resp:
                resp_body = resp.read().decode("utf-8")
                if not resp_body.strip():
                    return [], None
                return json.loads(resp_body), None
        except urllib.error.HTTPError as e:
            err_text = e.read().decode("utf-8", errors="replace") if e.fp else str(e)
            # Rate limit
            if e.code == 429:
                wait = RETRY_DELAY * (2 ** attempt)
                log(f"  Rate limited on {table}, retrying in {wait}s...")
                time.sleep(wait)
                continue
            return None, f"HTTP {e.code}: {err_text}"
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(RETRY_DELAY)
                continue
            return None, str(e)
    return None, "Max retries exceeded"


def supabase_insert_with_id(table: str, rows: list[dict], id_field: str) -> tuple[bool, list[dict] | None, str | None]:
    """Try inserting with explicit id. Returns (success, result, error)."""
    body = []
    for r in rows:
        d = dict(r)
        d[id_field] = d.pop("legacy_id")
        body.append(d)
    result, err = supabase_post(table, body)
    if err:
        # Check if error is about identity column
        if "identity" in err.lower() or "cannot insert a non-default value" in err.lower() or "is an identity column" in err.lower():
            return False, None, err
        # Other errors
        return False, None, err
    return True, result, None


def supabase_insert_without_id(table: str, rows: list[dict]) -> tuple[list[dict] | None, str | None]:
    """Insert without id, return new ids."""
    body = []
    for r in rows:
        d = dict(r)
        d.pop("legacy_id", None)
        body.append(d)
    result, err = supabase_post(table, body)
    return result, err


def read_csv(filepath: str, delimiter: str = ";", encoding: str = "cp1252") -> list[dict]:
    rows = []
    with open(filepath, "r", encoding=encoding, newline="") as f:
        reader = csv.DictReader(f, delimiter=delimiter)
        for row in reader:
            rows.append(dict(row))
    return rows


def chunked(iterable, size):
    for i in range(0, len(iterable), size):
        yield iterable[i:i + size]


# ---------------------------------------------------------------------------
# 1. LOAD LOOKUPS
# ---------------------------------------------------------------------------
log("Loading categories lookup...")
categories_raw = read_csv(f"{CSV_DIR}\\T09  categories.csv")
category_lookup = {}
for row in categories_raw:
    cid = row.get("id_categorie", "").strip()
    cat = row.get("categorie", "").strip()
    if cid:
        try:
            category_lookup[int(cid)] = cat if cat else "other"
        except ValueError:
            pass

# ---------------------------------------------------------------------------
# 2. CLIENTS
# ---------------------------------------------------------------------------
log("Processing clients...")
clients_raw = read_csv(f"{CSV_DIR}\\Clientèle.csv")
clients_data = []
for row in clients_raw:
    rid = row.get("RéfClient", "").strip()
    if not rid:
        skipped["clients"] += 1
        continue
    try:
        cid = int(rid)
    except ValueError:
        skipped["clients"] += 1
        continue
    name = nullify(row.get("NomSociété", ""))
    phone = nullify(row.get("NuméroTél", ""))
    address = nullify(row.get("AdresseFacturation", ""))
    city = nullify(row.get("Ville", ""))
    prenom = nullify(row.get("PrénomContact", "")) or ""
    nom = nullify(row.get("NomContact", "")) or ""
    nom_contact = nullify(f"{prenom} {nom}".strip())
    clients_data.append({
        "legacy_id": cid,
        "name": name,
        "phone": phone,
        "address": address,
        "city": city,
        "nom_contact": nom_contact,
        "adresse_facturation": address,
    })

clients_map = {}  # legacy_id -> db_id
identity_clients = False
for batch in chunked(clients_data, BATCH_SIZE):
    ok, result, err = supabase_insert_with_id("clients", batch, "id")
    if ok and result is not None:
        for r in result:
            clients_map[r["id"]] = r["id"]
        stats["clients"] += len(result)
    else:
        if err and ("identity" in err.lower() or "cannot insert a non-default value" in err.lower()):
            identity_clients = True
            log("  clients: identity column detected, retrying without id...")
            # Insert without id
            for sub in chunked(batch, BATCH_SIZE):
                res2, err2 = supabase_insert_without_id("clients", sub)
                if err2:
                    errors.append(f"clients insert without id: {err2}")
                    log(f"  ERROR clients: {err2}")
                elif res2:
                    for r in res2:
                        legacy = next((x["legacy_id"] for x in sub if x.get("name") == r.get("name")), None)
                        # Better: use original batch to map by row
                        pass
                    # Map by matching on all fields except legacy_id
                    sub_clean = []
                    for x in sub:
                        d = dict(x)
                        d.pop("legacy_id")
                        sub_clean.append(d)
                    for db_row, orig in zip(res2, sub_clean):
                        legacy = orig.get("legacy_id")
                        clients_map[db_row["id"]] = legacy
                    stats["clients"] += len(res2)
        else:
            errors.append(f"clients insert: {err}")
            log(f"  ERROR clients: {err}")

# Rebuild clients_map for non-identity case where we have legacy->new mapping
if identity_clients:
    clients_map = {}
    idx = 0
    for batch in chunked(clients_data, BATCH_SIZE):
        sub_clean = []
        for x in batch:
            d = dict(x)
            d.pop("legacy_id")
            sub_clean.append(d)
        res2, err2 = supabase_insert_without_id("clients", batch)
        if res2:
            for db_row, orig in zip(res2, batch):
                clients_map[orig["legacy_id"]] = db_row["id"]
            stats["clients"] += len(res2)
        else:
            errors.append(f"clients insert without id batch: {err2}")
            log(f"  ERROR clients batch: {err2}")

log(f"  clients inserted: {stats['clients']}, map size: {len(clients_map)}")

# ---------------------------------------------------------------------------
# 3. TRUCKS
# ---------------------------------------------------------------------------
log("Processing trucks...")
trucks_raw = read_csv(f"{CSV_DIR}\\T00vehicules.csv")
trucks_data = []
for row in trucks_raw:
    rid = row.get("id_vehicule", "").strip()
    if not rid:
        skipped["trucks"] += 1
        continue
    try:
        tid = int(rid)
    except ValueError:
        skipped["trucks"] += 1
        continue
    plate = nullify(row.get("Immatriculation", "")) or "vehicules"
    model = nullify(row.get("Marque", "")) or ""
    susp = row.get("Susp", "").strip().upper()
    status = "inactive" if susp == "TRUE" else "active"
    trucks_data.append({
        "legacy_id": tid,
        "plate": plate,
        "model": model,
        "status": status,
    })

trucks_map = {}
identity_trucks = False
for batch in chunked(trucks_data, BATCH_SIZE):
    ok, result, err = supabase_insert_with_id("trucks", batch, "id")
    if ok and result is not None:
        for r in result:
            trucks_map[r["id"]] = r["id"]
        stats["trucks"] += len(result)
    else:
        if err and ("identity" in err.lower() or "cannot insert a non-default value" in err.lower()):
            identity_trucks = True
            log("  trucks: identity column detected, retrying without id...")
            res2, err2 = supabase_insert_without_id("trucks", batch)
            if err2:
                errors.append(f"trucks insert without id: {err2}")
                log(f"  ERROR trucks: {err2}")
            elif res2:
                for db_row, orig in zip(res2, batch):
                    trucks_map[orig["legacy_id"]] = db_row["id"]
                stats["trucks"] += len(res2)
        else:
            errors.append(f"trucks insert: {err}")
            log(f"  ERROR trucks: {err}")

if identity_trucks:
    trucks_map = {}
    for batch in chunked(trucks_data, BATCH_SIZE):
        res2, err2 = supabase_insert_without_id("trucks", batch)
        if res2:
            for db_row, orig in zip(res2, batch):
                trucks_map[orig["legacy_id"]] = db_row["id"]
            stats["trucks"] += len(res2)
        else:
            errors.append(f"trucks insert without id batch: {err2}")
            log(f"  ERROR trucks batch: {err2}")

log(f"  trucks inserted: {stats['trucks']}, map size: {len(trucks_map)}")

# ---------------------------------------------------------------------------
# 4. TRAILERS
# ---------------------------------------------------------------------------
log("Processing trailers...")
trailers_raw = read_csv(f"{CSV_DIR}\\T00frigo.csv")
trailers_data = []
for row in trailers_raw:
    rid = row.get("id_frigo", "").strip()
    if not rid:
        skipped["trailers"] += 1
        continue
    try:
        fid = int(rid)
    except ValueError:
        skipped["trailers"] += 1
        continue
    plate_number = nullify(row.get("frigo", "")) or ""
    trailers_data.append({
        "legacy_id": fid,
        "plate_number": plate_number,
        "type": "refrigerated",
    })

trailers_map = {}
identity_trailers = False
for batch in chunked(trailers_data, BATCH_SIZE):
    ok, result, err = supabase_insert_with_id("trailers", batch, "id")
    if ok and result is not None:
        for r in result:
            trailers_map[r["id"]] = r["id"]
        stats["trailers"] += len(result)
    else:
        if err and ("identity" in err.lower() or "cannot insert a non-default value" in err.lower()):
            identity_trailers = True
            log("  trailers: identity column detected, retrying without id...")
            res2, err2 = supabase_insert_without_id("trailers", batch)
            if err2:
                errors.append(f"trailers insert without id: {err2}")
                log(f"  ERROR trailers: {err2}")
            elif res2:
                for db_row, orig in zip(res2, batch):
                    trailers_map[orig["legacy_id"]] = db_row["id"]
                stats["trailers"] += len(res2)
        else:
            errors.append(f"trailers insert: {err}")
            log(f"  ERROR trailers: {err}")

if identity_trailers:
    trailers_map = {}
    for batch in chunked(trailers_data, BATCH_SIZE):
        res2, err2 = supabase_insert_without_id("trailers", batch)
        if res2:
            for db_row, orig in zip(res2, batch):
                trailers_map[orig["legacy_id"]] = db_row["id"]
            stats["trailers"] += len(res2)
        else:
            errors.append(f"trailers insert without id batch: {err2}")
            log(f"  ERROR trailers batch: {err2}")

log(f"  trailers inserted: {stats['trailers']}, map size: {len(trailers_map)}")

# ---------------------------------------------------------------------------
# 5. DRIVERS
# ---------------------------------------------------------------------------
log("Processing drivers...")
drivers_raw = read_csv(f"{CSV_DIR}\\Employés.csv")
drivers_data = []
for row in drivers_raw:
    rid = row.get("RéfEmployé", "").strip()
    if not rid:
        skipped["drivers"] += 1
        continue
    try:
        did = int(rid)
    except ValueError:
        skipped["drivers"] += 1
        continue
    prenom = nullify(row.get("Prénom", "")) or ""
    nom = nullify(row.get("NomFamille", "")) or ""
    name = nullify(f"{prenom} {nom}".strip())
    phone = nullify(row.get("TélProfessionnel", ""))
    drivers_data.append({
        "legacy_id": did,
        "name": name,
        "phone": phone,
        "license": "",
        "status": "active",
        "base_salary": 0,
        "bonus_percentage": 0,
    })

drivers_map = {}
identity_drivers = False
for batch in chunked(drivers_data, BATCH_SIZE):
    ok, result, err = supabase_insert_with_id("drivers", batch, "id")
    if ok and result is not None:
        for r in result:
            drivers_map[r["id"]] = r["id"]
        stats["drivers"] += len(result)
    else:
        if err and ("identity" in err.lower() or "cannot insert a non-default value" in err.lower()):
            identity_drivers = True
            log("  drivers: identity column detected, retrying without id...")
            res2, err2 = supabase_insert_without_id("drivers", batch)
            if err2:
                errors.append(f"drivers insert without id: {err2}")
                log(f"  ERROR drivers: {err2}")
            elif res2:
                for db_row, orig in zip(res2, batch):
                    drivers_map[orig["legacy_id"]] = db_row["id"]
                stats["drivers"] += len(res2)
        else:
            errors.append(f"drivers insert: {err}")
            log(f"  ERROR drivers: {err}")

if identity_drivers:
    drivers_map = {}
    for batch in chunked(drivers_data, BATCH_SIZE):
        res2, err2 = supabase_insert_without_id("drivers", batch)
        if res2:
            for db_row, orig in zip(res2, batch):
                drivers_map[orig["legacy_id"]] = db_row["id"]
            stats["drivers"] += len(res2)
        else:
            errors.append(f"drivers insert without id batch: {err2}")
            log(f"  ERROR drivers batch: {err2}")

log(f"  drivers inserted: {stats['drivers']}, map size: {len(drivers_map)}")

# ---------------------------------------------------------------------------
# 6. TRIP ORDERS
# ---------------------------------------------------------------------------
log("Processing trip_orders...")
orders_raw = read_csv(f"{CSV_DIR}\\Commandes.csv")
orders_data = []
for row in orders_raw:
    rid = row.get("RéfCommande", "").strip()
    if not rid:
        skipped["trip_orders"] += 1
        continue
    try:
        oid = int(rid)
    except ValueError:
        skipped["trip_orders"] += 1
        continue
    client_rid = row.get("RéfClient", "").strip()
    try:
        client_lid = int(client_rid) if client_rid else None
    except ValueError:
        skipped["trip_orders"] += 1
        continue
    if client_lid not in clients_map:
        skipped["trip_orders"] += 1
        continue
    route = nullify(row.get("VilleExpédition", "")) or nullify(row.get("NomExpédition", "")) or ""
    price = parse_number(row.get("FraisTransport", "")) or 0
    valider = row.get("Valider", "").strip().upper()
    status = "completed" if valider == "TRUE" else "pending"
    departure_date = parse_date(row.get("DateCommande", ""))
    driver_rid = row.get("RéfEmployé", "").strip()
    truck_rid = row.get("Véhicule", "").strip()
    order = {
        "legacy_id": oid,
        "client_id": clients_map[client_lid],
        "route": route,
        "price": price,
        "status": status,
        "direction": "outbound",
        "specific_expenses": 0,
        "departure_date": departure_date,
    }
    if driver_rid:
        try:
            dlid = int(driver_rid)
            if dlid in drivers_map:
                order["driver_id"] = drivers_map[dlid]
        except ValueError:
            pass
    if truck_rid:
        try:
            tlid = int(truck_rid)
            if tlid in trucks_map:
                order["truck_id"] = trucks_map[tlid]
        except ValueError:
            pass
    orders_data.append(order)

orders_map = {}
identity_orders = False
for batch in chunked(orders_data, BATCH_SIZE):
    ok, result, err = supabase_insert_with_id("trip_orders", batch, "id")
    if ok and result is not None:
        for r in result:
            orders_map[r["id"]] = r["id"]
        stats["trip_orders"] += len(result)
    else:
        if err and ("identity" in err.lower() or "cannot insert a non-default value" in err.lower()):
            identity_orders = True
            log("  trip_orders: identity column detected, retrying without id...")
            res2, err2 = supabase_insert_without_id("trip_orders", batch)
            if err2:
                errors.append(f"trip_orders insert without id: {err2}")
                log(f"  ERROR trip_orders: {err2}")
            elif res2:
                for db_row, orig in zip(res2, batch):
                    orders_map[orig["legacy_id"]] = db_row["id"]
                stats["trip_orders"] += len(res2)
        else:
            errors.append(f"trip_orders insert: {err}")
            log(f"  ERROR trip_orders: {err}")

if identity_orders:
    orders_map = {}
    for batch in chunked(orders_data, BATCH_SIZE):
        res2, err2 = supabase_insert_without_id("trip_orders", batch)
        if res2:
            for db_row, orig in zip(res2, batch):
                orders_map[orig["legacy_id"]] = db_row["id"]
            stats["trip_orders"] += len(res2)
        else:
            errors.append(f"trip_orders insert without id batch: {err2}")
            log(f"  ERROR trip_orders batch: {err2}")

log(f"  trip_orders inserted: {stats['trip_orders']}, map size: {len(orders_map)}")

# ---------------------------------------------------------------------------
# 7. TRUCK MAINTENANCE
# ---------------------------------------------------------------------------
log("Processing truck_maintenance...")
jobs_raw = read_csv(f"{CSV_DIR}\\T09  tblJobs.csv")
jobs_data = []
for row in jobs_raw:
    rid = row.get("Véhicule", "").strip()
    if not rid:
        skipped["truck_maintenance"] += 1
        continue
    try:
        jid = int(rid)
    except ValueError:
        skipped["truck_maintenance"] += 1
        continue
    if jid not in trucks_map:
        skipped["truck_maintenance"] += 1
        continue
    cat_id = row.get("categorie", "").strip()
    try:
        expense_type = category_lookup.get(int(cat_id), "other") if cat_id else "other"
    except ValueError:
        expense_type = "other"
    description = nullify(row.get("JobName", "")) or ""
    due_date = parse_date(row.get("ExpectedCompletionDate", ""))
    jobs_data.append({
        "legacy_id": jid,  # not used for insert, just for tracking
        "truck_id": trucks_map[jid],
        "expense_type": expense_type,
        "amount": 0,
        "description": description,
        "due_date": due_date,
    })

# truck_maintenance likely doesn't need id preservation, but try anyway
maint_map = {}
identity_maint = False
for batch in chunked(jobs_data, BATCH_SIZE):
    clean_batch = []
    for x in batch:
        d = dict(x)
        d.pop("legacy_id", None)
        clean_batch.append(d)
    ok, result, err = supabase_post("truck_maintenance", clean_batch)
    # Actually, let's use the generic insert
    result, err = supabase_post("truck_maintenance", clean_batch)
    if err:
        if "identity" in err.lower() or "cannot insert a non-default value" in err.lower():
            identity_maint = True
        errors.append(f"truck_maintenance insert: {err}")
        log(f"  ERROR truck_maintenance: {err}")
    elif result:
        stats["truck_maintenance"] += len(result)

log(f"  truck_maintenance inserted: {stats['truck_maintenance']}")

# ---------------------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------------------
total = sum(stats.values())
log("\n=== IMPORT SUMMARY ===")
for table, count in stats.items():
    log(f"  {table}: {count} rows inserted")
log(f"  TOTAL: {total}")
log("\n=== SKIPPED ===")
for table, count in skipped.items():
    log(f"  {table}: {count} rows skipped")
log("\n=== ERRORS ===")
if errors:
    for e in errors[:20]:
        log(f"  {e}")
else:
    log("  None")
log("\nNO schema/DDL was run.")
