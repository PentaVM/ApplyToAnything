"""Búsqueda determinista de empleo: agrega ofertas de bolsas públicas.

Proveedores sin clave (funcionan de inmediato):
  - Remotive   (https://remotive.com/api/remote-jobs)      — remoto global
  - Arbeitnow  (https://www.arbeitnow.com/api/job-board-api) — Europa/general
  - RemoteOK   (https://remoteok.com/api)                  — remoto global

Proveedores con clave gratuita opcional (configurar en .env):
  - Adzuna     (por país, requiere app_id + app_key de https://developer.adzuna.com)
  - Jooble     (por país, requiere key de https://jooble.org/api/about)
"""
import asyncio
import re
from datetime import datetime, timezone

import httpx

from . import config

UA = {
    "User-Agent": "ApplyToAnything/1.0 (+https://github.com/PentaVM/ApplyToAnything)",
    "Accept": "application/json",
}

COUNTRIES = {
    "xx": "Remoto (Global)",
    "ar": "Argentina", "bo": "Bolivia", "br": "Brasil", "ca": "Canadá", "cl": "Chile",
    "co": "Colombia", "cr": "Costa Rica", "de": "Alemania", "do": "República Dominicana",
    "ec": "Ecuador", "es": "España", "fr": "Francia", "gb": "Reino Unido", "gt": "Guatemala",
    "ie": "Irlanda", "in": "India", "it": "Italia", "mx": "México", "nl": "Países Bajos",
    "pe": "Perú", "pl": "Polonia", "pt": "Portugal", "py": "Paraguay", "sv": "El Salvador",
    "uy": "Uruguay", "us": "Estados Unidos", "ve": "Venezuela", "za": "Sudáfrica",
    "au": "Australia",
}

ADZUNA_COUNTRIES = {
    "ar", "au", "at", "be", "br", "ca", "ch", "cl", "co", "cr", "cz", "de", "dk", "ec",
    "es", "fr", "gb", "gr", "hk", "ie", "in", "it", "jp", "kr", "mx", "my", "nl", "no",
    "nz", "pe", "pl", "pt", "ru", "sg", "th", "tr", "us", "uy", "ve", "za",
}
JOOBLE_COUNTRIES = set(COUNTRIES) - {"xx"}

DEFAULT_SOURCES = ["remotive", "arbeitnow", "remoteok", "adzuna", "jooble"]


def _clean_html(text: str, limit: int = 1200) -> str:
    if not text:
        return ""
    text = re.sub(r"<[^>]+>", " ", str(text))
    text = re.sub(r"&[a-zA-Z#0-9]+;", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text[:limit] + ("…" if len(text) > limit else "")


def _iso(ts) -> str:
    if not ts:
        return ""
    try:
        if isinstance(ts, (int, float)):
            return datetime.fromtimestamp(float(ts), tz=timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ")
        s = str(ts)
        if s.isdigit():
            return datetime.fromtimestamp(float(s), tz=timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ")
        return s
    except Exception:
        return ""


def _job(jid, title, company, url, source, description="", location="", country="",
         remote=False, salary="", tags=None, posted_at=""):
    if not title or not company or not url:
        return None
    blob = (str(location) + " " + str(description)[:400]).lower()
    is_remote = bool(remote) or "remote" in blob or "work from home" in blob
    clean_tags = [str(t) for t in (tags or []) if t][:8]
    return {
        "id": f"{source}:{jid}",
        "title": str(title).strip()[:150],
        "company": str(company).strip()[:100],
        "url": str(url),
        "source": source,
        "description": _clean_html(description),
        "location": str(location or "").strip()[:120],
        "country": (country or "xx").lower(),
        "remote": is_remote,
        "salary": str(salary or "").strip()[:80],
        "tags": clean_tags,
        "posted_at": _iso(posted_at),
    }


async def _get_json(client: httpx.AsyncClient, url: str, **kwargs):
    r = await client.get(url, timeout=20, **kwargs)
    r.raise_for_status()
    return r.json()


async def fetch_remotive(client, q, page=1):
    data = await _get_json(
        client, "https://remotive.com/api/remote-jobs",
        params={"search": (q or "").strip(), "limit": "60"})
    out = []
    for j in data.get("jobs", []):
        out.append(_job(
            j.get("id"), j.get("title"), j.get("company_name"), j.get("url"), "remotive",
            description=j.get("description") or "",
            location=j.get("candidate_required_location") or "",
            country="xx", remote=True,
            salary=j.get("salary") or "",
            tags=[j.get("category") or ""],
            posted_at=j.get("publication_date")))
    return out


async def fetch_arbeitnow(client, q, page=1):
    data = await _get_json(client, "https://www.arbeitnow.com/api/job-board-api",
                           params={"page": max(1, page)})
    out = []
    for j in data.get("data", []):
        out.append(_job(
            j.get("slug"), j.get("title"), j.get("company_name"), j.get("url"), "arbeitnow",
            description=j.get("description") or "",
            location=j.get("location") or "",
            country="de", remote=bool(j.get("remote")),
            tags=(j.get("tags") or []) + (j.get("job_types") or []),
            posted_at=j.get("created_at")))
    return out


async def fetch_remoteok(client, q, page=1):
    data = await _get_json(client, "https://remoteok.com/api")
    out = []
    for j in data:
        if not isinstance(j, dict) or "position" not in j:
            continue  # el primer elemento es el aviso legal
        sal = ""
        smin, smax = j.get("salary_min"), j.get("salary_max")
        if smin and smax:
            sal = f"{int(smin):,} - {int(smax):,} USD".replace(",", ".")
        out.append(_job(
            j.get("slug") or j.get("id"), j.get("position"), j.get("company"), j.get("url"),
            "remoteok",
            description=j.get("description") or "",
            location=j.get("location") or "",
            country="xx", remote=True, salary=sal,
            tags=j.get("tags") or [],
            posted_at=j.get("date")))
    return out


async def fetch_adzuna(client, q, country, page=1):
    if not (config.ADZUNA_APP_ID and config.ADZUNA_APP_KEY):
        return []
    if country not in ADZUNA_COUNTRIES:
        return []
    url = f"https://api.adzuna.com/v1/api/jobs/{country}/search/{max(1, page)}"
    params = {
        "app_id": config.ADZUNA_APP_ID,
        "app_key": config.ADZUNA_APP_KEY,
        "results_per_page": "30",
        "content-type": "application/json",
    }
    if q:
        params["what"] = q
    data = await _get_json(client, url, params=params)
    out = []
    for j in data.get("results", []):
        comp = (j.get("company") or {}).get("display_name", "")
        loc = (j.get("location") or {}).get("display_name", "")
        sal = ""
        smin, smax = j.get("salary_min") or 0, j.get("salary_max") or 0
        if smax and smax > 1:
            sal = f"{int(smin)} - {int(smax)}"
        out.append(_job(
            j.get("id"), j.get("title"), comp, j.get("redirect_url"), "adzuna",
            description=j.get("description") or "",
            location=loc, country=country,
            salary=sal,
            tags=[(j.get("category") or {}).get("label", "")],
            posted_at=j.get("created")))
    return out


async def fetch_jooble(client, q, country, page=1):
    if not config.JOOBLE_API_KEY:
        return []
    if country not in JOOBLE_COUNTRIES:
        return []
    r = await client.post(
        f"https://jooble.org/api/{config.JOOBLE_API_KEY}",
        json={"keywords": (q or "").strip(), "location": COUNTRIES[country],
              "page": max(1, page)},
        timeout=20)
    r.raise_for_status()
    data = r.json()
    out = []
    for j in data.get("jobs", []):
        out.append(_job(
            j.get("id") or j.get("link"), j.get("title"), j.get("company"), j.get("link"),
            "jooble",
            description=j.get("snippet") or "",
            location=j.get("location") or "",
            country=country,
            salary=j.get("salary") or "",
            posted_at=j.get("updated")))
    return out


async def search_all(q="", countries=None, remote_only=False, page=1, sources=None):
    """Ejecuta todas las consultas en paralelo, deduplica y ordena por fecha."""
    ccs = [c.strip().lower() for c in (countries or []) if c and c.strip()]
    if not ccs:
        ccs = ["xx"]
    srcs = [s for s in (sources or DEFAULT_SOURCES) if s in DEFAULT_SOURCES]

    tasks, names = [], []
    async with httpx.AsyncClient(headers=UA, follow_redirects=True) as client:
        if "remotive" in srcs:
            tasks.append(fetch_remotive(client, q, page))
            names.append("remotive")
        if "arbeitnow" in srcs:
            tasks.append(fetch_arbeitnow(client, q, page))
            names.append("arbeitnow")
        if "remoteok" in srcs:
            tasks.append(fetch_remoteok(client, q, page))
            names.append("remoteok")
        for cc in ccs:
            if cc == "xx":
                continue
            if "adzuna" in srcs:
                tasks.append(fetch_adzuna(client, q, cc, page))
                names.append(f"adzuna:{cc}")
            if "jooble" in srcs:
                tasks.append(fetch_jooble(client, q, cc, page))
                names.append(f"jooble:{cc}")

        results = await asyncio.gather(*tasks, return_exceptions=True)

    jobs, errors = [], []
    for name, res in zip(names, results):
        if isinstance(res, Exception):
            errors.append(f"{name}: {type(res).__name__}")
            continue
        jobs.extend(res)

    seen, uniq = set(), []
    for j in jobs:
        if remote_only and not j["remote"]:
            continue
        key = (j["title"].lower().strip()[:80], j["company"].lower().strip())
        if key in seen:
            continue
        seen.add(key)
        uniq.append(j)

    uniq.sort(key=lambda j: j["posted_at"], reverse=True)
    return uniq, errors
