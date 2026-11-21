"""Reproduce the synthetic v3 interoperability fixture using Python cryptography.

Test-only fixed salt/nonce and password; never use these values for real backups.
Run from flutter_app after installing the optional Python cryptography package.
The checked-in fixture lets Flutter CI test interoperability without Python crypto.
"""
import base64
import hashlib
import json
import struct
from pathlib import Path

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


def packed(value):
    return json.dumps(value, separators=(",", ":")).encode("utf-8")


def fixture():
    salt, prefix = bytes(range(16)), bytes(range(8))
    header = packed({
        "format": "FLEX-Stream-Backup", "version": 3, "encrypted": True,
        "chunkBytes": 65536, "iterations": 600000,
        "salt": base64.b64encode(salt).decode(),
        "noncePrefix": base64.b64encode(prefix).decode(),
    })
    key = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt,
                    iterations=600000).derive("Independent password é".encode("utf-8"))
    notebook = packed({"format": "FLEX-Flutter-Rebuild-Backup",
                       "tables": {"pupils": [], "preferences": []}})
    frames = [packed({"type": "notebook", "size": len(notebook),
                      "hash": base64.b64encode(hashlib.sha256(notebook).digest()).decode()}),
              notebook, packed({"type": "end", "files": 0, "bytes": 0})]
    result = bytearray(b"FLEXBACKUP3\n" + struct.pack(">I", len(header)) + header)
    for index, frame in enumerate(frames):
        number = struct.pack(">I", index)
        encrypted = AESGCM(key).encrypt(prefix + number, frame, header + number)
        result.extend(struct.pack(">I", len(encrypted)) + encrypted)
    return result


if __name__ == "__main__":
    Path("test/fixtures/stream_v3.bin").write_bytes(fixture())
