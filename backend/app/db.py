"""Capa de datos: SQLite estándar (sin ORM), seguro para hilos."""
import json
import secrets
import sqlite3
import threading
import time

from .config import DB_PATH

_lock = threading.RLock()  # reentrante: query()/execute() toman el lock y llaman a conn()
_conn: sqlite3.Connection | None = None

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


def query(sql: str, params=()):
    with _lock:
        return conn().execute(sql, params).fetchall()


def execute(sql: str, params=()):
    with _lock:
        cur = conn().execute(sql, params)
        conn().commit()
        return cur


def get_jwt_secret() -> str:
    rows = query("SELECT value FROM meta WHERE key='jwt_secret'")
    if rows:
        return rows[0]["value"]
    secret = secrets.token_hex(32)
    execute("INSERT OR IGNORE INTO meta(key, value) VALUES('jwt_secret', ?)", (secret,))
    return secret


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
