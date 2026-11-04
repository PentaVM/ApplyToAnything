"""ApplyToAnything API — punto de entrada FastAPI."""
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from . import config
from .db import query
from .routers import ai, applications, auth, connectors, jobs

app = FastAPI(
    title="ApplyToAnything API",
    version="1.2.0",
    description="Backend compartido de búsqueda de empleo y conectores de IA.",
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
app.include_router(connectors.router)
app.include_router(applications.router)

web = Path(__file__).with_name("web")
app.mount("/assets", StaticFiles(directory=web), name="assets")


@app.get("/", include_in_schema=False)
def dashboard():
    return FileResponse(web / "index.html", headers={
        "Content-Security-Policy": "default-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'none'",
        "X-Content-Type-Options": "nosniff",
    })


@app.get("/health")
def health():
    if config.ON_VERCEL or config.DATABASE_URL:
        try:
            query("SELECT 1")
        except Exception:
            return JSONResponse({"status": "database_unavailable", "app": "ApplyToAnything"}, status_code=503)
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
