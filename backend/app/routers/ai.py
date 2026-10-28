"""Proxy de IA: chat (onboarding) y cartas de presentación, vía OmniRoute."""
import json

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from .. import config
from ..db import get_prefs, log_chat
from ..omniroute import chat as omni_chat
from .auth import current_user

router = APIRouter()


class ChatBody(BaseModel):
    messages: list
    model: str | None = None
    api_key: str | None = None
    temperature: float | None = None


class CoverBody(BaseModel):
    job: dict
    model: str | None = None
    api_key: str | None = None


def _profile_context(user_row) -> str:
    prefs = get_prefs(user_row["id"])
    return (
        f"\n\n--- CONTEXTO DEL USUARIO ---\n"
        f"NOMBRE: {user_row['name'] or 'sin nombre'}\n"
        f"PERFIL ACTUAL (JSON, puede estar incompleto o vacío): "
        f"{json.dumps(prefs, ensure_ascii=False)}"
    )


@router.post("/ai/chat")
async def ai_chat(body: ChatBody, user=Depends(current_user)):
    system = config.system_prompt() + _profile_context(user)
    history = [
        {"role": m["role"], "content": str(m["content"])[:4000]}
        for m in body.messages
        if isinstance(m, dict)
        and m.get("role") in ("user", "assistant")
        and isinstance(m.get("content"), str)
        and m.get("content").strip()
    ][-20:]

    out = await omni_chat(
        [{"role": "system", "content": system}] + history,
        model=body.model or None,
        api_key=body.api_key or None,
        temperature=body.temperature if body.temperature is not None else 0.6,
    )

    if history:
        log_chat(user["id"], "user", history[-1]["content"])
        log_chat(user["id"], "assistant", out["reply"])
    return out


@router.post("/ai/cover-letter")
async def ai_cover_letter(body: CoverBody, user=Depends(current_user)):
    job = body.job
    prefs = get_prefs(user["id"])
    prompt = (
        "Redacta una carta de presentación breve (250-350 palabras) para esta oferta.\n\n"
        f"CANDIDATO/A: {user_row_name(user)}\n"
        f"PERFIL: {json.dumps(prefs, ensure_ascii=False)}\n\n"
        f"OFERTA:\n"
        f"- Puesto: {job.get('title', '')}\n"
        f"- Empresa: {job.get('company', '')}\n"
        f"- Ubicación: {job.get('location', '')} ({job.get('country', '')})\n"
        f"- Remota: {'sí' if job.get('remote') else 'no'}\n"
        f"- Descripción (recortada): {str(job.get('description', ''))[:1500]}\n\n"
        "Devuelve SOLO el texto de la carta, en el idioma de la oferta."
    )
    system = config.system_prompt() + _profile_context(user)
    return await omni_chat(
        [{"role": "system", "content": system}, {"role": "user", "content": prompt}],
        model=body.model or None,
        api_key=body.api_key or None,
        temperature=0.7,
        max_tokens=800,
    )


def user_row_name(user) -> str:
    return user["name"] or "candidato/a"
