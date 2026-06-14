import pytest
from src.core.security.encryption import (
    generate_salt,
    derive_teacher_key,
    encrypt_payload,
    decrypt_payload,
)


class TestDeriveKey:
    def test_salt_generation_is_unique(self):
        salt1 = generate_salt()
        salt2 = generate_salt()
        assert salt1 != salt2

    def test_salt_has_minimum_length(self):
        salt = generate_salt()
        assert len(salt) >= 16

    def test_derive_key_deterministic(self):
        key1 = derive_teacher_key("test_password", b"test_salt_12345678")
        key2 = derive_teacher_key("test_password", b"test_salt_12345678")
        assert key1 == key2

    def test_derive_key_different_passwords(self):
        key1 = derive_teacher_key("password1", b"test_salt_12345678")
        key2 = derive_teacher_key("password2", b"test_salt_12345678")
        assert key1 != key2

    def test_derive_key_different_salts(self):
        key1 = derive_teacher_key("test_password", b"salt_1_of_16_")
        key2 = derive_teacher_key("test_password", b"salt_2_of_16_")
        assert key1 != key2


class TestEncryptDecrypt:
    def test_encrypt_decrypt_roundtrip(self):
        key = derive_teacher_key("test", generate_salt())
        data = {"student": "Ali", "grade": 95}
        encrypted = encrypt_payload(data, key)
        assert "ciphertext" in encrypted
        assert "iv" in encrypted
        assert "auth_tag" in encrypted
        decrypted = decrypt_payload(
            encrypted["ciphertext"],
            encrypted["iv"],
            encrypted["auth_tag"],
            key,
        )
        assert decrypted == data

    def test_decrypt_wrong_key_fails(self):
        key1 = derive_teacher_key("password1", generate_salt())
        key2 = derive_teacher_key("password2", generate_salt())
        data = {"test": "data"}
        encrypted = encrypt_payload(data, key1)
        with pytest.raises(Exception):
            decrypt_payload(
                encrypted["ciphertext"],
                encrypted["iv"],
                encrypted["auth_tag"],
                key2,
            )

    def test_encrypt_produces_different_ciphertext(self):
        key = derive_teacher_key("test", generate_salt())
        data = {"msg": "same"}
        e1 = encrypt_payload(data, key)
        e2 = encrypt_payload(data, key)
        assert e1["ciphertext"] != e2["ciphertext"]

    def test_encrypt_empty_dict(self):
        key = derive_teacher_key("test", generate_salt())
        encrypted = encrypt_payload({}, key)
        decrypted = decrypt_payload(
            encrypted["ciphertext"],
            encrypted["iv"],
            encrypted["auth_tag"],
            key,
        )
        assert decrypted == {}

    def test_encrypt_large_data(self):
        key = derive_teacher_key("test", generate_salt())
        data = {"data": "X" * 100000}
        encrypted = encrypt_payload(data, key)
        decrypted = decrypt_payload(
            encrypted["ciphertext"],
            encrypted["iv"],
            encrypted["auth_tag"],
            key,
        )
        assert decrypted == data

    def test_tampered_ciphertext_fails(self):
        key = derive_teacher_key("test", generate_salt())
        data = {"secret": "value"}
        encrypted = encrypt_payload(data, key)
        tampered = bytearray(encrypted["ciphertext"], "utf-8")
        tampered[0] ^= 0xFF
        with pytest.raises(Exception):
            decrypt_payload(
                bytes(tampered).decode("utf-8", errors="replace"),
                encrypted["iv"],
                encrypted["auth_tag"],
                key,
            )
