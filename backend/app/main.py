"""ApplyToAnything API — punto de entrada FastAPI."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import config
from .routers import ai, applications, auth, jobs

app = FastAPI(
    title="ApplyToAnything API",
    version="1.0.0",
    description="Backend de búsqueda y postulación de empleo con IA (OmniRoute).",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(jobs.router)
app.include_router(ai.router)
app.include_router(applications.router)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "app": "ApplyToAnything",
        "omniroute_base": config.OMNIROUTE_BASE_URL,
        "omniroute_model": config.OMNIROUTE_MODEL,
        "adzuna": bool(config.ADZUNA_APP_ID and config.ADZUNA_APP_KEY),
        "jooble": bool(config.JOOBLE_API_KEY),
    }


@app.get("/system-prompt")
def system_prompt_route():
    sp = config.system_prompt()
    return {"system_prompt": sp, "chars": len(sp)}
