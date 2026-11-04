"""Cliente hacia OmniRoute: gateway de IA gratuito y OpenAI-compatible.

OmniRoute corre en la máquina del usuario:  npm install -g omniroute && omniroute
Endpoint: POST {OMNIROUTE_BASE_URL}/chat/completions  (por defecto http://localhost:20128/v1)
"""
import httpx
from fastapi import HTTPException

from . import config


async def chat(messages, model=None, api_key=None, temperature=0.6, max_tokens=900,
               direct=False):
    base = (config.API_BASE_URL if direct else config.OMNIROUTE_BASE_URL).rstrip("/")
    url = f"{base}/chat/completions"
    headers = {"Content-Type": "application/json"}
    key = api_key if direct else api_key or config.OMNIROUTE_API_KEY
    if key:
        headers["Authorization"] = f"Bearer {key}"

    payload = {
        "model": model or (config.API_MODEL if direct else config.OMNIROUTE_MODEL),
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }

    try:
        async with httpx.AsyncClient(timeout=45) as client:
            r = await client.post(url, json=payload, headers=headers)
    except httpx.HTTPError:
        raise HTTPException(
            status_code=502,
            detail="No se pudo conectar al proveedor de IA",
        )

    if r.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail=f"El proveedor de IA respondió con estado {r.status_code}",
        )

    try:
        data = r.json()
        reply = data["choices"][0]["message"]["content"]
        if not isinstance(reply, str) or not reply.strip():
            raise ValueError("Respuesta vacía")
        return {"reply": reply[:12000], "model": data.get("model", payload["model"])}
    except Exception:
        raise HTTPException(status_code=502, detail="Respuesta inesperada del proveedor de IA")
