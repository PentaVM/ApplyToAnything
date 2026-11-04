"""Capa de datos: SQLite estándar (sin ORM), seguro para hilos."""
import json
import secrets
import sqlite3
import threading
import time

from .config import DATABASE_URL, DB_PATH, ON_VERCEL

_lock = threading.RLock()  # reentrante: query()/execute() toman el lock y llaman a conn()
_conn: sqlite3.Connection | None = None
_postgres_ready = False

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS preferences (
  user_id INTEGER PRIMARY KEY REFERENCES users(id),
  data TEXT NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS applications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  job_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  company TEXT NOT NULL DEFAULT '',
  url TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT '',
  country TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'liked',
  method TEXT NOT NULL DEFAULT 'external_url',
  cover_letter TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  UNIQUE(user_id, job_id)
);
CREATE TABLE IF NOT EXISTS chat_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS ai_connectors (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  token_hash TEXT UNIQUE NOT NULL,
  seen_at BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY(user_id, provider)
);
CREATE TABLE IF NOT EXISTS ai_settings (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS ai_tasks (
  id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  request TEXT NOT NULL,
  created_at BIGINT NOT NULL,
  state TEXT NOT NULL DEFAULT 'queued',
  lease TEXT,
  lease_until BIGINT,
  reply TEXT
);
CREATE INDEX IF NOT EXISTS ai_task_queue ON ai_tasks(user_id, provider, state, created_at);
CREATE TABLE IF NOT EXISTS viewed_jobs (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  job_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  seen_at BIGINT NOT NULL,
  PRIMARY KEY(user_id, job_id)
);
"""


def conn() -> sqlite3.Connection:
    global _conn
    with _lock:
        if _conn is None:
            c = sqlite3.connect(DB_PATH, check_same_thread=False)
            c.row_factory = sqlite3.Row
            c.executescript(SCHEMA)
            c.commit()
            _conn = c
    return _conn


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _postgres():
    import psycopg
    from psycopg.rows import dict_row

    return psycopg.connect(DATABASE_URL, row_factory=dict_row, connect_timeout=8)


def _initialize_postgres(connection):
    global _postgres_ready
    with _lock:
        if not _postgres_ready:
            with connection.transaction():
                connection.execute("SELECT pg_advisory_xact_lock(734525154)")
                schema = SCHEMA.replace("INTEGER PRIMARY KEY AUTOINCREMENT", "SERIAL PRIMARY KEY")
                for statement in schema.split(";"):
                    if statement.strip():
                        connection.execute(statement)
            _postgres_ready = True


def _run(sql, params, *, fetch=False, many=False):
    if DATABASE_URL:
        with _postgres() as connection:
            _initialize_postgres(connection)
            with connection.cursor() as cursor:
                if many:
                    cursor.executemany(sql.replace("?", "%s"), params)
                else:
                    cursor.execute(sql.replace("?", "%s"), params)
                return cursor.fetchall() if fetch else cursor.rowcount
    if ON_VERCEL:
        from fastapi import HTTPException

        raise HTTPException(status_code=503, detail="Falta configurar PostgreSQL en el servidor")
    with _lock, conn() as connection:
        cursor = connection.executemany(sql, params) if many else connection.execute(sql, params)
        return cursor.fetchall() if fetch else cursor.rowcount


def query(sql: str, params=()):
    return _run(sql, params, fetch=True)


def execute(sql: str, params=()):
    return _run(sql, params)


def execute_many(sql, rows):
    return _run(sql, rows, many=True)


def get_jwt_secret() -> str:
    rows = query("SELECT value FROM meta WHERE key='jwt_secret'")
    if rows:
        return rows[0]["value"]
    secret = secrets.token_hex(32)
    execute("INSERT INTO meta(key, value) VALUES('jwt_secret', ?) ON CONFLICT(key) DO NOTHING", (secret,))
    return query("SELECT value FROM meta WHERE key='jwt_secret'")[0]["value"]


def get_prefs(user_id: int) -> dict:
    rows = query("SELECT data FROM preferences WHERE user_id = ?", (user_id,))
    if not rows:
        return {}
    try:
        return json.loads(rows[0]["data"] or "{}")
    except json.JSONDecodeError:
        return {}


def save_prefs(user_id: int, data: dict) -> None:
    execute(
        "INSERT INTO preferences(user_id, data) VALUES(?, ?) "
        "ON CONFLICT(user_id) DO UPDATE SET data = excluded.data",
        (user_id, json.dumps(data, ensure_ascii=False)),
    )


def log_chat(user_id: int, role: str, content: str) -> None:
    execute(
        "INSERT INTO chat_messages(user_id, role, content, created_at) VALUES(?,?,?,?)",
        (user_id, role, content[:8000], now()),
    )
