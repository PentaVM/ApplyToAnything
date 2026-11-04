# ApplyToAnything

Busca vacantes y prepara postulaciones desde Android o desde el navegador con la misma cuenta. La web y el APK consumen la API de FastAPI en backend/. Cada cuenta tiene su propio perfil, seguimiento y selección de IA.

## Iniciar

En Windows ejecuta backend\run.bat. En macOS o Linux ejecuta bash backend/run.sh. Abre http://localhost:8000 para usar la web. Desde Android, configura el mismo servidor. El emulador usa http://10.0.2.2:8000. Un APK para producción puede incluir la URL HTTPS con ATA_BACKEND_URL.

La IA prepara respuestas y cartas. La persona completa la postulación en la página del empleador y confirma el envío en Seguimiento.

## Proveedores de IA

Abre Conexiones en Android o Proveedores de IA en la web. Selecciona el proveedor, guarda la selección y, si usa un equipo externo, genera un código. Desde backend/ en ese equipo ejecuta, por ejemplo:

    python connector.py codex --server https://TU-PROYECTO.vercel.app

El conector pide el código sin mostrarlo. Para servicios sin terminal, usa ATA_CONNECTOR_TOKEN como secreto del proceso y ATA_SERVER_URL como URL. La conexión sale del equipo hacia el backend. Cada código pertenece a una cuenta y a un proveedor. Puedes revocarlo desde la app. Las credenciales del proveedor se configuran en el equipo que lo ejecuta.

| Modo | Configuración en el equipo |
| --- | --- |
| Codex | Inicia sesión con ChatGPT en el CLI oficial. Comprueba con python connector.py codex --probe. |
| Claude Code | Inicia sesión en el CLI oficial en el equipo de la cuenta y usa el adaptador allí. Comprueba con python connector.py claude --probe. Las integraciones que ofrecen autenticación de terceros en nombre de otros usuarios deben usar las vías autorizadas de Anthropic. |
| Antigravity | Inicia sesión con el CLI agy. Configura permissions.deny en ~/.gemini/antigravity-cli/settings.json con command(*), read_file(*), write_file(*), read_url(*), execute_url(*) y mcp(*). Comprueba con python connector.py antigravity --probe. |
| OmniRoute en tu equipo | Configura OmniRoute y elige un modelo gratuito. Define ATA_PROVIDER_MODEL. ATA_PROVIDER_URL usa http://127.0.0.1:20128/v1 por defecto. Si el gateway permite acceso sin clave, omite ATA_PROVIDER_API_KEY. |
| API en tu equipo | Define ATA_PROVIDER_URL, ATA_PROVIDER_MODEL y ATA_PROVIDER_API_KEY para un endpoint compatible con Chat Completions. La clave queda en ese equipo. |
| Clave API directa | El backend usa ATA_API_BASE_URL y el modelo por defecto ATA_API_MODEL si está configurado. Introduce tu clave y modelo en la web o en Ajustes de Android. El valor de la clave dura la sesión de la interfaz. |
| OmniRoute del servidor | Configura OMNIROUTE_BASE_URL y OMNIROUTE_MODEL. OMNIROUTE_API_KEY es opcional según el gateway. En producción usa un gateway administrado y accesible al servidor, o elige el conector de tu equipo. |
| Personalizado | Define ATA_PROVIDER_COMMAND como un arreglo JSON con el ejecutable y argumentos de confianza. Recibe el contexto por stdin y devuelve texto por stdout. |

El modo sin clave de OmniRoute depende de un modelo gratuito disponible y de la configuración del gateway. Usa el gateway sin clave dentro de una red privada.

El mismo conector puede ejecutarse en una VM o en un contenedor. Desde backend/:

    docker build -f Dockerfile.connector -t ata-connector .
    docker run --rm --env-file /ruta/privada/conector.env ata-connector omniroute

Para usar una CLI dentro de un contenedor, instálala y autentícala con el flujo oficial en ese entorno. La imagen base del conector incluye el cliente HTTP.

## Vercel

Importa PentaVM/ApplyToAnything y elige backend como Root Directory. El proyecto detecta FastAPI en app/main.py. Configura ATA_DATABASE_URL con una conexión de PostgreSQL, o usa POSTGRES_URL proporcionada por una integración de Vercel. En Vercel la aplicación requiere PostgreSQL. En desarrollo local conserva compatibilidad con SQLite.

Después del despliegue, verifica GET /health y crea la cuenta en la web o en Android. Usa la misma URL y el mismo correo en ambos. Para compilar Android con esa URL, define la variable ATA_BACKEND_URL del repositorio para CI o usa:

    flutter build apk --release --dart-define=ATA_BACKEND_URL=https://TU-PROYECTO.vercel.app

Si vienes de un backend SQLite local, sus cuentas y datos siguen en ese archivo. La base de Vercel arranca independiente.

## Verificación

Ejecuta python tests_smoke.py y python tests_connectors.py desde backend/. CI ejecuta el flujo de conectores con SQLite y PostgreSQL, además de analizar y compilar Flutter.
