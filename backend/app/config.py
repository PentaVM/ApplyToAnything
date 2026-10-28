"""Configuración central de ApplyToAnything.

Todo se puede sobreescribir con variables de entorno o un archivo .env junto a backend/.
"""
import os
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
REPO_DIR = BACKEND_DIR.parent

# Cargar .env opcional (sin dependencias)
_env_file = BACKEND_DIR / ".env"
if _env_file.is_file():
    for line in _env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip())

DB_PATH = os.environ.get("ATA_DB_PATH", str(BACKEND_DIR / "ata.db"))
JWT_EXPIRE_DAYS = int(os.environ.get("ATA_JWT_EXPIRE_DAYS", "30"))

# --- OmniRoute (gateway de IA gratuito, OpenAI-compatible) -------------------
# Instalación:  npm install -g omniroute  &&  omniroute
OMNIROUTE_BASE_URL = os.environ.get("OMNIROUTE_BASE_URL", "http://localhost:20128/v1")
OMNIROUTE_API_KEY = os.environ.get("OMNIROUTE_API_KEY", "")
OMNIROUTE_MODEL = os.environ.get("OMNIROUTE_MODEL", "glm/glm-4.7")

# --- Bolsas de trabajo opcionales (requieren clave gratuita) -----------------
ADZUNA_APP_ID = os.environ.get("ADZUNA_APP_ID", "")
ADZUNA_APP_KEY = os.environ.get("ADZUNA_APP_KEY", "")
JOOBLE_API_KEY = os.environ.get("JOOBLE_API_KEY", "")

_FALLBACK_PROMPT = """Eres Ana, la asesora de carrera de IA de ApplyToAnything.
Entrevistas a la persona para conocer su perfil (rol, seniority, países o remoto, modalidad,
salario, skills, idiomas) de forma breve y conversacional, una pregunta por mensaje.
Cuando tengas rol + países/remoto + seniority o skills, da un resumen y emite al final un bloque:

PROFILE_JSON
{"role":"...","seniority":"...","countries":["xx"],"modality":"remoto","remote_only":true,"salary_min":0,"currency":"USD","skills":["..."],"languages":["es"],"keywords":["..."]}

Nunca inventas ofertas de trabajo; la búsqueda la hace el backend contra bolsas públicas.
(Copia el archivo system.md del repositorio para el prompt completo)."""


def system_prompt() -> str:
    """Lee el archivo system.md canónico (raíz del repo) con fallback embebido."""
    env_path = os.environ.get("ATA_SYSTEM_MD_PATH", "")
    candidates = []
    if env_path:
        candidates.append(Path(env_path))
    candidates.append(REPO_DIR / "system.md")
    candidates.append(BACKEND_DIR / "system.md")
    for c in candidates:
        try:
            if c.is_file():
                return c.read_text(encoding="utf-8")
        except OSError:
            continue
    return _FALLBACK_PROMPT
