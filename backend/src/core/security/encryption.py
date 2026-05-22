import os
import base64
import json
import logging
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger("darsak")


def generate_salt() -> bytes:
    return os.urandom(16)


def derive_teacher_key(teacher_password: str, salt: bytes) -> str:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100_000,
    )
    key = kdf.derive(teacher_password.encode("utf-8"))
    return base64.urlsafe_b64encode(key).decode("utf-8")


def encrypt_payload(data: dict, teacher_key: str) -> dict:
    key = base64.urlsafe_b64decode(teacher_key)
    aesgcm = AESGCM(key)
    iv = os.urandom(12)
    plaintext = json.dumps(data, ensure_ascii=False).encode("utf-8")
    ct_with_tag = aesgcm.encrypt(iv, plaintext, None)
    ciphertext = ct_with_tag[:-16]
    auth_tag = ct_with_tag[-16:]
    return {
        "ciphertext": base64.b64encode(ciphertext).decode("utf-8"),
        "iv": base64.b64encode(iv).decode("utf-8"),
        "auth_tag": base64.b64encode(auth_tag).decode("utf-8"),
    }


def decrypt_payload(ciphertext: str, iv: str, auth_tag: str, teacher_key: str) -> dict:
    key = base64.urlsafe_b64decode(teacher_key)
    aesgcm = AESGCM(key)
    ct = base64.b64decode(ciphertext)
    iv_bytes = base64.b64decode(iv)
    tag = base64.b64decode(auth_tag)
    plaintext = aesgcm.decrypt(iv_bytes, ct + tag, None)
    return json.loads(plaintext.decode("utf-8"))
