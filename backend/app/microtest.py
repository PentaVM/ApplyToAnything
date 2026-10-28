"""Micro-test de la lógica propia (agregador + SQL). Uso: python -m app.microtest"""
import asyncio
import os

os.environ.setdefault("ATA_DB_PATH", ":memory:")

import app.providers as prov  # noqa: E402
from app import db  # noqa: E402

# --- 1) Agregador con datos simulados ---------------------------------------
fake = {"data": [
    {"slug": "s1", "company_name": "ACME", "title": "Python Dev", "url": "https://a.b/1",
     "remote": True, "tags": ["python"], "location": "Madrid", "created_at": 1730000000},
    {"slug": "s2", "company_name": "Globex", "title": "<b>Backend</b> Engineer", "url": "https://a.b/2",
     "remote": False, "tags": [], "location": "Berlín", "created_at": 1730000100},
    {"slug": "s1", "company_name": "ACME", "title": "Python Dev", "url": "https://a.b/1",
     "remote": True, "tags": ["python"], "location": "Madrid", "created_at": 1730000000},
]}

async def fake_get(client, url, **kw):
    return fake

prov._get_json = fake_get
jobs, errors = asyncio.run(prov.search_all(q="python", countries=["xx"]))
assert not errors, f"errores inesperados: {errors}"
assert len(jobs) == 2, f"dedupe fallo: {len(jobs)}"
assert jobs[0]["company"] == "Globex", "orden por fecha fallo"
assert "<b>" not in jobs[1]["title"], "limpieza de HTML fallo"
ro, _ = asyncio.run(prov.search_all(q="", countries=["xx"], remote_only=True))
assert len(ro) == 1 and ro[0]["remote"], "filtro remote_only fallo"
print("1) agregador OK (dedupe, orden, html, remote_only)")

# --- 2) SQL de postulaciones (upsert/patch/delete) sobre la BD ---------------
db.execute("INSERT INTO users(email, password_hash, name, created_at) VALUES(?,?,?,?)",
           ("t@t.com", "x", "T", db.now()))
db.execute(
    """INSERT INTO applications
         (user_id, job_id, title, company, url, source, country, status, method, cover_letter, created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?)
       ON CONFLICT(user_id, job_id) DO UPDATE SET status = excluded.status""",
    (1, "remotive:1", "Dev", "ACME", "https://x.y/j", "remotive", "xx", "applied", "external_url", "Hola", db.now()))
db.execute(
    """INSERT INTO applications
         (user_id, job_id, title, company, url, source, country, status, method, cover_letter, created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?)
       ON CONFLICT(user_id, job_id) DO UPDATE SET status = excluded.status""",
    (1, "remotive:1", "Dev", "ACME", "https://x.y/j", "remotive", "xx", "liked", "external_url", "Hola", db.now()))
rows = db.query("SELECT * FROM applications WHERE user_id=1")
assert len(rows) == 1, "upsert no deduplicó"
assert rows[0]["status"] == "liked", "upsert no actualizó el estado"
cur = db.execute("UPDATE applications SET status='applied' WHERE id=1 AND user_id=1")
assert cur.rowcount == 1, "patch fallo"
cur = db.execute("DELETE FROM applications WHERE id=1 AND user_id=1")
assert cur.rowcount == 1, "delete fallo"
print("2) SQL de postulaciones OK (upsert, patch, delete)")

# --- 3) Password + JWT -------------------------------------------------------
from app.security import create_token, decode_token, hash_password, verify_password  # noqa: E402
h = hash_password("secreto")
assert verify_password("secreto", h) and not verify_password("malo", h)
uid = decode_token(create_token(7, "a@b.c"))
assert uid == 7
print("3) password + JWT OK")

print("MICROTEST COMPLETO: TODO OK")
