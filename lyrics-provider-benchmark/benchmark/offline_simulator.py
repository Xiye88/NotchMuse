from __future__ import annotations

import csv
import re
import sqlite3
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path


LABELS = {"top", "second", "neither", "uncertain"}


@dataclass(frozen=True)
class RankingCase:
    case_id: str
    source_title: str
    source_artist: str
    source_duration_seconds: float
    top_title: str | None = None
    top_artist: str | None = None
    top_duration_seconds: float | None = None
    second_title: str | None = None
    second_artist: str | None = None
    second_duration_seconds: float | None = None
    second_score: int | None = None
    old_decision: str | None = None
    label: str = "uncertain"
    source_album: str = ""
    top_album: str | None = None
    second_album: str | None = None


@dataclass(frozen=True)
class Signals:
    duration_difference: bool = False
    complete_artist_exact: bool = False
    album_version_metadata: bool = False
    title_remastered: bool = False
    title_live: bool = False
    title_deluxe: bool = False
    title_feat: bool = False
    title_ft: bool = False


@dataclass(frozen=True)
class OutcomeMetrics:
    correct: int = 0
    false_positive: int = 0
    unresolved: int = 0
    total: int = 0

    @property
    def correct_candidate_rate(self) -> float:
        return round(self.correct / self.total, 4) if self.total else 0.0

    @property
    def false_positive_rate(self) -> float:
        return round(self.false_positive / self.total, 4) if self.total else 0.0


@dataclass(frozen=True)
class SimulationResult:
    old: OutcomeMetrics
    experimental: OutcomeMetrics
    eligibility: dict[str, int]
    ambiguous_unresolved: int
    signal_unavailable: dict[str, int] = field(default_factory=dict)


def evaluate_cases(cases: list[RankingCase], signals: Signals) -> SimulationResult:
    old_counts = _Counts()
    experimental_counts = _Counts()
    eligibility = {"eligible": 0, "missing_evidence": 0, "missing_ground_truth": 0}
    signal_unavailable: dict[str, int] = {}
    ambiguous_unresolved = 0

    for case in cases:
        if case.label not in LABELS or case.label == "uncertain":
            eligibility["missing_ground_truth"] += 1
            ambiguous_unresolved += 1
            continue
        if not _has_candidate_pair(case):
            eligibility["missing_evidence"] += 1
            continue

        eligibility["eligible"] += 1
        old_counts.add(_old_selection(case), case.label)
        experimental_counts.add(_experimental_selection(case, signals, signal_unavailable), case.label)

    return SimulationResult(
        old=old_counts.metrics(),
        experimental=experimental_counts.metrics(),
        eligibility=eligibility,
        ambiguous_unresolved=ambiguous_unresolved,
        signal_unavailable=signal_unavailable,
    )


def load_cases_from_csv(path: Path) -> list[RankingCase]:
    with path.open(newline="", encoding="utf-8") as handle:
        return [_case_from_mapping(row) for row in csv.DictReader(handle)]


def load_cases_from_sqlite(db: sqlite3.Connection, run_id: int) -> list[RankingCase]:
    rows = db.execute(
        """
        select pr.id as case_id, s.title as source_title, s.artist as source_artist,
               s.album as source_album, s.duration_seconds as source_duration_seconds,
               pr.matched_title as top_title, pr.matched_artist as top_artist,
               pr.matched_duration_seconds as top_duration_seconds,
               pr.second_matched_title as second_title, pr.second_matched_artist as second_artist,
               pr.second_matched_duration_seconds as second_duration_seconds,
               pr.second_score, pr.reject_reason as old_decision
        from provider_results pr
        join songs s on s.id=pr.song_id
        where pr.run_id=? and pr.failure_reason='matching_failed'
        """,
        (run_id,),
    )
    return [_case_from_mapping(dict(row)) for row in rows]


class _Counts:
    def __init__(self) -> None:
        self.correct = 0
        self.false_positive = 0
        self.unresolved = 0
        self.total = 0

    def add(self, selected: str | None, label: str) -> None:
        self.total += 1
        if selected is None:
            self.unresolved += 1
        elif selected == label:
            self.correct += 1
        elif label == "neither" or selected in {"top", "second"}:
            self.false_positive += 1

    def metrics(self) -> OutcomeMetrics:
        return OutcomeMetrics(self.correct, self.false_positive, self.unresolved, self.total)


def _case_from_mapping(row: dict) -> RankingCase:
    return RankingCase(
        case_id=str(row.get("case_id") or row.get("id") or ""),
        source_title=str(row.get("source_title") or ""),
        source_artist=str(row.get("source_artist") or ""),
        source_album=str(row.get("source_album") or ""),
        source_duration_seconds=_float(row.get("source_duration_seconds")),
        top_title=_optional_str(row.get("top_title") or row.get("candidate_title") or row.get("matched_title")),
        top_artist=_optional_str(row.get("top_artist") or row.get("candidate_artist") or row.get("matched_artist")),
        top_duration_seconds=_optional_float(row.get("top_duration_seconds") or row.get("candidate_duration_seconds") or row.get("matched_duration_seconds")),
        second_title=_optional_str(row.get("second_title") or row.get("second_matched_title")),
        second_artist=_optional_str(row.get("second_artist") or row.get("second_matched_artist")),
        second_duration_seconds=_optional_float(row.get("second_duration_seconds") or row.get("second_matched_duration_seconds")),
        second_score=_optional_int(row.get("second_score")),
        old_decision=_optional_str(row.get("old_decision") or row.get("reject_reason")),
        label=str(row.get("label") or row.get("manual_label") or "uncertain"),
        top_album=_optional_str(row.get("top_album") or row.get("matched_album")),
        second_album=_optional_str(row.get("second_album") or row.get("second_matched_album")),
    )


def _has_candidate_pair(case: RankingCase) -> bool:
    return all(
        value is not None
        for value in (
            case.top_title,
            case.top_artist,
            case.top_duration_seconds,
            case.second_title,
            case.second_artist,
            case.second_duration_seconds,
        )
    )


def _old_selection(case: RankingCase) -> str | None:
    return case.old_decision if case.old_decision in {"top", "second"} else None


def _experimental_selection(case: RankingCase, signals: Signals, unavailable: dict[str, int]) -> str | None:
    top = _signal_score(case, "top", signals, unavailable)
    second = _signal_score(case, "second", signals, unavailable)
    if top == second:
        return None
    return "top" if top > second else "second"


def _signal_score(case: RankingCase, side: str, signals: Signals, unavailable: dict[str, int]) -> float:
    title = case.top_title if side == "top" else case.second_title
    artist = case.top_artist if side == "top" else case.second_artist
    duration = case.top_duration_seconds if side == "top" else case.second_duration_seconds
    album = case.top_album if side == "top" else case.second_album
    total = 0.0

    if signals.duration_difference:
        total -= abs(case.source_duration_seconds - float(duration))
    if signals.complete_artist_exact:
        total += 10 if _normalize(case.source_artist) == _normalize(str(artist)) else 0
    if signals.album_version_metadata:
        if not case.source_album or not album:
            unavailable["album_version_metadata"] = unavailable.get("album_version_metadata", 0) + 1
        else:
            total += 1 if _normalize(case.source_album) == _normalize(album) else 0
    total += _title_signal(case.source_title, str(title), signals)
    return total


def _title_signal(source: str, candidate: str, signals: Signals) -> float:
    total = 0.0
    if signals.title_live and _marker_mismatch(source, candidate, "live"):
        return -1000.0
    for field, marker in (
        (signals.title_remastered, "remaster"),
        (signals.title_deluxe, "deluxe"),
        (signals.title_feat, "feat"),
        (signals.title_ft, "ft"),
    ):
        if field and (_has_marker(source, marker) or _has_marker(candidate, marker)) and _strip_marker(source, marker) == _strip_marker(candidate, marker):
            total += 1
    return total


def _marker_mismatch(source: str, candidate: str, marker: str) -> bool:
    return _has_marker(source, marker) != _has_marker(candidate, marker)


def _has_marker(text: str, marker: str) -> bool:
    return re.search(_marker_pattern(marker), text, flags=re.I) is not None


def _strip_marker(text: str, marker: str) -> str:
    return _normalize(re.sub(_marker_pattern(marker), "", text, flags=re.I))


def _marker_pattern(marker: str) -> str:
    if marker == "remaster":
        return r"\bremaster(?:ed)?\b"
    if marker == "feat":
        return r"\bfeat(?:\.|uring)?\b.*$"
    return rf"\b{re.escape(marker)}\.?\b"


def _normalize(text: str) -> str:
    folded = "".join(ch for ch in unicodedata.normalize("NFKD", text.casefold()) if not unicodedata.combining(ch))
    return "".join(ch for ch in folded if ch.isalnum())


def _optional_str(value: object) -> str | None:
    text = "" if value is None else str(value)
    return text or None


def _float(value: object) -> float:
    return float(value or 0)


def _optional_float(value: object) -> float | None:
    return None if value in (None, "") else float(value)


def _optional_int(value: object) -> int | None:
    return None if value in (None, "") else int(value)
