import pytest

from src.core.security.encryption import (
    generate_salt,
    derive_teacher_key,
    encrypt_payload,
    decrypt_payload,
)


def test_derive_key_deterministic():
    password = "my_secret_password"
    salt = b"fixed_salt_16b!!"
    key1 = derive_teacher_key(password, salt)
    key2 = derive_teacher_key(password, salt)
    assert key1 == key2
    assert len(key1) > 0


def test_derive_key_different_passwords():
    salt = generate_salt()
    key1 = derive_teacher_key("password1", salt)
    key2 = derive_teacher_key("password2", salt)
    assert key1 != key2


def test_encrypt_decrypt_roundtrip():
    original_data = {
        "student_id": "abc-123",
        "score": 85.5,
        "exam": "midterm",
    }
    password = "teacher_password"
    salt = generate_salt()
    key = derive_teacher_key(password, salt)

    encrypted = encrypt_payload(original_data, key)
    assert "ciphertext" in encrypted
    assert "iv" in encrypted
    assert "auth_tag" in encrypted

    decrypted = decrypt_payload(
        encrypted["ciphertext"],
        encrypted["iv"],
        encrypted["auth_tag"],
        key,
    )
    assert decrypted == original_data


def test_decrypt_wrong_key_fails():
    original_data = {"secret": "data"}
    key1 = derive_teacher_key("password1", generate_salt())
    key2 = derive_teacher_key("password2", generate_salt())

    encrypted = encrypt_payload(original_data, key1)

    with pytest.raises(Exception):
        decrypt_payload(
            encrypted["ciphertext"],
            encrypted["iv"],
            encrypted["auth_tag"],
            key2,
        )


def test_encrypt_produces_different_ciphertext():
    data = {"same": "data"}
    key = derive_teacher_key("password", generate_salt())

    enc1 = encrypt_payload(data, key)
    enc2 = encrypt_payload(data, key)

    assert enc1["ciphertext"] != enc2["ciphertext"]
    assert enc1["iv"] != enc2["iv"]
