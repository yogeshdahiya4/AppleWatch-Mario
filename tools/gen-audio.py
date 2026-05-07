#!/usr/bin/env python3
"""
Procedurally synthesizes the game's SFX bank as 16-bit mono WAVs.

Outputs to apps/watch/PixelHop/Resources/Sounds/ — bundle path picked up by
`Sound.swift`'s `Bundle.main.url(forResource:withExtension:"wav")` lookup.

Files produced:
    jump.wav        short up-pitch chirp
    coin.wav        bright two-tone chime
    stomp.wav       low thump + tail
    hurt.wav        descending dissonant buzz
    powerUp.wav     ascending arpeggio
    levelClear.wav  triumphant arpeggio

All sounds are CC0 (we synthesised them here from sine/square/noise).
Run again to regenerate; deterministic.
"""
from __future__ import annotations
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "apps/watch/PixelHop/Resources/Sounds"
OUT.mkdir(parents=True, exist_ok=True)

SR = 22_050   # plenty for watch speaker; smaller files


def write_wav(name: str, samples: list[float]) -> None:
    """Clamp and write a mono 16-bit WAV at SR."""
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        ints = []
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32_000)
            ints.append(v)
        w.writeframes(struct.pack("<" + "h" * len(ints), *ints))


def envelope(t: float, total: float, attack: float = 0.005, release: float = 0.05) -> float:
    if t < attack:
        return t / attack
    if t > total - release:
        return max(0.0, (total - t) / release)
    return 1.0


def sine(freq: float, n: int) -> list[float]:
    return [math.sin(2 * math.pi * freq * i / SR) for i in range(n)]


def chirp(f0: float, f1: float, dur: float, vol: float = 0.4) -> list[float]:
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        # Linear pitch ramp, exponential gain envelope.
        f = f0 + (f1 - f0) * (t / dur)
        env = envelope(t, dur)
        out.append(math.sin(2 * math.pi * f * t) * env * vol)
    return out


def tone(freq: float, dur: float, vol: float = 0.4) -> list[float]:
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = envelope(t, dur)
        out.append(math.sin(2 * math.pi * freq * t) * env * vol)
    return out


def square(freq: float, dur: float, vol: float = 0.3) -> list[float]:
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = envelope(t, dur)
        s = 1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0
        out.append(s * env * vol)
    return out


def noise(dur: float, vol: float = 0.3) -> list[float]:
    n = int(dur * SR)
    import random
    out = []
    for i in range(n):
        t = i / SR
        env = envelope(t, dur)
        out.append((random.random() * 2 - 1) * env * vol)
    return out


def mix(*tracks: list[float]) -> list[float]:
    """Sum tracks element-wise, padding the shorter ones with zeros."""
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i in range(len(t)):
            out[i] += t[i]
    # Soft-limit to avoid clipping when several notes overlap.
    return [max(-1.0, min(1.0, v / max(1, len(tracks) // 2 + 1))) for v in out]


def cat(*tracks: list[float]) -> list[float]:
    out: list[float] = []
    for t in tracks:
        out.extend(t)
    return out


def main() -> None:
    print(f"Writing SFX to {OUT.relative_to(ROOT)}")

    # JUMP — short up-chirp 380→700Hz over 90ms.
    write_wav("jump", chirp(380, 720, 0.10, 0.35))

    # COIN — two-tone bright chime: 1100Hz then 1800Hz.
    coin = mix(
        tone(1100, 0.06, 0.30),
        cat([0.0] * int(SR * 0.04), tone(1800, 0.10, 0.32)),
    )
    write_wav("coin", coin)

    # STOMP — low square thump + short noise tail.
    stomp = mix(
        square(120, 0.08, 0.35),
        noise(0.07, 0.18),
    )
    write_wav("stomp", stomp)

    # HURT — descending dissonant beep.
    write_wav("hurt", chirp(560, 220, 0.22, 0.32))

    # POWER-UP — quick ascending arpeggio.
    powerUp = cat(
        tone(523.25, 0.05, 0.30),  # C5
        tone(659.25, 0.05, 0.30),  # E5
        tone(783.99, 0.05, 0.30),  # G5
        tone(1046.5, 0.10, 0.34),  # C6
    )
    write_wav("powerUp", powerUp)

    # LEVEL CLEAR — triumphant longer fanfare.
    clear = cat(
        tone(523.25, 0.10, 0.30),  # C5
        tone(659.25, 0.10, 0.30),  # E5
        tone(783.99, 0.10, 0.30),  # G5
        tone(1046.5, 0.20, 0.34),  # C6
        tone(0,      0.05),        # rest
        tone(1318.5, 0.30, 0.36),  # E6 hold
    )
    write_wav("levelClear", clear)

    print("Done.")


if __name__ == "__main__":
    main()
