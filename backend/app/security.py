"""Hash de contraseñas (PBKDF2) y tokens JWT."""
import base64
import hashlib
import hmac
import os
import time

import jwt

from .config import JWT_EXPIRE_DAYS
from .db import get_jwt_secret


def hash_password(pw: str) -> str:
    salt = os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", pw.encode("utf-8"), salt, 120_000)
    return "pbkdf2$120000$" + base64.b64encode(salt).decode() + "$" + base64.b64encode(dk).decode()


def verify_password(pw: str, stored: str) -> bool:
    try:
        _, iters, salt_b64, dk_b64 = stored.split("$")
        salt = base64.b64decode(salt_b64)
        dk = hashlib.pbkdf2_hmac("sha256", pw.encode("utf-8"), salt, int(iters))
        return hmac.compare_digest(base64.b64encode(dk).decode(), dk_b64)
    except Exception:
        return False


def create_token(user_id: int, email: str) -> str:
    payload = {
        "sub": str(user_id),
        "email": email,
        "exp": int(time.time()) + JWT_EXPIRE_DAYS * 86400,
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm="HS256")


def decode_token(token: str) -> int:
    payload = jwt.decode(token, get_jwt_secret(), algorithms=["HS256"])
    return int(payload["sub"])
