"""Integration coverage for account isolation, job provenance, and the AI bridge."""

import os
import uuid
from unittest.mock import patch

from fastapi.testclient import TestClient

os.environ.setdefault("ATA_DB_PATH", ":memory:")

from app.main import app
from app.routers.jobs import remember_jobs


def main():
    client = TestClient(app)

    def signup(name):
        response = client.post("/auth/register", json={
            "email": f"{uuid.uuid4().hex}@example.com", "password": "test-only-password", "name": name,
        })
        assert response.status_code == 200, response.text
        data = response.json()
        return data["user"]["id"], bearer(data["token"])

    def pair(owner, provider):
        response = client.post("/ai/connectors", headers=owner, json={"provider": provider})
        assert response.status_code == 200, response.text
        assert response.headers["cache-control"] == "no-store"
        return bearer(response.json()["token"])

    def claim(worker, provider):
        return client.post("/ai/worker/claim", headers=worker, params={"provider": provider})

    def bearer(token):
        return {"Authorization": "Bearer " + token}

    def cover(owner):
        return client.post("/ai/cover-letter", headers=owner, json={
            "job": {"id": "demo:1", "description": "Texto falsificado en el cliente"},
        })

    assert client.get("/").status_code == 200
    assert client.get("/assets/dashboard.js").status_code == 200
    user_id, owner = signup("Candidata A")
    _, other = signup("Candidato B")
    remember_jobs(user_id, [{"id": "demo:1", "title": "Soporte", "company": "Demo",
                             "description": "Descripción oficial de la vacante"}])
    client.put("/me/preferences", headers=owner, json={
        "preferences": {"skills": ["Linux"], "passport": "No enviar este dato"},
    }).raise_for_status()
    assert client.put("/ai/provider", headers=owner, json={"provider": "codex"}).status_code == 204
    assert cover(other).status_code == 422
    assert cover(owner).status_code == 503

    worker = pair(owner, "codex")
    foreign = pair(other, "codex")
    assert claim(worker, "claude").status_code == 403
    assert claim(worker, "codex").json() == {"task": None}
    assert client.get("/me", headers=worker).status_code == 401
    request = cover(owner)
    assert request.status_code == 202, request.text
    assert cover(owner).status_code == 503
    task_id = request.json()["task_id"]
    assert client.get(f"/ai/tasks/{task_id}", headers=other).status_code == 404
    assert claim(foreign, "codex").json() == {"task": None}
    task = claim(worker, "codex").json()["task"]
    assert task["id"] == task_id
    content = str(task["messages"])
    assert "Descripción oficial de la vacante" in content and "Linux" in content
    assert "Texto falsificado" not in content and "No enviar este dato" not in content
    assert claim(worker, "codex").json() == {"task": None}
    completion = {"lease": task["lease"], "reply": "Carta de prueba"}
    assert client.put(f"/ai/worker/tasks/{task_id}", headers=foreign, json=completion).status_code == 409
    assert client.put(f"/ai/worker/tasks/{task_id}", headers=worker, json=completion).status_code == 204
    assert client.get(f"/ai/tasks/{task_id}", headers=owner).json()["reply"] == "Carta de prueba"
    stale = cover(owner).json()["task_id"]
    replacement = pair(owner, "codex")
    assert claim(worker, "codex").status_code == 401
    assert claim(replacement, "codex").json() == {"task": None}
    assert client.get(f"/ai/tasks/{stale}", headers=owner).json()["state"] == "failed"
    assert client.delete("/ai/connectors/codex", headers=owner).status_code == 204
    assert claim(replacement, "codex").status_code == 401

    original = {"job_id": "demo:1", "title": "Soporte", "status": "liked", "cover_letter": "Borrador"}
    application = client.post("/applications", headers=owner, json=original).json()["application"]
    client.patch(f"/applications/{application['id']}", headers=owner, json={
        "status": "applied", "confirmed_submission": True,
    }).raise_for_status()
    saved = client.post("/applications", headers=owner, json={**original, "cover_letter": ""}).json()["application"]
    assert saved["status"] == "applied" and saved["cover_letter"] == "Borrador"

    with patch("app.routers.ai.gateway_chat", return_value={"reply": "Prueba", "model": "demo"}) as gateway:
        message = {"messages": [{"role": "user", "content": "¿Qué cargos busco?"}]}
        response = client.post("/ai/chat", headers=owner, json={
            **message, "provider": "auto", "api_key": "direct-only", "model": "direct-model",
        })
        assert response.status_code == 200, response.text
        assert gateway.call_args.kwargs["api_key"] is None
        assert gateway.call_args.kwargs["model"] is None
        response = client.post("/ai/chat", headers=owner, json={
            **message, "provider": "api_key", "api_key": "test-key", "model": "demo",
        })
        assert response.status_code == 200, response.text
        assert gateway.call_args.kwargs["direct"] is True

    print("Connectors OK: owner isolation, revocation, verified offers, personal context, API and no-key routing")


if __name__ == "__main__":
    main()
