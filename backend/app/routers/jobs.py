"""Búsqueda determinista de ofertas (agrega proveedores públicos)."""
import json
import time

from fastapi import APIRouter, Depends, Query
from starlette.concurrency import run_in_threadpool

from ..db import execute, execute_many, get_prefs
from ..providers import search_all
from .auth import current_user

router = APIRouter()


def remember_jobs(user_id, jobs):
    now = int(time.time())
    execute("DELETE FROM viewed_jobs WHERE user_id=? AND seen_at < ?", (user_id, now - 86400))
    if jobs:
        execute_many(
            """INSERT INTO viewed_jobs(user_id, job_id, payload, seen_at) VALUES(?,?,?,?)
               ON CONFLICT(user_id, job_id) DO UPDATE SET payload=excluded.payload, seen_at=excluded.seen_at""",
            [(user_id, job["id"], json.dumps(job, ensure_ascii=False), now) for job in jobs],
        )


@router.get("/jobs/search")
async def jobs_search(
    user=Depends(current_user),
    q: str = Query("", max_length=120),
    countries: str = Query("", max_length=200),
    remote: str | None = Query(None, pattern="^(any|only)$"),
    page: int = Query(1, ge=1, le=10),
    sources: str = Query("", max_length=200),
):
    prefs = get_prefs(user["id"])
    remote = remote or ("only" if prefs.get("remote_only") is True else "any")
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
        match_title=bool(q.strip()),
    )
    await run_in_threadpool(remember_jobs, user["id"], jobs[:60])
    return {
        "jobs": jobs[:60],
        "count": len(jobs[:60]),
        "total_found": len(jobs),
        "errors": errors,
        "query": {"q": query_text, "countries": ccs, "remote": remote, "page": page},
    }
