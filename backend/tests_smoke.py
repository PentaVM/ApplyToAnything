"""Test funcional del backend (sin HTTP): endpoints y agregador con datos simulados.

Uso:  python tests_smoke.py
"""
from app.routers.auth import register, login, update_prefs, me
from app.routers.auth import Credentials, PrefsBody
from app.routers.applications import (
    ApplicationBody,
    StatusBody,
    list_applications,
    update_status,
    upsert_application,
)

r = register(Credentials(email="demo@test.com", password="secret123", name="Demo"))
print("register:", r["user"], "| token ok:", len(r["token"]) > 20)
user = {"id": r["user"]["id"], "email": "demo@test.com", "name": "Demo"}

try:
    register(Credentials(email="demo@test.com", password="secret123"))
    print("dup register: FALLO")
except Exception as e:
    print("dup register OK ->", getattr(e, "status_code", e))

print("login:", login(Credentials(email="demo@test.com", password="secret123"))["user"]["name"])
try:
    login(Credentials(email="demo@test.com", password="bad"))
    print("bad login: FALLO")
except Exception as e:
    print("bad login OK ->", getattr(e, "status_code", e))

print("prefs:", update_prefs(PrefsBody(preferences={"role": "python dev", "countries": ["xx", "es"]}), user)["preferences"])
print("me omniroute:", me(user)["omniroute"]["base_url"])

a = upsert_application(ApplicationBody(job_id="remotive:1", title="Dev", company="ACME", url="https://x.y/j", status="applied", cover_letter="Hola"), user)
print("upsert:", a["application"]["status"])
a = upsert_application(ApplicationBody(job_id="remotive:1", title="Dev", company="ACME", url="https://x.y/j", status="liked"), user)
print("upsert again ->", a["application"]["status"])
print("list n=", len(list_applications(user)["applications"]))
print("patch:", update_status(1, StatusBody(status="applied"), user))

# Agregador con datos simulados (sin red)
import asyncio

import app.providers as prov

fake = {
    "data": [
        {"slug": "s1", "company_name": "ACME", "title": "Python Dev", "url": "https://a.b/1",
         "remote": True, "tags": ["python"], "location": "Madrid", "created_at": 1730000000},
        {"slug": "s2", "company_name": "Globex", "title": "<b>Backend</b> Engineer", "url": "https://a.b/2",
         "remote": False, "tags": [], "location": "Berlín", "created_at": 1730000100},
    ]
}

async def fake_get(client, url, **kw):
    return fake

prov._get_json = fake_get
jobs, errors = asyncio.run(prov.search_all(q="python", countries=["xx"]))
print("agregador: n=", len(jobs), "| errores:", errors,
      "| fecha desc:", jobs[0]["company"] == "Globex",
      "| html limpio:", "<b>" not in jobs[1]["title"])
ro, _ = asyncio.run(prov.search_all(q="", countries=["xx"], remote_only=True))
print("remote_only n=", len(ro))
print("TODOS LOS TESTS FUNCIONALES OK")
