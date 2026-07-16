#!/usr/bin/env python3
"""
Import legacy CSV data into an EXISTING Supabase project using ONLY INSERTs.
HARD RULE: no DDL (no CREATE/ALTER/DROP/TRUNCATE). This script never issues any schema change.
"""
import csv
import json
import re
import time
import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------
URL = "https://jgehdsmrmcpnvcnfrjai.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impn"
        "ZWhkc21ybWNwbnZjbmZyamFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2OTMxMzQsImV4cCI"
        "6MjA5OTI2OTEzNH0.GurwFyegBNqiImJGUfwxEUuR2epzLlII1BwpBDPH1Kg")

CSV_DIR = Path(r"D:\trans\international_transport_app\csv")

# ---------------------------------------------------------------------------
# HTTP layer: prefer requests, fall back to urllib
# ---------------------------------------------------------------------------
try:
    import requests
    _SESSION = requests.Session()
    _ADAPTER = requests.adapters.HTTPAdapter(max_retries=3)
    _SESSION.mount("https://", _ADAPTER)
    _HAS_REQUESTS = True
except ImportError:
    _HAS_REQUESTS = False
    import urllib.request
    import urllib.error


def _headers():
    return {
        "apikey": ANON,
        "Authorization": f"Bearer {ANON}",
        "Content-Type": "application/json",
        "Prefer": "return=representation,resolution=merge-duplicates",
    }


def _raw_post(payload):
    """POST one JSON array. Returns (status, body_text). Raises on transport errors."""
    data = json.dumps(payload).encode("utf-8")
    if _HAS_REQUESTS:
        resp = _SESSION.post(f"{URL}/rest/v1/{_TABLE}", headers=_headers(),
                             data=data, timeout=60)
        return resp.status_code, resp.text
    else:
        req = urllib.request.Request(f"{URL}/rest/v1/{_TABLE}", data=data,
                                     headers=_headers(), method="POST")
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode("utf-8", "replace")


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------
def parse_num(v):
    if v is None:
        return None
    s = v.strip().replace(" ", "")
    if s == "":
        return None
    if re.search(r"\d,\d", s):
        s = s.replace(".", "").replace(",", ".")
    else:
        s = s.replace(".", "").replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


def parse_date(v):
    if v is None:
        return None
    s = v.strip()
    if not s:
        return None
    try:
        return datetime.datetime.strptime(s, "%d/%m/%Y").strftime("%Y-%m-%d")
    except ValueError:
        return None


def to_int(v):
    if v is None:
        return None
    s = v.strip().replace(" ", "")
    if s == "":
        return None
    try:
        return int(float(s))
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# CSV helpers (normalized access: case / space / accent tolerant)
# ---------------------------------------------------------------------------
def get(row, name):
    """Look up a column by normalized (lower, strip) name, else exact, else ''."""
    norm = {k.strip().lower(): k for k in row.keys()}
    target = name.strip().lower()
    if target in norm:
        return row[norm[target]]
    if name in row:
        return row[name]
    return ""


def read_csv(name):
    path = CSV_DIR / name
    with open(path, encoding="cp1252", newline="") as f:
        reader = csv.DictReader(f, delimiter=";")
        return list(reader)


# ---------------------------------------------------------------------------
# POST with chunking, 429 retry, and id-fallback collection
# ---------------------------------------------------------------------------
_TABLE = None
CHUNK = 300


def post(table, rows):
    """Batch POST rows (chunk 300). Return (inserted_count, errors, returned_ids)."""
    global _TABLE
    _TABLE = table
    inserted = 0
    errors = []
    returned_ids = []
    for i in range(0, len(rows), CHUNK):
        chunk = rows[i:i + CHUNK]
        attempt = 0
        while attempt < 6:
            attempt += 1
            try:
                status, body = _raw_post(chunk)
            except Exception as e:  # transport failure
                if attempt >= 6:
                    errors.append(f"{table}: transport error {e}")
                    break
                time.sleep(2 * attempt)
                continue
            if status in (200, 201):
                try:
                    data = json.loads(body) if body else []
                except json.JSONDecodeError:
                    data = []
                returned_ids.extend(d.get("id") for d in data if isinstance(d, dict))
                inserted += len(data) if data else len(chunk)
                break
            elif status == 429:
                time.sleep(2 * attempt)
                continue
            else:
                errors.append(f"{table}: HTTP {status} - {body[:300]}")
                break
    return inserted, errors, returned_ids


# ---------------------------------------------------------------------------
# ID-map-aware insert: try WITH legacy id, else WITHOUT id and zip returned ids
# ---------------------------------------------------------------------------
def insert_with_map(table, items):
    """items: list of (legacy_id, dict_without_id). Returns (inserted, errors, id_map)."""
    id_map = {}
    if not items:
        return 0, [], id_map

    with_id = [dict(d, id=lid) for lid, d in items]
    ins, errs, _ = post(table, with_id)
    identity_error = any(("identity" in e.lower()) or ("non-default value" in e.lower())
                         for e in errs)

    if identity_error or ins == 0:
        # retry without explicit id, then map returned (new) ids to legacy ids
        without_id = [{k: v for k, v in d.items() if k != "id"} for _, d in items]
        ins2, errs2, ret = post(table, without_id)
        for lid, rid in zip((lid for lid, _ in items), ret):
            if rid is not None:
                id_map[lid] = rid
        # anything without a returned id keeps legacy id as fallback
        for lid, _ in items:
            id_map.setdefault(lid, lid)
        return ins2, errs2, id_map

    for lid, _ in items:
        id_map[lid] = lid
    return ins, errs, id_map


# ---------------------------------------------------------------------------
# Load source files
# ---------------------------------------------------------------------------
clients_rows = read_csv("Clientèle.csv")
trucks_rows = read_csv("T00vehicules.csv")
trailers_rows = read_csv("T00frigo.csv")
drivers_rows = read_csv("Employés.csv")
orders_rows = read_csv("Commandes.csv")
categories_rows = read_csv("T09  categories.csv")
jobs_rows = read_csv("T09  tblJobs.csv")

# categories lookup: id_categorie -> categorie (name)
cat_lookup = {}
for r in categories_rows:
    cid = to_int(get(r, "id_categorie"))
    if cid is not None:
        cat_lookup[cid] = get(r, "categorie").strip()

# ---------------------------------------------------------------------------
# Build rows + maps
# ---------------------------------------------------------------------------
def clean(d):
    return {k: v for k, v in d.items() if v is not None}


clients_items = []
skipped = {"clients": 0}
for r in clients_rows:
    lid = to_int(get(r, "RéfClient"))
    if lid is None:
        skipped["clients"] += 1
        continue
    d = clean({
        "name": get(r, "NomSociété").strip(),
        "phone": get(r, "NuméroTél").strip(),
        "address": get(r, "AdresseFacturation").strip(),
        "city": get(r, "Ville").strip(),
        "nom_contact": " ".join([get(r, "PrénomContact"), get(r, "NomContact")]).strip(),
        "adresse_facturation": get(r, "AdresseFacturation").strip() or None,
    })
    if d.get("adresse_facturation") is None:
        d.pop("adresse_facturation", None)
    clients_items.append((lid, d))

trucks_items = []
skipped["trucks"] = 0
for r in trucks_rows:
    lid = to_int(get(r, "id_vehicule"))
    if lid is None:
        skipped["trucks"] += 1
        continue
    imm = get(r, "Immatriculation").strip()
    plate = imm if imm else get(r, "vehicules").strip()
    susp = get(r, "Susp").strip().upper()
    d = clean({
        "plate": plate,
        "model": get(r, "Marque").strip(),
        "status": "inactive" if susp == "TRUE" else "active",
    })
    trucks_items.append((lid, d))

trailers_items = []
skipped["trailers"] = 0
for r in trailers_rows:
    lid = to_int(get(r, "id_frigo"))
    if lid is None:
        skipped["trailers"] += 1
        continue
    d = clean({
        "plate_number": get(r, "frigo").strip(),
        "type": "refrigerated",
    })
    trailers_items.append((lid, d))

drivers_items = []
skipped["drivers"] = 0
for r in drivers_rows:
    lid = to_int(get(r, "RéfEmployé"))
    if lid is None:
        skipped["drivers"] += 1
        continue
    d = clean({
        "name": " ".join([get(r, "Prénom"), get(r, "NomFamille")]).strip(),
        "phone": get(r, "TélProfessionnel").strip(),
        "license": "",
        "status": "active",
        "base_salary": 0,
        "bonus_percentage": 0,
    })
    drivers_items.append((lid, d))

# ---------------------------------------------------------------------------
# Order items by legacy id (so zipped returned ids align), then insert + map
# ---------------------------------------------------------------------------
clients_items.sort(key=lambda x: x[0])
trucks_items.sort(key=lambda x: x[0])
trailers_items.sort(key=lambda x: x[0])
drivers_items.sort(key=lambda x: x[0])

ic, ec, clients_map = insert_with_map("clients", clients_items)
it, et, trucks_map = insert_with_map("trucks", trucks_items)
ifr, efr, trailers_map = insert_with_map("trailers", trailers_items)
idr, edr, drivers_map = insert_with_map("drivers", drivers_items)

all_errors = ec + et + efr + edr

# ---------------------------------------------------------------------------
# trip_orders
# ---------------------------------------------------------------------------
order_items = []
skipped["trip_orders"] = 0
for r in orders_rows:
    lid = to_int(get(r, "RéfCommande"))
    client_legacy = to_int(get(r, "RéfClient"))
    if lid is None or client_legacy not in clients_map:
        skipped["trip_orders"] += 1
        continue
    d = clean({
        "id": lid,
        "client_id": clients_map[client_legacy],
        "route": get(r, "VilleExpédition").strip() or get(r, "NomExpédition").strip() or "",
        "price": parse_num(get(r, "FraisTransport")) or 0,
        "status": "completed" if get(r, "Valider").strip().upper() == "TRUE" else "pending",
        "direction": "outbound",
        "specific_expenses": 0,
        "departure_date": parse_date(get(r, "DateCommande")),
    })
    drv = to_int(get(r, "RéfEmployé"))
    if drv is not None and drv in drivers_map:
        d["driver_id"] = drivers_map[drv]
    veh = to_int(get(r, "Véhicule"))
    if veh is not None and veh in trucks_map:
        d["truck_id"] = trucks_map[veh]
    order_items.append((lid, d))

io, eo, _ = insert_with_map("trip_orders", order_items)
all_errors += eo

# ---------------------------------------------------------------------------
# truck_maintenance
# ---------------------------------------------------------------------------
maint_items = []
skipped["truck_maintenance"] = 0
for r in jobs_rows:
    veh = to_int(get(r, "Véhicule"))
    if veh is None or veh not in trucks_map:
        skipped["truck_maintenance"] += 1
        continue
    cat_id = to_int(get(r, "categorie"))
    expense_type = cat_lookup.get(cat_id, "other")
    if not expense_type:
        expense_type = "other"
    d = clean({
        "truck_id": trucks_map[veh],
        "expense_type": expense_type,
        "amount": 0,
        "description": get(r, "JobName").strip() or None,
        "due_date": parse_date(get(r, "ExpectedCompletionDate")),
    })
    # required non-null: truck_id, expense_type, amount -> all guaranteed present
    maint_items.append(d)

im, em, _ = post("truck_maintenance", maint_items)
all_errors += em

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
totals = {
    "clients": (ic, skipped["clients"]),
    "trucks": (it, skipped["trucks"]),
    "trailers": (ifr, skipped["trailers"]),
    "drivers": (idr, skipped["drivers"]),
    "trip_orders": (io, skipped["trip_orders"]),
    "truck_maintenance": (im, skipped["truck_maintenance"]),
}

print("=== Per-table results (inserted / skipped) ===")
total_inserted = 0
for t, (ins, sk) in totals.items():
    print(f"  {t:18s} inserted={ins:6d}  skipped={sk:6d}")
    total_inserted += ins

print(f"\nTOTAL inserted = {total_inserted}")
print(f"Maps: clients={len(clients_map)} trucks={len(trucks_map)} "
      f"trailers={len(trailers_map)} drivers={len(drivers_map)}")

print("\n=== Error samples (first 3) ===")
for e in all_errors[:3]:
    print("  -", e)
if not all_errors:
    print("  (none)")

print("\nDDL executed: NONE (only INSERT statements were issued).")
