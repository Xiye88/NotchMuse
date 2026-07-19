from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from difflib import SequenceMatcher


ACCEPTANCE_THRESHOLD = 80


@dataclass(frozen=True)
class Track:
    track_id: str
    title: str
    artist: str
    album: str
    duration_seconds: float
    category: str = ""


@dataclass(frozen=True)
class Candidate:
    title: str
    artists: list[str]
    duration_ms: int
    album: str = ""


def score(track: Track, candidate: Candidate) -> int:
    source_title = _parsed_title(track.title)
    candidate_title = _parsed_title(candidate.title)
    duration_difference = abs(track.duration_seconds - candidate.duration_ms / 1000)

    if source_title[1] != candidate_title[1] or duration_difference > 12:
        return 0

    title_similarity = _similarity(source_title[0], candidate_title[0])
    if title_similarity < 0.82:
        return 0

    artist_similarity = _artist_similarity([track.artist], candidate.artists)
    minimum_artist_similarity = 0.5 if title_similarity == 1 and duration_difference <= 2 else 0.62
    if artist_similarity < minimum_artist_similarity:
        return 0

    title_score = round(title_similarity * 50)
    artist_score = round(artist_similarity * 30)
    if duration_difference <= 2:
        duration_score = 15
    elif duration_difference <= 5:
        duration_score = 11
    elif duration_difference <= 8:
        duration_score = 7
    else:
        duration_score = 3
    album_score = 5 if track.album and candidate.album and _similarity(_normalize(track.album), _normalize(candidate.album)) >= 0.85 else 0
    return title_score + artist_score + duration_score + album_score


def best_match_index(track: Track, candidates: list[Candidate]) -> int | None:
    ranked = sorted(enumerate(candidates), key=lambda item: score(track, item[1]), reverse=True)
    if not ranked or score(track, ranked[0][1]) < ACCEPTANCE_THRESHOLD:
        return None
    if len(ranked) >= 2 and score(track, ranked[0][1]) - score(track, ranked[1][1]) < 6:
        return None
    return ranked[0][0]


def _parsed_title(title: str) -> tuple[str, set[str]]:
    name = _fold(title)
    for pattern in (
        r"[\(\[].*?\b(feat\.?|ft\.?|featuring)\b.*?[\)\]]",
        r"\s+\b(feat\.?|ft\.?|featuring)\b.*$",
        r"[\(\[].*?\b(ost|original soundtrack|theme|from|movie|film|drama|tv|电视剧|電影|电影|主題曲|主题曲|插曲|片尾曲|心动曲)\b.*?[\)\]]",
        r"[\(\[].*?(电视剧|電影|电影|主題曲|主题曲|插曲|片尾曲|心动曲).*?[\)\]]",
    ):
        name = re.sub(pattern, "", name, flags=re.I)
    versions = {word for word in ("live", "remix", "acoustic", "instrumental") if re.search(rf"\b{word}\b", name)}
    for pattern in (
        r"[\(\[].*?\b(remaster(ed)?|version|live|remix|acoustic|instrumental)\b.*?[\)\]]",
        r"\s+-\s+.*\b(remaster(ed)?|version|live|remix|acoustic|instrumental)\b.*$",
    ):
        name = re.sub(pattern, "", name, flags=re.I)
    versions.discard("remaster")
    return _normalize(name), versions


def _artist_keys(artists: list[str]) -> tuple[set[str], set[str]]:
    cleaned = [
        re.sub(
            r"\b(feat\.?|ft\.?|featuring|with|and)\b",
            ",",
            _alias(artist),
            flags=re.I,
        )
        for artist in artists
    ]
    members = {_normalize(part) for artist in cleaned for part in re.split(r"[,/&;×、＋+]| x ", artist, flags=re.I) if _normalize(part)}
    group = {_normalize(part) for artist in cleaned for part in re.split(r"[,/&;×、＋+]| x ", artist, flags=re.I) if _normalize(part)}
    return members, group


def _fold(text: str) -> str:
    return "".join(ch for ch in unicodedata.normalize("NFKD", text.casefold()) if not unicodedata.combining(ch))


def _normalize(text: str) -> str:
    return "".join(ch for ch in _fold(text) if ch.isalnum())


def _similarity(left: str, right: str) -> float:
    if not left or not right:
        return 0
    if left == right:
        return 1
    if left in right or right in left:
        return min(len(left), len(right)) / max(len(left), len(right))
    return SequenceMatcher(None, left, right).ratio()


def _artist_similarity(source: list[str], candidate: list[str]) -> float:
    source_members, source_group = _artist_keys(source)
    candidate_members, candidate_group = _artist_keys(candidate)
    if source_members == candidate_members or source_group == candidate_group:
        return 1
    if source_members & candidate_members:
        return len(source_members & candidate_members) / max(len(source_members), len(candidate_members))
    source_text = _normalize("".join(sorted(source_group)))
    candidate_text = _normalize("".join(sorted(candidate_group)))
    return _similarity(source_text, candidate_text)


def _alias(text: str) -> str:
    aliases = {
        "薛之謙": "薛之谦",
        "周杰倫": "周杰伦",
        "汪苏泷": "silence wang",
        "silence wang": "silence wang",
        "JC 陈咏桐": "JC",
    }
    value = text
    for source, target in aliases.items():
        value = re.sub(re.escape(source), target, value, flags=re.I)
    return value
