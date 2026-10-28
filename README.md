# ApplyToAnything 🧡📱

**Busca empleo haciendo swipe (estilo Tinder), habla con una IA asesora gratuita y postula
con carta de presentación generada automáticamente.** Clon libre de herramientas tipo
aiAutoApply, hecho en **Flutter (Android)** + **backend FastAPI** + **OmniRoute** como
gateway de IA **100% gratuito**.

```
 ┌─────────────────────────┐        ┌──────────────────────────┐        ┌─────────────────────┐
 │  App Flutter (Android)  │  HTTP  │   Backend FastAPI local  │        │ OmniRoute (gratis)  │
 │  · Chat con Ana (IA)    │ ─────► │  · Auth JWT + SQLite     │ ─────► │ /v1/chat/completions│
 │  · Mazo estilo Tinder   │        │  · Búsqueda determinista │        │ (gateway local de   │
 │  · Postulaciones        │        │    en bolsas públicas    │        │  modelos LLM)       │
 │  · Perfil y ajustes     │        │  · Proxy IA + cartas     │        └─────────────────────┘
 └─────────────────────────┘        └────────────┬─────────────┘
                                                 │  consultas en paralelo
                          ┌──────────┬────────────┼─────────────┬──────────┐
                          ▼          ▼            ▼             ▼          ▼
                      Remotive   Arbeitnow    RemoteOK      Adzuna*    Jooble*
                                                            (*con clave gratis opcional)
```

## ✨ Funciones

- **Cuentas**: registro e inicio de sesión (correo + contraseña, JWT, SQLite en tu propio backend).
- **Chat con Ana, la asesora IA**: te entrevista paso a paso (rol, seniority, países, modalidad,
  salario, skills, idiomas) y con tu respuesta construye un `PROFILE_JSON` que la app convierte
  automáticamente en filtros de búsqueda. El prompt completo vive en [`system.md`](system.md).
- **IA gratis vía OmniRoute**: la app habla con Ana a través de OmniRoute
  (`http://localhost:20128/v1`, OpenAI-compatible). Tú eliges el proveedor/modelo gratuito en el
  panel de OmniRoute; la app nunca necesita claves de pago.
- **Búsqueda determinista multi-país**: el backend agrega ofertas de Remotive, Arbeitnow y
  RemoteOK (sin claves, funcionan al instante) + Adzuna y Jooble por país (claves gratuitas
  opcionales). Deduplicación, orden por fecha y filtrado remoto/por país.
- **Interfaz tipo Tinder**: mazo de tarjetas con drag, rotación y sellos animados.
  - Desliza a la **derecha** → Ana genera una **carta de presentación** editable, se abre la
    oferta en el navegador y se registra como *Aplicada*.
  - Desliza **arriba** → guardas la oferta (*Guardadas*).
  - Desliza a la **izquierda** → la descarta (no vuelve a aparecer).
- **Postulaciones**: pestañas Aplicadas/Guardadas, abrir oferta, actualizar estado, eliminar.
- **Perfil editable** manualmente (por si prefieres no usar el chat) y **Ajustes** con prueba de
  conexión y visor del `system.md`.

## 🚀 Puesta en marcha (5 minutos)

### 1. Arranca OmniRoute (IA gratuita)

```bash
npm install -g omniroute
omniroute            # gateway en http://localhost:20128
```

Abre `http://localhost:20128`, crea una cuenta local y **activa uno o varios proveedores
gratuitos** (GLM, DeepSeek, Gemini, etc.). Por defecto no requiere API key
(`REQUIRE_API_KEY=false`). Modelo usado por defecto por el backend: `glm/glm-4.7`
(cámbialo con `OMNIROUTE_MODEL` o desde Ajustes en la app).

### 2. Arranca el backend

Windows:
```bat
backend\run.bat
```
Linux/macOS/Git Bash:
```bash
cd backend && chmod +x run.sh && ./run.sh
```
Esto crea un venv, instala FastAPI/uvicorn/httpx/PyJWT y levanta la API en
`http://localhost:8000` (docs interactivas en `/docs`). La base SQLite se crea sola.

Opcional (más resultados por país): crea `backend/.env` con claves gratuitas:
```
ADZUNA_APP_ID=xxx
ADZUNA_APP_KEY=xxx     # https://developer.adzuna.com (free tier)
JOOBLE_API_KEY=xxx     # https://jooble.org/api/about (free)
```

### 3. Compila la app Flutter

```bash
cd app
flutter create . --org com.applytoanything --project-name apply_to_anything
flutter pub get
flutter run          # o: flutter build apk --release
```

> `flutter create .` genera las carpetas de plataforma (android/, ios/, …). No toca `lib/`.
> El CI de GitHub hace exactamente esto y compila el APK en cada push.

**Permisos Android**: en `android/app/src/main/AndroidManifest.xml` añade dentro de `<manifest>`
(la app habla con tu backend por HTTP local):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application android:usesCleartextTraffic="true" ...>
```

### 4. Conecta la app al backend

- **Emulador Android**: la URL por defecto ya es `http://10.0.2.2:8000` (= localhost de tu PC).
- **Dispositivo físico**: abre *Perfil → Ajustes* y pon `http://IP-DE-TU-PC:8000`
  (misma red WiFi; el `run.bat` ya escucha en 0.0.0.0). Pulsa **Probar conexión**.

### 5. Úsalo

1. **Crear cuenta** (se guarda en tu backend local).
2. Pestaña **Ana IA**: responde sus preguntas; al final guardará tu perfil (`PROFILE_JSON`).
3. Pestaña **Empleos**: desliza ofertas. A la derecha = postular con carta IA + abrir la oferta.
4. Pestaña **Postulaciones**: revisa a qué aplicaste y qué guardaste.

## 🔌 API del backend

| Método | Ruta                    | Descripción                                          |
|--------|-------------------------|------------------------------------------------------|
| POST   | `/auth/register`        | Crea cuenta → `{token, user}`                        |
| POST   | `/auth/login`           | Login → `{token, user}`                              |
| GET    | `/me`                   | Usuario + preferencias                               |
| PUT    | `/me/preferences`       | Guarda perfil de búsqueda                            |
| GET    | `/jobs/search`          | Agrega ofertas (`q`, `countries=xx,es`, `remote=only`, `page`) |
| POST   | `/ai/chat`              | Chat con Ana (system.md + perfil → OmniRoute)        |
| POST   | `/ai/cover-letter`      | Carta de presentación para una oferta                |
| GET    | `/applications`         | Lista postulaciones (`?status=applied`)              |
| POST   | `/applications`         | Registra/actualiza (liked / applied / skipped)       |
| PATCH  | `/applications/{id}`    | Cambia estado                                        |
| DELETE | `/applications/{id}`    | Elimina                                              |
| GET    | `/system-prompt`        | Devuelve el system.md actual                         |
| GET    | `/health`               | Estado + config OmniRoute                            |

Variables de entorno del backend (o `backend/.env`): `OMNIROUTE_BASE_URL`,
`OMNIROUTE_MODEL`, `OMNIROUTE_API_KEY`, `ADZUNA_APP_ID/KEY`, `JOOBLE_API_KEY`,
`ATA_DB_PATH`, `ATA_JWT_EXPIRE_DAYS`, `ATA_SYSTEM_MD_PATH`.

## 🧠 Cómo funciona el «cerebro»

1. `system.md` define a **Ana**: tono, flujo de entrevista (máx. 8 preguntas, una por mensaje)
   y el contrato de salida `PROFILE_JSON` con países en ISO-2 y keywords de búsqueda.
2. La app detecta ese bloque en el chat, lo parsea y lo envía a `PUT /me/preferences`.
3. La pestaña Empleos consulta `/jobs/search` con esos filtros; el backend lanza todas las
   consultas **en paralelo** (`asyncio.gather`), limpia HTML, deduplica y pagina.
4. Al postular, `/ai/cover-letter` pide a Ana una carta en el idioma de la oferta usando tu
   perfil; tú la editas, se registra la postulación y se abre la oferta real.

## ⚖️ Notas

- La búsqueda usa **APIs públicas y documentadas** de cada bolsa de empleo. Respeta sus
  términos y límites de uso.
- «Aplicar» abre la oferta original en tu navegador (postulación externa) y registra el
  seguimiento; las bolsas no permiten envío automático de formularios vía API.
- Proyecto educativo bajo licencia MIT. No está afiliado a aiAutoApply ni a las bolsas citadas.

## 🛠️ Estructura

```
ApplyToAnything/
├── system.md                  # Prompt canónico de la IA (Ana)
├── backend/
│   ├── app/
│   │   ├── main.py            # FastAPI + rutas + CORS
│   │   ├── config.py          # .env, OmniRoute, claves
│   │   ├── db.py              # SQLite (usuarios, prefs, postulaciones)
│   │   ├── security.py        # PBKDF2 + JWT
│   │   ├── providers.py       # Remotive/Arbeitnow/RemoteOK/Adzuna/Jooble
│   │   ├── omniroute.py       # Cliente /v1/chat/completions
│   │   └── routers/           # auth · jobs · ai · applications
│   ├── run.bat / run.sh
│   └── requirements.txt
├── app/                       # Flutter
│   ├── assets/system.md       # Copia del prompt (fallback offline)
│   └── lib/
│       ├── core/              # api client · tema · constantes (países…)
│       ├── models/            # Job · User · Application
│       ├── state/app_state.dart
│       ├── widgets/           # SwipeDeck (Tinder) · JobCard · sheets
│       └── screens/           # auth · home · swipe · chat · aplicaciones · perfil · ajustes
└── .github/workflows/ci.yml   # CI: backend import + flutter analyze + APK debug
```

---

Hecho con 💜 — MIT License.
