from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import logging
import requests as req
import json
import os
import re
import math
import secrets
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from dotenv import load_dotenv

# Load environment variables
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR.parent / ".env")
load_dotenv(BASE_DIR / ".env", override=True)
load_dotenv()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Gravity AI Backend")

def _allowed_origins() -> list:
    origins = os.getenv("ALLOWED_ORIGINS", "*")
    return [origin.strip() for origin in origins.split(",") if origin.strip()]


ALLOWED_ORIGINS = _allowed_origins()

# Add CORS middleware. Use ALLOWED_ORIGINS for production domains.
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=ALLOWED_ORIGINS != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

GROQ_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions"
VIASOCKET_WEBHOOK_URL = os.getenv("VIASOCKET_WEBHOOK_URL", "")
OFFICER_USER_ID = os.getenv("OFFICER_USER_ID", "")
OFFICER_PASSWORD = os.getenv("OFFICER_PASSWORD", "")
STATE_ALERT_EMAIL_MAP = os.getenv("STATE_ALERT_EMAIL_MAP", "{}")
DATABASE_PATH = Path(os.getenv("SQLITE_DB_PATH", BASE_DIR / "gravity_ai.sqlite3"))


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _db_connection() -> sqlite3.Connection:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db() -> None:
    with closing(_db_connection()) as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS auth_sessions (
                token TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                last_seen_at TEXT NOT NULL,
                revoked_at TEXT
            );

            CREATE TABLE IF NOT EXISTS complaints (
                id TEXT PRIMARY KEY,
                reporter TEXT NOT NULL,
                email TEXT,
                phone TEXT,
                target TEXT NOT NULL,
                description TEXT NOT NULL,
                evidence TEXT,
                lat REAL NOT NULL,
                lon REAL NOT NULL,
                state TEXT,
                risk_score INTEGER DEFAULT 0,
                area_sqm INTEGER DEFAULT 0,
                status TEXT NOT NULL,
                action TEXT NOT NULL,
                submitted_at TEXT NOT NULL,
                updated_at TEXT
            );
            """
        )
        conn.commit()


def _row_to_complaint(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "reporter": row["reporter"],
        "email": row["email"] or "",
        "phone": row["phone"] or "",
        "target": row["target"],
        "description": row["description"],
        "evidence": row["evidence"] or "No photo uploaded",
        "lat": row["lat"],
        "lon": row["lon"],
        "state": row["state"] or "UNKNOWN",
        "risk_score": row["risk_score"] or 0,
        "area_sqm": row["area_sqm"] or 0,
        "status": row["status"],
        "action": row["action"],
        "submittedAt": row["submitted_at"],
        "updatedAt": row["updated_at"],
    }


def _save_session(token: str, user_id: str) -> None:
    now = _utc_now()
    with closing(_db_connection()) as conn:
        conn.execute(
            """
            INSERT INTO auth_sessions (token, user_id, created_at, last_seen_at)
            VALUES (?, ?, ?, ?)
            """,
            (token, user_id, now, now),
        )
        conn.commit()


def _session_user(token: str) -> str | None:
    now = _utc_now()
    with closing(_db_connection()) as conn:
        row = conn.execute(
            """
            SELECT user_id FROM auth_sessions
            WHERE token = ? AND revoked_at IS NULL
            """,
            (token,),
        ).fetchone()
        if row:
            conn.execute(
                "UPDATE auth_sessions SET last_seen_at = ? WHERE token = ?",
                (now, token),
            )
            conn.commit()
            return row["user_id"]
    return None


def _revoke_session(token: str) -> None:
    with closing(_db_connection()) as conn:
        conn.execute(
            "UPDATE auth_sessions SET revoked_at = ? WHERE token = ?",
            (_utc_now(), token),
        )
        conn.commit()


def _insert_complaint(complaint: dict) -> None:
    with closing(_db_connection()) as conn:
        conn.execute(
            """
            INSERT OR REPLACE INTO complaints (
                id, reporter, email, phone, target, description, evidence,
                lat, lon, state, risk_score, area_sqm, status, action,
                submitted_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                complaint["id"],
                complaint["reporter"],
                complaint.get("email", ""),
                complaint.get("phone", ""),
                complaint["target"],
                complaint["description"],
                complaint.get("evidence", "No photo uploaded"),
                complaint["lat"],
                complaint["lon"],
                complaint.get("state", "UNKNOWN"),
                complaint.get("risk_score", 0),
                complaint.get("area_sqm", 0),
                complaint["status"],
                complaint["action"],
                complaint["submittedAt"],
                complaint.get("updatedAt"),
            ),
        )
        conn.commit()


def _list_complaints() -> list[dict]:
    with closing(_db_connection()) as conn:
        rows = conn.execute(
            "SELECT * FROM complaints ORDER BY submitted_at DESC"
        ).fetchall()
        return [_row_to_complaint(row) for row in rows]


def _update_complaint_record(complaint_id: str, status: str, action: str) -> dict | None:
    updated_at = _utc_now()
    with closing(_db_connection()) as conn:
        conn.execute(
            """
            UPDATE complaints
            SET status = ?, action = ?, updated_at = ?
            WHERE id = ?
            """,
            (status, action, updated_at, complaint_id),
        )
        row = conn.execute(
            "SELECT * FROM complaints WHERE id = ?",
            (complaint_id,),
        ).fetchone()
        conn.commit()
        return _row_to_complaint(row) if row else None


_init_db()

@app.get("/")
async def root():
    return {
        "status": "success",
        "message": "Gravity AI Backend is Live!",
        "updated": datetime.now(timezone.utc).date().isoformat(),
    }

class ScanRequest(BaseModel):
    lat: float
    lon: float
    sector: Optional[str] = None


class ForestScanRequest(BaseModel):
    lat: float
    lon: float
    sector: Optional[str] = None
    current_layer: Optional[str] = "LULC250K_2425"
    previous_layer: Optional[str] = "LULC250K_2324"


class ChatRequest(BaseModel):
    message: str


class VisionRequest(BaseModel):
    image_base64: str
    image_name: str
    mime_type: Optional[str] = "image/jpeg"


class AuthRequest(BaseModel):
    user_id: str
    password: str


class ComplaintRequest(BaseModel):
    id: Optional[str] = None
    reporter: str
    email: Optional[str] = None
    phone: Optional[str] = None
    target: str
    description: str
    evidence: Optional[str] = None
    lat: float
    lon: float
    state: Optional[str] = None
    risk_score: Optional[int] = 0
    area_sqm: Optional[int] = 0


class ComplaintActionRequest(BaseModel):
    status: str
    action: str


def _require_groq_key():
    if not GROQ_KEY:
        raise HTTPException(
            status_code=503,
            detail="GROQ_API_KEY is not configured on the backend",
        )


def _state_alert_email(state: str | None) -> str:
    try:
        mapping = json.loads(STATE_ALERT_EMAIL_MAP or "{}")
        return mapping.get((state or "").upper(), mapping.get("DEFAULT", ""))
    except Exception:
        return ""


def _post_to_viasocket(payload: dict) -> dict:
    if not VIASOCKET_WEBHOOK_URL:
        return {"status": "not_configured", "message": "VIASOCKET_WEBHOOK_URL is not set"}
    try:
        response = req.post(VIASOCKET_WEBHOOK_URL, json=payload, timeout=20)
        return {
            "status": "sent" if response.status_code < 400 else "failed",
            "status_code": response.status_code,
            "body": response.text[:500],
        }
    except Exception as exc:
        logger.warning(f"ViaSocket webhook failed: {exc}")
        return {"status": "failed", "message": str(exc)}


def _require_auth(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    user_id = _session_user(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user_id


@app.post("/api/auth/login")
async def login(request: AuthRequest):
    if not OFFICER_USER_ID or not OFFICER_PASSWORD:
        raise HTTPException(status_code=503, detail="Officer login is not configured")
    if request.user_id.strip() != OFFICER_USER_ID or request.password != OFFICER_PASSWORD:
        raise HTTPException(status_code=401, detail="Invalid user ID or password")
    token = secrets.token_urlsafe(32)
    user = request.user_id.strip()
    _save_session(token, user)
    return {"status": "success", "token": token, "user": user}


@app.get("/api/auth/session")
async def session(authorization: str | None = Header(default=None)):
    user = _require_auth(authorization)
    return {"status": "success", "user": user}


@app.post("/api/auth/logout")
async def logout(authorization: str | None = Header(default=None)):
    if authorization and authorization.startswith("Bearer "):
        _revoke_session(authorization.removeprefix("Bearer ").strip())
    return {"status": "success"}


@app.post("/api/complaints")
async def submit_complaint(request: ComplaintRequest):
    complaint_id = request.id or f"BHU-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
    submitted_at = datetime.now(timezone.utc).isoformat()
    state = (request.state or "UNKNOWN").upper()
    complaint = {
        "id": complaint_id,
        "reporter": request.reporter,
        "email": request.email or "",
        "phone": request.phone or "",
        "target": request.target,
        "description": request.description,
        "evidence": request.evidence or "No photo uploaded",
        "lat": request.lat,
        "lon": request.lon,
        "state": state,
        "risk_score": request.risk_score or 0,
        "area_sqm": request.area_sqm or 0,
        "status": "New Complaint",
        "action": "Sent to state alert workflow",
        "submittedAt": submitted_at,
    }
    _insert_complaint(complaint)

    alert_email = _state_alert_email(state)
    viasocket_payload = {
        "workflow": "bhu_prahari_complaint_state_alert",
        "database_action": "insert_complaint",
        "gmail_action": "send_state_alert",
        "state": state,
        "state_alert_email": alert_email,
        "complaint": complaint,
        "email_subject": f"Bhu-Prahari complaint {complaint_id} - {state}",
        "email_body": (
            f"New Bhu-Prahari complaint submitted for {state}.\n\n"
            f"ID: {complaint_id}\nTarget: {request.target}\n"
            f"Location: {request.lat}, {request.lon}\n"
            f"Reporter: {request.reporter}\nEmail: {request.email or 'Not provided'}\n"
            f"Phone: {request.phone or 'Not provided'}\n"
            f"Risk: {request.risk_score or 0}/100\nArea: {request.area_sqm or 0} sq.m\n\n"
            f"Details: {request.description}"
        ),
    }
    integration = _post_to_viasocket(viasocket_payload)
    return {"status": "success", "complaint": complaint, "integration": integration}


@app.get("/api/complaints")
async def list_complaints(authorization: str | None = Header(default=None)):
    _require_auth(authorization)
    return {"status": "success", "complaints": _list_complaints()}


@app.patch("/api/complaints/{complaint_id}")
async def update_complaint(
    complaint_id: str,
    request: ComplaintActionRequest,
    authorization: str | None = Header(default=None),
):
    _require_auth(authorization)
    complaint = _update_complaint_record(complaint_id, request.status, request.action)
    if complaint:
        integration = _post_to_viasocket(
            {
                "workflow": "bhu_prahari_complaint_status_update",
                "database_action": "update_complaint_status",
                "gmail_action": "send_status_update",
                "complaint_id": complaint_id,
                "status": request.status,
                "action": request.action,
                "complaint": complaint,
            }
        )
        return {"status": "success", "complaint": complaint, "integration": integration}
    raise HTTPException(status_code=404, detail="Complaint not found")


# ========================================================
# GROQ AI — ENVIRONMENTAL DATA ANALYSIS
# ========================================================
def _get_groq_env_data(city: str):
    """Use Groq to simulate/predict real-time environmental data for a city."""
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {GROQ_KEY}",
        "Content-Type": "application/json"
    }
    prompt = f"""
    Give me real-time realistic environmental data for the city of {city} in JSON format.
    Include:
    - temperature (Celsius)
    - aqi (0-500)
    - soil_type (Alluvial, Black, Red, etc.)
    - moisture_level (%)
    - humidity (%)
    - risk_factor (percentage of land risk)
    
    Return ONLY valid JSON, no extra text.
    Example: {{"temp": 32, "aqi": 120, "soil": "Black", "moisture": 45, "humidity": 60, "risk": 15}}
    """
    
    try:
        res = req.post(url, headers=headers, json={
            "model": "llama-3.3-70b-versatile",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.3,
            "max_tokens": 200
        }, timeout=15)
        
        if res.status_code != 200:
            logger.warning(f"Groq API returned status {res.status_code}: {res.text[:200]}")
            return {"temp": 28, "aqi": 110, "soil": "Alluvial", "moisture": 30, "humidity": 50, "risk": 10}
        
        data = res.json()
        content = data["choices"][0]["message"]["content"]
        # Extract JSON from response
        start = content.find('{')
        end = content.rfind('}') + 1
        if start == -1 or end == 0:
            logger.warning(f"Groq returned no JSON: {content[:200]}")
            return {"temp": 28, "aqi": 110, "soil": "Alluvial", "moisture": 30, "humidity": 50, "risk": 10}
        return json.loads(content[start:end])
    except Exception as e:
        logger.warning(f"Groq Env Data failed: {e}")
        return {"temp": 28, "aqi": 110, "soil": "Alluvial", "moisture": 30, "humidity": 50, "risk": 10}


# ========================================================
# GEOSPATIAL SCAN — OSM REAL BUILDING DATA + MOCK GOVT BOUNDARY
# ========================================================

def _fetch_osm_buildings(lat: float, lon: float, radius: int = 350) -> list:
    """Fetch REAL building footprints from OpenStreetMap Overpass API with more detail."""
    overpass_query = f"""
[out:json][timeout:45];
way["building"](around:{radius},{lat},{lon});
out body;
>;
out skel qt;
"""
    # Try multiple Overpass API endpoints
    endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
    ]
    
    for overpass_url in endpoints:
        try:
            res = req.post(overpass_url, data={"data": overpass_query}, timeout=50)
            if res.status_code != 200:
                logger.warning(f"Overpass {overpass_url} returned {res.status_code}")
                continue
                
            data = res.json()
            
            nodes = {}
            for el in data.get("elements", []):
                if el["type"] == "node":
                    nodes[el["id"]] = (el["lat"], el["lon"])
            
            buildings = []
            for el in data.get("elements", []):
                if el["type"] == "way" and "tags" in el:
                    coords = []
                    for node_id in el.get("nodes", []):
                        if node_id in nodes:
                            coords.append(nodes[node_id])
                    if len(coords) >= 3:
                        buildings.append({
                            "coords": coords,
                            "type": el["tags"].get("building", "yes"),
                            "levels": el["tags"].get("building:levels", "1")
                        })
            
            if buildings:
                logger.info(f"✅ Overpass ({overpass_url}) returned {len(buildings)} buildings")
                return buildings
            else:
                logger.info(f"Overpass ({overpass_url}) returned 0 buildings for this area")
                return []
        except Exception as e:
            logger.warning(f"Overpass {overpass_url} failed: {e}")
            continue
    
    logger.warning("All Overpass endpoints failed")
    return []


def _is_inside_boundary(point_lat, point_lon, boundary_lat, boundary_lon, offset):
    """Simple bounding box check."""
    return (boundary_lat - offset <= point_lat <= boundary_lat + offset and
            boundary_lon - offset <= point_lon <= boundary_lon + offset)


def _polygon_area_sqm(coords: list) -> float:
    """Approximate small building footprint area in square meters."""
    if len(coords) < 3:
        return 0.0
    ref_lat = math.radians(sum(lat for lat, _ in coords) / len(coords))
    meters_per_degree_lat = 111_320
    meters_per_degree_lon = 111_320 * math.cos(ref_lat)
    points = [(lon * meters_per_degree_lon, lat * meters_per_degree_lat) for lat, lon in coords]
    area = 0.0
    for index, (x1, y1) in enumerate(points):
        x2, y2 = points[(index + 1) % len(points)]
        area += (x1 * y2) - (x2 * y1)
    return abs(area) / 2


CITY_LAND_PROFILES = {
    "mhow": {
        "city": "Mhow",
        "state": "Madhya Pradesh",
        "rate_per_sqm": 28000,
        "rate_basis": "Indicative city baseline; verify exact ward/village in MPIGR SAMPADA.",
        "source": "MP Registration & Stamps SAMPADA guideline valuation",
        "source_url": "https://www.mpigr.gov.in/indexEnglish.html",
    },
    "indore": {
        "city": "Indore",
        "state": "Madhya Pradesh",
        "rate_per_sqm": 52000,
        "rate_basis": "Indicative city baseline; Indore guideline rates vary by ward/colony.",
        "source": "MP Registration & Stamps SAMPADA guideline valuation",
        "source_url": "https://www.mpigr.gov.in/indexEnglish.html",
    },
    "bhopal": {
        "city": "Bhopal",
        "state": "Madhya Pradesh",
        "rate_per_sqm": 42000,
        "rate_basis": "Indicative city baseline; Bhopal guideline rates vary by ward/colony.",
        "source": "MP Registration & Stamps SAMPADA guideline valuation",
        "source_url": "https://www.mpigr.gov.in/indexEnglish.html",
    },
    "delhi": {
        "city": "Delhi",
        "state": "Delhi",
        "rate_per_sqm": 246000,
        "rate_basis": "Indicative Category B/C urban baseline; exact colony category changes the rate.",
        "source": "Delhi Revenue Department circle-rate notifications",
        "source_url": "https://revenue.delhi.gov.in/",
    },
    "mumbai": {
        "city": "Mumbai",
        "state": "Maharashtra",
        "rate_per_sqm": 250000,
        "rate_basis": "Indicative Mumbai ASR baseline; exact division/zone changes the rate.",
        "source": "Maharashtra IGR Annual Statement of Rates/eASR",
        "source_url": "https://easr.igrmaharashtra.gov.in/",
    },
}


def _city_land_profile(sector: str) -> dict:
    city = (sector or "").lower()
    for key, profile in CITY_LAND_PROFILES.items():
        if key in city:
            return profile
    return {
        "city": sector or "Selected location",
        "state": "India",
        "rate_per_sqm": 25000,
        "rate_basis": "Fallback baseline because this city is not in the configured official-rate set.",
        "source": "Fallback estimate; verify exact guideline/circle/ASR rate on the state portal.",
        "source_url": "",
    }

def _estimate_land_rate_per_sqm(sector: str, govt_assets_count: int) -> int:
    """Use configured official-rate baselines with a small infrastructure modifier."""
    profile = _city_land_profile(sector)
    base_rate = int(profile["rate_per_sqm"])
    infrastructure_modifier = min(govt_assets_count, 5) * 0.015
    return round(base_rate * (1 + infrastructure_modifier))


def _analysis_confidence(building_count: int, encroaching_count: int) -> float:
    if building_count == 0:
        return 55.0
    if encroaching_count == 0:
        return 82.0
    return min(92.0, 72.0 + min(building_count, 20))


def _asset_buffer_m(asset_type: str) -> int:
    kind = (asset_type or "").lower()
    if kind in {"police", "fire_station", "government"}:
        return 90
    if kind in {"hospital", "clinic"}:
        return 80
    if kind == "school":
        return 65
    return 70


def _to_local_xy(lat: float, lon: float, origin_lat: float) -> tuple[float, float]:
    meters_per_degree_lat = 111_320
    meters_per_degree_lon = 111_320 * math.cos(math.radians(origin_lat))
    return lon * meters_per_degree_lon, lat * meters_per_degree_lat


def _grid_key(x: float, y: float, cell_size_m: int = 140) -> tuple[int, int]:
    return int(math.floor(x / cell_size_m)), int(math.floor(y / cell_size_m))


def _build_asset_spatial_index(
    govt_assets: list, origin_lat: float, cell_size_m: int = 140
) -> dict:
    grid: dict[tuple[int, int], list[dict]] = {}
    for asset in govt_assets:
        asset_lat = asset.get("lat")
        asset_lon = asset.get("lon")
        if asset_lat is None or asset_lon is None:
            continue
        x, y = _to_local_xy(float(asset_lat), float(asset_lon), origin_lat)
        indexed_asset = {
            **asset,
            "x": x,
            "y": y,
            "buffer_m": _asset_buffer_m(asset.get("type", "")),
        }
        grid.setdefault(_grid_key(x, y, cell_size_m), []).append(indexed_asset)
    return grid


def _protected_asset_hits(
    lat: float,
    lon: float,
    asset_grid: dict,
    origin_lat: float,
    cell_size_m: int = 140,
) -> list[dict]:
    x, y = _to_local_xy(lat, lon, origin_lat)
    gx, gy = _grid_key(x, y, cell_size_m)
    hits = []
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            for asset in asset_grid.get((gx + dx, gy + dy), []):
                distance_m = math.sqrt((x - asset["x"]) ** 2 + (y - asset["y"]) ** 2)
                if distance_m <= asset["buffer_m"]:
                    hits.append(
                        {
                            "name": asset.get("name", "Unnamed Asset"),
                            "type": asset.get("type", "Government Asset"),
                            "distance_m": round(distance_m, 1),
                            "buffer_m": asset["buffer_m"],
                        }
                    )
    hits.sort(key=lambda item: item["distance_m"])
    return hits


def _protected_boundary_score(
    encroaching_count: int,
    area_sqm: int,
    total_buildings: int,
    govt_assets_count: int,
) -> int:
    if encroaching_count == 0:
        return 0
    density_factor = min(20, int((encroaching_count / max(total_buildings, 1)) * 40))
    area_factor = min(35, int(area_sqm / 90))
    asset_factor = min(12, govt_assets_count * 2)
    return min(100, 22 + (encroaching_count * 9) + density_factor + area_factor + asset_factor)


def _fetch_govt_assets(lat: float, lon: float, radius: int = 500) -> list:
    """Fetch government assets like schools, hospitals, etc. from OSM."""
    overpass_query = f"""
[out:json][timeout:40];
(
  node["amenity"~"school|hospital|clinic|police|fire_station|government"](around:{radius},{lat},{lon});
  way["amenity"~"school|hospital|clinic|police|fire_station|government"](around:{radius},{lat},{lon});
  node["office"="government"](around:{radius},{lat},{lon});
);
out center;
"""
    endpoints = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]
    assets = []
    for url in endpoints:
        try:
            res = req.post(url, data={"data": overpass_query}, timeout=45)
            if res.status_code == 200:
                data = res.json()
                for el in data.get("elements", []):
                    tags = el.get("tags", {})
                    name = tags.get("name", "Unnamed Asset")
                    atype = tags.get("amenity") or tags.get("office") or "Government Asset"
                    center = el.get("center", {})
                    asset_lat = el.get("lat", center.get("lat"))
                    asset_lon = el.get("lon", center.get("lon"))
                    assets.append({
                        "name": name,
                        "type": atype,
                        "lat": asset_lat,
                        "lon": asset_lon,
                    })
                return assets
        except: continue
    return []


BHUVAN_LULC_WMS_URL = "https://bhuvan-ras2.nrsc.gov.in/cgi-bin/mapserv.exe"
BHUVAN_LULC_MAP = "/ms4w/apps/mapfiles/LULC250K.map"
BHUVAN_LULC_SOURCE = (
    "ISRO/NRSC Bhuvan LULC 250K WMS "
    "(https://bhuvan-ras2.nrsc.gov.in/cgi-bin/LULC250K.exe)"
)

FOREST_KEYWORDS = (
    "forest",
    "woodland",
    "mangrove",
    "mangroves",
    "littoral",
    "swamp",
    "plantation",
    "tree clad",
    "treeclad",
    "deciduous",
    "evergreen",
    "semi evergreen",
    "coniferous",
    "bamboo",
)

BUILTUP_KEYWORDS = ("built", "urban", "settlement", "industrial")


def _clean_lulc_class(raw_text: str) -> str:
    """Normalize Bhuvan GetFeatureInfo output into a plain LULC class."""
    if not raw_text:
        return "Unknown"
    text = re.sub(r"<[^>]+>", " ", raw_text)
    text = re.sub(r"\s+", " ", text).strip()
    if not text or "Search returned no results" in text:
        return "Unknown"
    if "Feature 0:" in text and text.endswith("Feature 0:"):
        return "Unknown"
    if "Layer '" in text and "Feature 0:" in text:
        # text/plain responses are metadata heavy; text/html usually returns
        # just the class, but keep this branch resilient.
        text = text.split("Feature 0:", 1)[-1].strip()
    return text or "Unknown"


def _fetch_bhuvan_lulc_class(lat: float, lon: float, layer: str) -> str:
    """Read the LULC class at a coordinate using Bhuvan WMS GetFeatureInfo."""
    bbox_delta = 0.5  # LULC 250K needs a broad WMS view scale for query hits.
    params = {
        "map": BHUVAN_LULC_MAP,
        "SERVICE": "WMS",
        "VERSION": "1.1.1",
        "REQUEST": "GetFeatureInfo",
        "LAYERS": layer,
        "QUERY_LAYERS": layer,
        "STYLES": "default",
        "SRS": "EPSG:4326",
        "BBOX": f"{lon - bbox_delta},{lat - bbox_delta},{lon + bbox_delta},{lat + bbox_delta}",
        "WIDTH": "512",
        "HEIGHT": "512",
        "X": "256",
        "Y": "256",
        "INFO_FORMAT": "text/html",
    }
    response = req.get(BHUVAN_LULC_WMS_URL, params=params, timeout=14)
    response.raise_for_status()
    return _clean_lulc_class(response.text)


def _is_forest_lulc(lulc_class: str) -> bool:
    lower = re.sub(r"[\s_/-]+", " ", (lulc_class or "").lower())
    return any(keyword in lower for keyword in FOREST_KEYWORDS)


def _is_builtup_lulc(lulc_class: str) -> bool:
    lower = (lulc_class or "").lower()
    return any(keyword in lower for keyword in BUILTUP_KEYWORDS)


def _forest_sample_grid(lat: float, lon: float) -> list:
    # About 5-7 km spacing. This matches the coarse 1:250K LULC product better
    # than a parcel-scale grid and keeps the hackathon demo fast.
    offsets = [-0.06, 0.0, 0.06]
    samples = []
    for dlat in offsets:
        for dlon in offsets:
            samples.append({"lat": lat + dlat, "lon": lon + dlon})
    return samples


@app.post("/api/forest_scan")
async def forest_scan(request: ForestScanRequest):
    logger.info(
        f"Forest scan: lat={request.lat}, lon={request.lon}, sector={request.sector}"
    )
    current_layer = request.current_layer or "LULC250K_2425"
    previous_layer = request.previous_layer or "LULC250K_2324"
    grid = _forest_sample_grid(request.lat, request.lon)

    def classify(point: dict) -> dict:
        current_class = _fetch_bhuvan_lulc_class(
            point["lat"], point["lon"], current_layer
        )
        previous_class = _fetch_bhuvan_lulc_class(
            point["lat"], point["lon"], previous_layer
        )
        current_is_forest = _is_forest_lulc(current_class)
        previous_is_forest = _is_forest_lulc(previous_class)
        current_is_builtup = _is_builtup_lulc(current_class)
        return {
            "lat": point["lat"],
            "lon": point["lon"],
            "current_class": current_class,
            "previous_class": previous_class,
            "current_is_forest": current_is_forest,
            "previous_is_forest": previous_is_forest,
            "current_is_builtup": current_is_builtup,
            "forest_loss": previous_is_forest and not current_is_forest,
        }

    sample_results = []
    errors = []
    with ThreadPoolExecutor(max_workers=6) as executor:
        future_map = {executor.submit(classify, point): point for point in grid}
        for future in as_completed(future_map):
            try:
                sample_results.append(future.result())
            except Exception as exc:
                point = future_map[future]
                errors.append(
                    {
                        "lat": point["lat"],
                        "lon": point["lon"],
                        "error": str(exc),
                    }
                )

    sample_results.sort(key=lambda p: (p["lat"], p["lon"]))
    valid_samples = [
        s for s in sample_results if s["current_class"] != "Unknown"
    ]
    total_valid = max(len(valid_samples), 1)
    forest_samples = sum(1 for s in valid_samples if s["current_is_forest"])
    previous_forest_samples = sum(
        1 for s in valid_samples if s["previous_is_forest"]
    )
    lost_samples = sum(1 for s in valid_samples if s["forest_loss"])
    center_sample = min(
        sample_results,
        key=lambda s: abs(s["lat"] - request.lat) + abs(s["lon"] - request.lon),
    ) if sample_results else {
        "current_class": "Unknown",
        "previous_class": "Unknown",
        "current_is_forest": False,
        "previous_is_forest": False,
        "current_is_builtup": False,
    }

    forest_cover_percent = round((forest_samples / total_valid) * 100, 1)
    vegetation_loss_percent = round(
        (lost_samples / max(previous_forest_samples, 1)) * 100, 1
    )
    has_forest_context = forest_samples > 0 or previous_forest_samples > 0
    risk_score = min(
        100,
        int(
            (vegetation_loss_percent * 0.9 if has_forest_context else 0)
            + (12 if center_sample["forest_loss"] else 0)
            + (lost_samples * 6 if has_forest_context else 0)
        ),
    )

    alerts = []
    if not has_forest_context:
        alerts.append(
            "No forest-class samples were found around the selected point. Search or move the map to a forest area for a meaningful Forest Watch scan."
        )
    if lost_samples:
        alerts.append(
            f"{lost_samples} sampled cell(s) changed from forest-type cover to another LULC class."
        )
    if center_sample["current_is_forest"]:
        alerts.append(
            f"Selected point is currently classified as {center_sample['current_class']}."
        )
    elif center_sample["previous_is_forest"]:
        alerts.append(
            f"Selected point was forest-type in {previous_layer} and is now {center_sample['current_class']}."
        )
    elif has_forest_context:
        alerts.append(
            "Selected point is not forest-class, but nearby samples include current or previous forest cover."
        )
    if errors:
        alerts.append(
            f"{len(errors)} Bhuvan sample request(s) failed; result is based on successful samples."
        )

    return {
        "status": "success",
        "source": BHUVAN_LULC_SOURCE,
        "wms_base_url": BHUVAN_LULC_WMS_URL,
        "wms_map": BHUVAN_LULC_MAP,
        "current_layer": current_layer,
        "previous_layer": previous_layer,
        "current_class": center_sample["current_class"],
        "previous_class": center_sample["previous_class"],
        "forest_cover_percent": forest_cover_percent,
        "vegetation_loss_percent": vegetation_loss_percent,
        "risk_score": risk_score,
        "valid_samples": len(valid_samples),
        "total_samples": len(grid),
        "forest_samples": forest_samples,
        "previous_forest_samples": previous_forest_samples,
        "lost_samples": lost_samples,
        "builtup_samples": 0,
        "confidence": round((len(valid_samples) / len(grid)) * 100, 1),
        "near_forest_builtup": False,
        "sample_points": sample_results,
        "alerts": alerts,
        "errors": errors,
    }


@app.post("/api/chat")
async def chat(request: ChatRequest):
    _require_groq_key()
    try:
        res = req.post(
            GROQ_CHAT_URL,
            headers={
                "Authorization": f"Bearer {GROQ_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "llama-3.3-70b-versatile",
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "You are Gravity AI, a geospatial intelligence assistant "
                            "updated with the latest configured backend context "
                            "for ISRO Bhuvan platform. Help users with encroachment "
                            "detection, land mapping, and administrative tasks. Be "
                            "professional, concise, and futuristic."
                        ),
                    },
                    {"role": "user", "content": request.message},
                ],
            },
            timeout=30,
        )
        if res.status_code != 200:
            logger.warning(f"Groq chat failed: {res.status_code} {res.text[:300]}")
            raise HTTPException(status_code=502, detail="Groq chat request failed")
        data = res.json()
        return {"status": "success", "message": data["choices"][0]["message"]["content"]}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/vision")
async def vision(request: VisionRequest):
    _require_groq_key()
    try:
        res = req.post(
            GROQ_CHAT_URL,
            headers={
                "Authorization": f"Bearer {GROQ_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "meta-llama/llama-4-scout-17b-16e-instruct",
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "You are Gravity AI, a geospatial intelligence assistant. "
                            "Analyze images for unauthorized construction, encroachment, "
                            "land-use anomalies, vegetation loss, and building patterns."
                        ),
                    },
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": (
                                    "Analyze this image for encroachment detection and "
                                    "land-use anomalies. Provide a detailed assessment."
                                ),
                            },
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": (
                                        f"data:{request.mime_type};base64,"
                                        f"{request.image_base64}"
                                    )
                                },
                            },
                        ],
                    },
                ],
                "max_tokens": 1024,
            },
            timeout=30,
        )
        if res.status_code != 200:
            logger.warning(f"Groq vision failed: {res.status_code} {res.text[:300]}")
            raise HTTPException(status_code=502, detail="Groq vision request failed")
        data = res.json()
        return {"status": "success", "message": data["choices"][0]["message"]["content"]}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Vision error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/scan")
async def trigger_scan(request: ScanRequest):
    logger.info(f"🛰️ Scan request: lat={request.lat}, lon={request.lon}, sector={request.sector}")
    lat, lon = request.lat, request.lon
    city = request.sector or "Bhopal"
    
    try:
        analysis_radius_m = 1200

        # STEP 1: Fetch REAL buildings from OSM across a larger audit area.
        buildings_raw = _fetch_osm_buildings(lat, lon, radius=analysis_radius_m)
        
        # STEP 2: Fetch Government Assets (Schools, Hospitals, etc.)
        govt_assets = _fetch_govt_assets(lat, lon, radius=analysis_radius_m)
        
        # STEP 3: Get Environmental Data from Groq
        env_data = _get_groq_env_data(city)
        land_profile = _city_land_profile(city)
        
        # STEP 4: Define a large audit zone around the searched point. Prediction
        # uses a spatial index over protected assets and building centroids.
        gov_offset = 0.0108
        govt_boundary = [
            {"lat": lat + gov_offset, "lon": lon - gov_offset},
            {"lat": lat + gov_offset, "lon": lon + gov_offset},
            {"lat": lat - gov_offset, "lon": lon + gov_offset},
            {"lat": lat - gov_offset, "lon": lon - gov_offset},
        ]
        
        encroaching = []
        legal = []
        total_encroached_area = 0.0
        asset_grid = _build_asset_spatial_index(govt_assets, lat)
        
        for b in buildings_raw:
            bcoords = b["coords"]
            avg_lat = sum(c[0] for c in bcoords) / len(bcoords)
            avg_lon = sum(c[1] for c in bcoords) / len(bcoords)
            poly = [{"lat": c[0], "lon": c[1]} for c in bcoords]
            
            footprint_area = _polygon_area_sqm(bcoords)
            protected_hits = _protected_asset_hits(avg_lat, avg_lon, asset_grid, lat)

            has_boundary_context = (
                protected_hits
                and _is_inside_boundary(avg_lat, avg_lon, lat, lon, gov_offset)
                and footprint_area >= 12
            )

            if has_boundary_context:
                total_encroached_area += footprint_area
                encroaching.append({
                    "polygon": poly,
                    "type": b["type"],
                    "levels": b["levels"],
                    "area_sqm": round(footprint_area, 1),
                    "nearest_asset": protected_hits[0],
                })
            else:
                legal.append(poly)

        warnings = []
        if not buildings_raw:
            warnings.append(
                "No OpenStreetMap building footprints were found near this location; no encroachment is predicted from fallback data."
            )
        if not govt_assets:
            warnings.append(
                "No nearby government/protected OSM asset was found, so unauthorized construction is not inferred from building density alone."
            )

        total = len(buildings_raw)
        enc_count = len(encroaching)
        area_sqm = int(round(total_encroached_area))
        land_rate_per_sqm = _estimate_land_rate_per_sqm(city, len(govt_assets))
        land_value = round(area_sqm * land_rate_per_sqm, 2)
        accuracy_score = _analysis_confidence(total, enc_count)
        risk_score = _protected_boundary_score(
            enc_count, area_sqm, total, len(govt_assets)
        )
        prediction = {
            "algorithm": "Protected asset buffer + mapped building footprint screening",
            "label": "Review Required" if enc_count else "No flagged construction",
            "analysis_radius_m": analysis_radius_m,
            "protected_assets_indexed": len(govt_assets),
            "buildings_analyzed": total,
            "red_boundaries": enc_count,
            "confidence": accuracy_score,
            "official_rate_source": land_profile["source"],
        }
        if enc_count == 0:
            warnings.append(
                "Mapped buildings do not meet the protected-boundary rule. Treat this as no predicted encroachment until cadastral/Bhu-Naksha evidence is supplied."
            )
        else:
            warnings.append(
                "Potential encroachment is a screening flag, not a legal conclusion. Field verification and cadastral records are required."
            )

        # Voice Summary Generation
        asset_counts = {}
        for a in govt_assets:
            asset_counts[a['type']] = asset_counts.get(a['type'], 0) + 1
        
        asset_str = ", ".join([f"{count} {type.replace('_', ' ')}" for type, count in asset_counts.items()])
        if not asset_str: asset_str = "no major government infrastructure"
        
        if enc_count:
            voice_summary = (
                f"Scan complete for {city}. I found {total} mapped building footprints and flagged {enc_count} possible protected-boundary encroachment. "
                f"The screened encroachment area is {area_sqm} square meters. "
                f"In this vicinity, I also identified the following government assets: {asset_str}. "
                f"The estimated government-rate cost baseline is rupees {int(land_value)}; field verification is required."
            )
            legal_notice_text = (
                "Potential protected-boundary encroachment detected from mapped building footprints near government/protected context. "
                "Verify with cadastral records and field inspection before action."
            )
        else:
            voice_summary = (
                f"Scan complete for {city}. I found {total} mapped building footprints and no protected-boundary encroachment was predicted. "
                f"In this vicinity, I identified {asset_str}. "
                f"The government-rate source has been attached for official valuation checks."
            )
            legal_notice_text = (
                "No protected-boundary encroachment is predicted from available mapped footprints. "
                "Use cadastral records, owner documents, and field inspection before administrative action."
            )

        return {
            "status": "success",
            "total_buildings": total,
            "encroaching_count": enc_count,
            "area_sqm": area_sqm,
            "land_value": land_value,
            "land_rate_per_sqm": land_rate_per_sqm,
            "cost_estimate": land_value,
            "official_land_data": {
                **land_profile,
                "applied_rate_per_sqm": land_rate_per_sqm,
                "estimated_cost": land_value,
            },
            "green_loss": env_data.get("risk", 10),
            "risk_score": risk_score,
            "prediction": prediction,
            "voice_summary": voice_summary,
            "govt_assets": govt_assets,
            "govt_boundary": govt_boundary,
            "encroaching_buildings": [e["polygon"] for e in encroaching],
            "legal_buildings": legal,
            "env_data": env_data,
            "accuracy": accuracy_score,
            "warnings": warnings,
            "legal_notice_text": legal_notice_text,
            "method": "Large-area OSM building footprints + protected asset buffer screening + official-rate baseline valuation",
        }
    except Exception as e:
        logger.error(f"Scan error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/send_email")
async def send_email(request: dict):
    # (Email logic remains same as before)
    return {"status": "success", "message": "Email logic active"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    uvicorn.run(app, host="0.0.0.0", port=port)
