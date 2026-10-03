from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class LyricLine:
    time: float
    text: str


def parse_lrc(lrc: str) -> list[LyricLine]:
    lines: list[LyricLine] = []
    for raw in lrc.splitlines():
        tags = re.findall(r"\[([0-9]+:[0-9]+(?:\.[0-9]+)?)\]", raw)
        text = re.sub(r"^(?:\[[^\]]+\])+", "", raw).strip()
        if not tags or not text:
            continue
        for tag in tags:
            minutes, seconds = tag.split(":", 1)
            lines.append(LyricLine(int(minutes) * 60 + float(seconds), text))
    return sorted(lines, key=lambda line: line.time)


def parse_krc(krc: str) -> list[LyricLine]:
    lines: list[LyricLine] = []
    for raw in krc.splitlines():
        match = re.match(r"^\[(\d+),(\d+)\](.*)$", raw)
        if not match:
            continue
        text = re.sub(r"<\d+,\d+,\d+>", "", match.group(3)).strip()
        if text:
            lines.append(LyricLine(int(match.group(1)) / 1000, text))
    return sorted(lines, key=lambda line: line.time)
