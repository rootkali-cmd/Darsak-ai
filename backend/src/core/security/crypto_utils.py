import os
import hmac
import json
import base64
import hashlib
import secrets
import logging

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

logger = logging.getLogger("darsak")

HMAC_KEY = os.environ.get("HMAC_SECRET_KEY", "")
AES_KEY_B64 = os.environ.get("AES_ENCRYPTION_KEY", "")


def _get_aes_key() -> bytes:
    if not HMAC_KEY:
        raise ValueError("HMAC_SECRET_KEY not set")
    if AES_KEY_B64:
        return base64.b64decode(AES_KEY_B64)
    salt = secrets.token_bytes(16)
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    from cryptography.hazmat.primitives import hashes
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=600_000,
    )
    return kdf.derive(HMAC_KEY.encode("utf-8"))


def generate_license_key() -> str:
    parts = []
    for _ in range(4):
        part = secrets.token_hex(2).upper()
        parts.append(part)
    return "-".join(parts)


def sign_data(data: dict) -> str:
    payload = json.dumps(data, separators=(",", ":"), sort_keys=True)
    signature = hmac.new(
        HMAC_KEY.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return signature


def verify_signature(data: dict, signature: str) -> bool:
    expected = sign_data(data)
    return hmac.compare_digest(expected, signature)


def encrypt_payload(data: dict) -> str:
    key = _get_aes_key()
    aesgcm = AESGCM(key)
    iv = os.urandom(12)
    plaintext = json.dumps(data, ensure_ascii=False).encode("utf-8")
    ct_with_tag = aesgcm.encrypt(iv, plaintext, None)
    result = {
        "iv": base64.b64encode(iv).decode("utf-8"),
        "ciphertext": base64.b64encode(ct_with_tag).decode("utf-8"),
    }
    return base64.b64encode(json.dumps(result).encode("utf-8")).decode("utf-8")


def decrypt_payload(encrypted: str) -> dict:
    try:
        blob = json.loads(base64.b64decode(encrypted).decode("utf-8"))
        key = _get_aes_key()
        aesgcm = AESGCM(key)
        iv = base64.b64decode(blob["iv"])
        ct = base64.b64decode(blob["ciphertext"])
        plaintext = aesgcm.decrypt(iv, ct, None)
        return json.loads(plaintext.decode("utf-8"))
    except Exception as e:
        logger.error("Decryption failed: %s", e)
        raise ValueError("Failed to decrypt payload")
