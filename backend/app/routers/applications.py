"""Postulaciones: registrar, listar y actualizar (guardadas / aplicadas / descartadas)."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from ..db import now, query, execute
from .auth import current_user

router = APIRouter()

VALID_STATUS = {"liked", "applied", "skipped"}


class ApplicationBody(BaseModel):
    job_id: str
    title: str = ""
    company: str = ""
    url: str = ""
    source: str = ""
    country: str = ""
    status: str = "applied"
    method: str = "external_url"
    cover_letter: str = ""


class StatusBody(BaseModel):
    status: str


def _row_dict(r) -> dict:
    return dict(r)


@router.post("/applications")
def upsert_application(body: ApplicationBody, user=Depends(current_user)):
    if body.status not in VALID_STATUS:
        raise HTTPException(status_code=400, detail="Estado no válido")
    execute(
        """INSERT INTO applications
             (user_id, job_id, title, company, url, source, country,
              status, method, cover_letter, created_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)
           ON CONFLICT(user_id, job_id) DO UPDATE SET
             status = excluded.status,
             method = excluded.method,
             cover_letter = excluded.cover_letter""",
        (user["id"], body.job_id[:200], body.title[:150], body.company[:100],
         body.url[:600], body.source[:40], body.country[:10],
         body.status, body.method[:40], body.cover_letter[:20000], now()),
    )
    rows = query(
        "SELECT * FROM applications WHERE user_id = ? AND job_id = ?",
        (user["id"], body.job_id[:200]),
    )
    return {"application": _row_dict(rows[0])}


@router.get("/applications")
def list_applications(user=Depends(current_user), status: str = ""):
    if status and status in VALID_STATUS:
        rows = query(
            "SELECT * FROM applications WHERE user_id = ? AND status = ? ORDER BY id DESC",
            (user["id"], status),
        )
    else:
        rows = query(
            "SELECT * FROM applications WHERE user_id = ? ORDER BY id DESC",
            (user["id"],),
        )
    return {"applications": [_row_dict(r) for r in rows]}


@router.patch("/applications/{app_id}")
def update_status(app_id: int, body: StatusBody, user=Depends(current_user)):
    if body.status not in VALID_STATUS:
        raise HTTPException(status_code=400, detail="Estado no válido")
    cur = execute(
        "UPDATE applications SET status = ? WHERE id = ? AND user_id = ?",
        (body.status, app_id, user["id"]),
    )
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Postulación no encontrada")
    return {"ok": True}


@router.delete("/applications/{app_id}")
def delete_application(app_id: int, user=Depends(current_user)):
    cur = execute(
        "DELETE FROM applications WHERE id = ? AND user_id = ?",
        (app_id, user["id"]),
    )
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="Postulación no encontrada")
    return {"ok": True}
