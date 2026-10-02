#!/usr/bin/env python3
"""Generate tiny stdlib-only PNG fixtures for the compiled macOS screenshot verifier."""
from pathlib import Path
import struct
import subprocess
import zlib

out = Path("build")
out.mkdir(parents=True, exist_ok=True)
size = 160

def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

def fixture(name: str, rgb: tuple[int, int, int]) -> Path:
    raw = (b"\x00" + bytes(rgb) * size) * size
    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    path = out / name
    path.write_bytes(png)
    return path

cases = (
    ("blank-white.png", (255, 255, 255), False),
    ("dark-field-ui.png", (7, 16, 9), True),
    ("realistic-green-panel.png", (90, 169, 108), True),
)
for name, color, accepted in cases:
    path = fixture(name, color)
    p = subprocess.run(["build/validate-screenshot", str(path)], text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
    assert (p.returncode == 0) == accepted, f"{name}: unexpected exit {p.returncode}: {p.stdout}"
    print(f"PASS: {name} {'visible' if accepted else 'blank rejected'}")
