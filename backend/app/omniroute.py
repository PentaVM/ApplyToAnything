"""Cliente hacia OmniRoute: gateway de IA gratuito y OpenAI-compatible.

OmniRoute corre en la máquina del usuario:  npm install -g omniroute && omniroute
Endpoint: POST {OMNIROUTE_BASE_URL}/chat/completions  (por defecto http://localhost:20128/v1)
"""
import httpx
from fastapi import HTTPException

from . import config


async def chat(messages, model=None, api_key=None, temperature=0.6, max_tokens=900):
    base = config.OMNIROUTE_BASE_URL.rstrip("/")
    url = f"{base}/chat/completions"
    headers = {"Content-Type": "application/json"}
    key = api_key or config.OMNIROUTE_API_KEY
    if key:
        headers["Authorization"] = f"Bearer {key}"

    payload = {
        "model": model or config.OMNIROUTE_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }

    try:
        async with httpx.AsyncClient(timeout=120) as client:
            r = await client.post(url, json=payload, headers=headers)
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=502,
            detail=(
                f"No se pudo conectar a OmniRoute ({url}): {type(e).__name__}. "
                "¿Está corriendo el gateway? Instálalo y arráncalo gratis con: "
                "`npm install -g omniroute && omniroute`."
            ),
        )

    if r.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"OmniRoute respondió {r.status_code}: {r.text[:300]}",
        )

    try:
        data = r.json()
        reply = data["choices"][0]["message"]["content"] or ""
        return {"reply": reply, "model": data.get("model", payload["model"])}
    except Exception:
        raise HTTPException(status_code=502, detail="Respuesta inesperada de OmniRoute")
