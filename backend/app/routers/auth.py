"""Autenticación: registro, login y perfil con preferencias."""
import json
import re

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from .. import config
from ..db import get_prefs, now, query, save_prefs, execute
from ..security import create_token, decode_token, hash_password, verify_password

router = APIRouter()
bearer = HTTPBearer(auto_error=False)

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class Credentials(BaseModel):
    email: str
    password: str
    name: str = ""


class PrefsBody(BaseModel):
    preferences: dict


def current_user(cred: HTTPAuthorizationCredentials = Depends(bearer)):
    if cred is None:
        raise HTTPException(status_code=401, detail="Falta el token de acceso")
    try:
        uid = decode_token(cred.credentials)
    except Exception:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")
    rows = query("SELECT * FROM users WHERE id = ?", (uid,))
    if not rows:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    return rows[0]


def _user_dict(row) -> dict:
    return {"id": row["id"], "email": row["email"], "name": row["name"]}


@router.post("/auth/register")
def register(body: Credentials):
    email = body.email.strip().lower()
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="Correo electrónico no válido")
    if len(body.password) < 6:
        raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 6 caracteres")
    if query("SELECT id FROM users WHERE email = ?", (email,)):
        raise HTTPException(status_code=409, detail="Ese correo ya está registrado")

    cur = execute(
        "INSERT INTO users(email, password_hash, name, created_at) VALUES(?,?,?,?)",
        (email, hash_password(body.password), body.name.strip()[:80], now()),
    )
    uid = cur.lastrowid
    save_prefs(uid, {})
    token = create_token(uid, email)
    return {"token": token, "user": {"id": uid, "email": email, "name": body.name.strip()[:80]}}


@router.post("/auth/login")
def login(body: Credentials):
    email = body.email.strip().lower()
    rows = query("SELECT * FROM users WHERE email = ?", (email,))
    if not rows or not verify_password(body.password, rows[0]["password_hash"]):
        raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")
    user = rows[0]
    token = create_token(user["id"], user["email"])
    return {"token": token, "user": _user_dict(user)}


@router.get("/me")
def me(user=Depends(current_user)):
    return {"user": _user_dict(user), "preferences": get_prefs(user["id"]),
            "omniroute": {"base_url": config.OMNIROUTE_BASE_URL,
                          "model": config.OMNIROUTE_MODEL}}


@router.put("/me/preferences")
def update_prefs(body: PrefsBody, user=Depends(current_user)):
    current = get_prefs(user["id"])
    incoming = {k: v for k, v in body.preferences.items() if len(json.dumps(v)) < 20000}
    current.update(incoming)
    save_prefs(user["id"], current)
    return {"preferences": current}
