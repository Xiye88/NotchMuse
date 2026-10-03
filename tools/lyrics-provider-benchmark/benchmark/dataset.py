from __future__ import annotations

import csv
import random
from pathlib import Path

from .matcher import Track


def load_tracks(path: Path) -> list[Track]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        tracks = []
        for row in reader:
            tracks.append(
                Track(
                    row.get("track_id", ""),
                    row["title"],
                    row["artist"],
                    row.get("album", ""),
                    float(row.get("duration_seconds") or row.get("duration") or 0),
                    row.get("category", ""),
                )
            )
    return tracks


def sample_tracks(tracks: list[Track], size: int | None, seed: str | None) -> list[Track]:
    if not size or size >= len(tracks):
        return tracks
    rng = random.Random(seed)
    return rng.sample(tracks, size)
