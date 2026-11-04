"""Account-owned AI jobs. Workers only receive jobs for their paired provider."""

import hashlib
import json
import secrets
import time
import uuid
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, Field, model_validator

from ..db import execute, query
from .auth import bearer, current_user

router = APIRouter(prefix="/ai")
Provider = Literal["codex", "claude", "antigravity", "omniroute", "api", "custom"]
PROVIDERS = ("codex", "claude", "antigravity", "omniroute", "api", "custom")


class Pairing(BaseModel):
    provider: Provider


class Selection(BaseModel):
    provider: Provider | Literal["auto", "api_key"]


class Completion(BaseModel):
    lease: str = Field(max_length=64)
    reply: str | None = Field(default=None, min_length=1, max_length=12000)
    error: bool = False

    @model_validator(mode="after")
    def check_outcome(self):
        if self.error == bool(self.reply and self.reply.strip()):
            raise ValueError("Indica una respuesta o un error")
        return self


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _worker(cred: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if cred and cred.credentials.startswith("ata_worker_") and len(cred.credentials) < 100:
        rows = query("SELECT * FROM ai_connectors WHERE token_hash = ?", (_hash(cred.credentials),))
        if rows:
            return rows[0]
    raise HTTPException(status_code=401, detail="Conector sin acceso")


def selected_provider(user_id):
    rows = query("SELECT provider FROM ai_settings WHERE user_id=?", (user_id,))
    return rows[0]["provider"] if rows else "auto"


@router.get("/connectors")
def list_connectors(user=Depends(current_user)):
    active = {
        row["provider"]: int(time.time()) - row["seen_at"] <= 60
        for row in query("SELECT provider, seen_at FROM ai_connectors WHERE user_id = ?", (user["id"],))
    }
    return {"providers": PROVIDERS, "paired": active, "selected": selected_provider(user["id"])}


@router.put("/provider", status_code=204)
def select_provider(body: Selection, user=Depends(current_user)):
    execute(
        "INSERT INTO ai_settings(user_id, provider) VALUES(?,?) "
        "ON CONFLICT(user_id) DO UPDATE SET provider=excluded.provider",
        (user["id"], body.provider),
    )


@router.post("/connectors")
def pair(body: Pairing, response: Response, user=Depends(current_user)):
    token = "ata_worker_" + secrets.token_urlsafe(32)
    execute(
        "INSERT INTO ai_connectors(user_id, provider, token_hash) VALUES(?, ?, ?) "
        "ON CONFLICT(user_id, provider) DO UPDATE SET token_hash=excluded.token_hash, seen_at=0",
        (user["id"], body.provider, _hash(token)),
    )
    response.headers["Cache-Control"] = "no-store"
    return {"provider": body.provider, "token": token}


@router.delete("/connectors/{provider}", status_code=204)
def revoke(provider: Provider, user=Depends(current_user)):
    execute("DELETE FROM ai_connectors WHERE user_id=? AND provider=?", (user["id"], provider))


def enqueue(user_id: int, provider: str, messages: list) -> dict:
    now = int(time.time())
    execute("DELETE FROM ai_tasks WHERE created_at < ?", (now - 900,))
    task_id = uuid.uuid4().hex
    inserted = execute(
        """INSERT INTO ai_tasks(id, user_id, provider, request, created_at)
           SELECT ?, user_id, provider, ?, ? FROM ai_connectors
           WHERE user_id=? AND provider=? AND seen_at >= ?
           AND (SELECT COUNT(*) FROM ai_tasks
                WHERE user_id=? AND state IN ('queued', 'running') AND created_at >= ?) < 3""",
        (task_id, json.dumps(messages, ensure_ascii=False), now,
         user_id, provider, now - 60, user_id, now - 150),
    )
    if not inserted:
        raise HTTPException(status_code=503, detail="Conector desconectado u ocupado")
    return {"task_id": task_id, "state": "queued"}


@router.post("/worker/claim")
def claim(provider: Provider, response: Response, worker=Depends(_worker)):
    now = int(time.time())
    if provider != worker["provider"]:
        raise HTTPException(status_code=403, detail="El código pertenece a otro proveedor")
    owner, token_hash = worker["user_id"], worker["token_hash"]
    active = execute(
        "UPDATE ai_connectors SET seen_at=? WHERE user_id=? AND provider=? AND token_hash=?",
        (now, owner, provider, token_hash),
    )
    if not active:
        raise HTTPException(status_code=401, detail="Conector sin acceso")
    lease = secrets.token_urlsafe(24)
    rows = query(
        """UPDATE ai_tasks SET state='running', lease=?, lease_until=?
           WHERE id=(SELECT id FROM ai_tasks WHERE user_id=? AND provider=? AND state='queued'
                     AND created_at >= ? ORDER BY created_at, id LIMIT 1)
           AND state='queued' AND EXISTS (
             SELECT 1 FROM ai_connectors WHERE user_id=? AND provider=? AND token_hash=?
           ) RETURNING id, request""",
        (lease, now + 120, owner, provider, now - 60, owner, provider, token_hash),
    )
    response.headers["Cache-Control"] = "no-store"
    if not rows:
        return {"task": None}
    return {"task": {"id": rows[0]["id"], "lease": lease, "messages": json.loads(rows[0]["request"])}}


@router.put("/worker/tasks/{task_id}", status_code=204)
def complete(task_id: str, body: Completion, worker=Depends(_worker)):
    owner, provider = worker["user_id"], worker["provider"]
    if not execute(
        """UPDATE ai_tasks SET state=?, reply=?, request='[]'
           WHERE id=? AND user_id=? AND provider=? AND lease=? AND state='running' AND lease_until>=?
           AND EXISTS (SELECT 1 FROM ai_connectors WHERE user_id=? AND provider=? AND token_hash=?)""",
        ("failed" if body.error else "done", body.reply, task_id, owner, provider,
         body.lease, int(time.time()), owner, provider, worker["token_hash"]),
    ):
        raise HTTPException(status_code=409, detail="La tarea no está disponible")


@router.get("/tasks/{task_id}")
def result(task_id: str, response: Response, user=Depends(current_user)):
    now = int(time.time())
    rows = query("SELECT * FROM ai_tasks WHERE id=? AND user_id=? AND created_at>=?",
                 (task_id, user["id"], now - 900))
    if not rows:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    row = rows[0]
    state = row["state"]
    response.headers["Cache-Control"] = "no-store"
    if state == "done":
        return {"state": state, "reply": row["reply"], "model": row["provider"]}
    if (state == "queued" and now - row["created_at"] > 60) or (
        state == "running" and now > row["lease_until"]
    ):
        return {"state": "failed", "detail": "El conector no respondió a tiempo"}
    if state == "failed":
        return {"state": state, "detail": "El proveedor local no pudo responder"}
    return {"state": state}
