"""Run an outbound ApplyToAnything connector on a trusted host."""

import argparse
import getpass
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.parse import urlsplit

import httpx

PROVIDERS = ("codex", "claude", "antigravity", "omniroute", "api", "custom")
AGY_DENY = {"command(*)", "read_file(*)", "write_file(*)", "read_url(*)",
            "execute_url(*)", "mcp(*)"}


def validate_server(url):
    parsed = urlsplit(url)
    loopback = parsed.hostname in ("localhost", "127.0.0.1", "::1")
    if not parsed.hostname or parsed.username or parsed.query or parsed.fragment or (
        parsed.scheme != "https" and not (parsed.scheme == "http" and loopback)
    ):
        raise ValueError("Usa la URL HTTPS del backend o una URL HTTP local")
    return url.rstrip("/")


def run_provider(provider, messages):
    prompt = (
        "Responde como un asistente de búsqueda laboral. Usa solo los mensajes JSON adjuntos. "
        "No uses herramientas, archivos, navegación ni memorias externas. Devuelve solo la respuesta.\n"
        + json.dumps(messages, ensure_ascii=False)
    )
    if provider in ("omniroute", "api"):
        base = os.environ.get("ATA_PROVIDER_URL", "http://127.0.0.1:20128/v1" if provider == "omniroute" else "")
        key = os.environ.get("ATA_PROVIDER_API_KEY", "")
        model = os.environ.get("ATA_PROVIDER_MODEL", "")
        if not base or not model or (provider == "api" and not key):
            raise ValueError("Configura la URL, el modelo y, para API, la clave del proveedor")
        response = httpx.post(
            base.rstrip("/") + "/chat/completions",
            headers={"Authorization": f"Bearer {key}"} if key else {},
            json={"model": model, "messages": messages, "max_tokens": 900},
            timeout=90,
        )
        response.raise_for_status()
        result = response.json()["choices"][0]["message"]["content"]
    else:
        env = {k: v for k, v in os.environ.items() if k != "ATA_CONNECTOR_TOKEN"}
        if provider == "codex":
            env.pop("CODEX_API_KEY", None)
            env.pop("OPENAI_API_KEY", None)
            command = ["codex", "exec", "--ignore-user-config", "--ephemeral", "--sandbox", "read-only",
                       "--disable", "shell_tool", "-c", 'web_search="disabled"', "--skip-git-repo-check", "-"]
        elif provider == "claude":
            env.pop("ANTHROPIC_API_KEY", None)
            env.pop("ANTHROPIC_AUTH_TOKEN", None)
            command = ["claude", "-p", "--tools", "", "--strict-mcp-config",
                       "--mcp-config", '{"mcpServers":{}}', "--setting-sources", "",
                       "--no-session-persistence"]
        elif provider == "antigravity":
            settings = Path.home() / ".gemini" / "antigravity-cli" / "settings.json"
            policy = json.loads(settings.read_text(encoding="utf-8")).get("permissions", {})
            if not AGY_DENY.issubset(policy.get("deny", [])):
                raise ValueError("Configura las reglas deny del conector Antigravity en este host")
            command = ["agy", "--mode", "plan", "--sandbox", "--disable-slash-commands",
                       "--print-timeout", "90s", "-p", prompt]
        else:
            command = json.loads(os.environ.get("ATA_PROVIDER_COMMAND", "[]"))
            if not isinstance(command, list) or not command or not all(isinstance(arg, str) for arg in command):
                raise ValueError("ATA_PROVIDER_COMMAND debe ser una lista JSON de argumentos")
        with tempfile.TemporaryDirectory(prefix="ata-provider-") as cwd:
            process = subprocess.run(
                command, input="" if provider == "antigravity" else prompt,
                capture_output=True, text=True, encoding="utf-8", errors="replace",
                cwd=cwd, env=env, timeout=95, check=True,
            )
        result = process.stdout
    if not isinstance(result, str) or not result.strip():
        raise ValueError("El proveedor devolvió una respuesta vacía")
    return result.strip()[:12000]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provider", choices=PROVIDERS)
    parser.add_argument("--server", default=os.environ.get("ATA_SERVER_URL"))
    parser.add_argument("--probe", action="store_true")
    args = parser.parse_args()
    if args.probe:
        print(run_provider(args.provider, [{"role": "user", "content": "Responde solo: Conexión lista."}]))
        return
    if not args.server:
        parser.error("Indica --server o ATA_SERVER_URL")
    url = validate_server(args.server)
    token = os.environ.get("ATA_CONNECTOR_TOKEN") or getpass.getpass("Código de conexión: ").strip()
    if not token.startswith("ata_worker_"):
        parser.error("Genera un código en Proveedores de IA desde tu cuenta")
    print(f"Conectando {args.provider} a {url}", flush=True)
    with httpx.Client(base_url=url, headers={"Authorization": f"Bearer {token}"}, timeout=12) as client:
        while True:
            try:
                response = client.post("/ai/worker/claim", params={"provider": args.provider})
                if response.status_code in (401, 403):
                    raise SystemExit("Código inválido, revocado o de otro proveedor")
                response.raise_for_status()
                task = response.json()["task"]
                if task:
                    try:
                        reply = run_provider(args.provider, task["messages"])
                        body = {"lease": task["lease"], "reply": reply}
                    except Exception as error:
                        print(f"El proveedor no completó la tarea ({type(error).__name__}).", flush=True)
                        body = {"lease": task["lease"], "error": True}
                    client.put(f"/ai/worker/tasks/{task['id']}", json=body).raise_for_status()
                time.sleep(5 if task else 10)
            except httpx.HTTPError:
                print("Conexión interrumpida. Reintentando.", flush=True)
                time.sleep(15)


if __name__ == "__main__":
    main()
