"""Búsqueda determinista de ofertas (agrega proveedores públicos)."""
from fastapi import APIRouter, Depends, Query

from ..db import get_prefs
from ..providers import search_all
from .auth import current_user

router = APIRouter()


@router.get("/jobs/search")
async def jobs_search(
    user=Depends(current_user),
    q: str = Query("", max_length=120),
    countries: str = Query("", max_length=200),
    remote: str = Query("any", pattern="^(any|only)$"),
    page: int = Query(1, ge=1, le=10),
    sources: str = Query("", max_length=200),
):
    prefs = get_prefs(user["id"])
    ccs = [c.strip().lower() for c in countries.split(",") if c.strip()]
    if not ccs:
        ccs = [str(c).lower() for c in (prefs.get("countries") or []) if c]
    query_text = q.strip()
    if not query_text:
        query_text = str(prefs.get("role") or "")
    if not query_text and prefs.get("keywords"):
        query_text = str(prefs["keywords"][0])
    srcs = [s.strip() for s in sources.split(",") if s.strip()] or None

    jobs, errors = await search_all(
        q=query_text,
        countries=ccs,
        remote_only=(remote == "only"),
        page=page,
        sources=srcs,
    )
    return {
        "jobs": jobs[:60],
        "count": len(jobs[:60]),
        "total_found": len(jobs),
        "errors": errors,
        "query": {"q": query_text, "countries": ccs, "remote": remote, "page": page},
    }
