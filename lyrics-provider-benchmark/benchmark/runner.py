from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from typing import Awaitable, Callable

from .matcher import Track


Provider = Callable[[Track], Awaitable["ProviderResult"]]


@dataclass(frozen=True)
class ProviderResult:
    provider: str
    status: str
    lyrics_available: bool
    failure_reason: str | None
    line_count: int
    latency_ms: int
    match_score: int | None = None
    matched_title: str | None = None
    matched_artist: str | None = None
    matched_duration_seconds: float | None = None
    raw_error: str | None = None
    top_score: int | None = None
    second_score: int | None = None
    reject_reason: str | None = None


async def run_track(track: Track, providers: list[tuple[str, Provider]]) -> list[ProviderResult]:
    results = []
    for _name, provider in providers:
        results.append(await provider(track))
    return results


def timed_result(provider: str, started: float, lines: int, reason: str | None = None, error: str | None = None) -> ProviderResult:
    ok = lines > 0 and reason is None and error is None
    return ProviderResult(
        provider=provider,
        status="success" if ok else "failed",
        lyrics_available=ok,
        failure_reason=None if ok else reason or "unknown_error",
        line_count=lines if ok else 0,
        latency_ms=int((time.monotonic() - started) * 1000),
        raw_error=error,
    )


async def gather_tracks(
    tracks: list[Track],
    providers: list[tuple[str, Provider]],
    concurrency: int,
) -> dict[Track, list[ProviderResult]]:
    semaphore = asyncio.Semaphore(concurrency)

    async def run_one(track: Track) -> tuple[Track, list[ProviderResult]]:
        async with semaphore:
            return track, await run_track(track, providers)

    return dict(await asyncio.gather(*(run_one(track) for track in tracks)))
