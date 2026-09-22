#!/usr/bin/env python3
"""소리 파일 생성 (T-01 → 2026-09-18 변경).

    python3 tools/make_sounds.py

- `countdown-beep.caf` : 마지막 3초 매초 울리는 작은 beep (합성)
- `rest-end.caf`       : 휴식 끝 벨. 사용자가 넣은 `tools/sounds/boxing-opening-bell.mp3`를 caf(mono, 16bit)로 변환

표준 라이브러리 + macOS `afconvert` 만 쓴다. 알림(UNNotificationSound)에 쓰려면 30초 미만 aiff/wav/caf 여야 한다.
"""
import math
import struct
import subprocess
import wave
from pathlib import Path

RATE = 44100
ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / "NextSet" / "NextSet" / "Sounds"


def beep(freq: float, length: float, gain: float) -> list[float]:
    """짧고 부드러운 beep: 사인파 + 5ms 어택/릴리즈."""
    n = int(RATE * length)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.005, (length - t) / 0.02)
        out.append(math.sin(2 * math.pi * freq * t) * max(0.0, env) * gain)
    return out


def write_wav_as_caf(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    wav = OUT / f"{name}.wav"
    caf = OUT / f"{name}.caf"
    with wave.open(str(wav), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", str(wav), str(caf)], check=True)
    wav.unlink()
    print(f"{caf.name}: {len(samples) / RATE:.2f}s")


# 마지막 3초 beep — 1kHz, 90ms, 작게(0.35)
write_wav_as_caf("countdown-beep", beep(1000.0, 0.09, 0.35))

# 휴식 끝 벨 — mp3 → caf
src = ROOT / "sounds" / "boxing-opening-bell.mp3"
subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", "-c", "1", str(src), str(OUT / "rest-end.caf")], check=True)
print("rest-end.caf: from", src.name)
