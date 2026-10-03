from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Callable


EVALUABLE_LABELS = {"top", "second", "neither"}
VERSION_MARKERS = (
    "live",
    "remix",
    "remaster",
    "acoustic",
    "cover",
    "radio edit",
)


@dataclass(frozen=True)
class CandidateEvidence:
    candidate_id: str
    title: str
    artist: str
    duration_seconds: float
    album: str = ""
    isrc: str = ""


@dataclass(frozen=True)
class GroundTruthCase:
    case_id: str
    source_title: str
    source_artist: str
    source_duration_seconds: float
    top: CandidateEvidence
    second: CandidateEvidence
    ground_truth: str
    current_selection: str | None = None
    source_album: str = ""
    source_isrc: str = ""


@dataclass(frozen=True)
class Metrics:
    correct: int = 0
    wrong_candidate: int = 0
    false_positive: int = 0
    unresolved: int = 0

    @property
    def total(self) -> int:
        return self.correct + self.false_positive + self.unresolved

    @property
    def correct_rate(self) -> float:
        return self.correct / self.total if self.total else 0.0

    @property
    def false_positive_rate(self) -> float:
        return self.false_positive / self.total if self.total else 0.0


@dataclass(frozen=True)
class Evaluation:
    current: Metrics
    experimental: Metrics
    evaluable: int
    excluded_indistinguishable: int
    excluded_insufficient: int
    resolved_ambiguities: int

    @property
    def ambiguity_resolution_rate(self) -> float:
        current_unresolved = self.current.unresolved
        if not current_unresolved:
            return 0.0
        return self.resolved_ambiguities / current_unresolved


def evaluate_strategy(
    cases: list[GroundTruthCase],
    strategy: Callable[[GroundTruthCase], str | None],
) -> Evaluation:
    current = _MutableMetrics()
    experimental = _MutableMetrics()
    evaluable = 0
    excluded_indistinguishable = 0
    excluded_insufficient = 0
    resolved_ambiguities = 0

    for item in cases:
        if item.ground_truth == "indistinguishable":
            excluded_indistinguishable += 1
            continue
        if item.ground_truth not in EVALUABLE_LABELS:
            excluded_insufficient += 1
            continue
        evaluable += 1
        current.add(item.current_selection, item.ground_truth)
        experimental_selection = strategy(item)
        experimental.add(experimental_selection, item.ground_truth)
        if (
            item.current_selection is None
            and item.ground_truth in {"top", "second"}
            and experimental_selection == item.ground_truth
        ):
            resolved_ambiguities += 1

    return Evaluation(
        current.freeze(),
        experimental.freeze(),
        evaluable,
        excluded_indistinguishable,
        excluded_insufficient,
        resolved_ambiguities,
    )


def select_stable_id_duplicate(item: GroundTruthCase) -> str | None:
    if item.top.candidate_id and item.top.candidate_id == item.second.candidate_id:
        return "top"
    return None


def select_exact_identity_duplicate(item: GroundTruthCase) -> str | None:
    top = item.top
    second = item.second
    if (
        top.candidate_id
        and top.candidate_id == second.candidate_id
        and top.title == second.title
        and top.artist == second.artist
        and top.duration_seconds == second.duration_seconds
    ):
        return "top"
    return None


def rank_with_identity_signals(item: GroundTruthCase) -> str | None:
    decisions: list[str] = []

    if item.source_isrc and item.top.isrc and item.second.isrc:
        isrc_matches = [
            side
            for side, candidate in (("top", item.top), ("second", item.second))
            if candidate.isrc and candidate.isrc.casefold() == item.source_isrc.casefold()
        ]
        if len(isrc_matches) == 1:
            decisions.append(isrc_matches[0])

    exact_identity = [
        side
        for side, candidate in (("top", item.top), ("second", item.second))
        if candidate.title == item.source_title
        and candidate.artist == item.source_artist
        and candidate.duration_seconds == item.source_duration_seconds
    ]
    if len(exact_identity) == 1:
        decisions.append(exact_identity[0])

    if not decisions or len(set(decisions)) != 1:
        return None
    selected = decisions[0]
    candidate = item.top if selected == "top" else item.second
    if _version_markers(candidate.title) != _version_markers(item.source_title):
        return None
    return selected


class _MutableMetrics:
    def __init__(self) -> None:
        self.correct = 0
        self.wrong_candidate = 0
        self.false_positive = 0
        self.unresolved = 0

    def add(self, selected: str | None, truth: str) -> None:
        if selected is None:
            if truth == "neither":
                self.correct += 1
            else:
                self.unresolved += 1
        elif selected == truth:
            self.correct += 1
        else:
            if truth in {"top", "second"} and selected in {"top", "second"}:
                self.wrong_candidate += 1
            self.false_positive += 1

    def freeze(self) -> Metrics:
        return Metrics(
            self.correct,
            self.wrong_candidate,
            self.false_positive,
            self.unresolved,
        )


def _version_markers(*values: str) -> frozenset[str]:
    folded = " ".join(_fold(value) for value in values)
    markers = {
        marker
        for marker in VERSION_MARKERS
        if re.search(rf"\b{re.escape(marker)}(?:ed)?\b", folded)
    }
    for marker in ("feat", "ft", "featuring", "with"):
        if re.search(rf"\b{marker}\.?\b", folded):
            markers.add(marker)
    return frozenset(markers)


def _fold(value: str) -> str:
    return "".join(
        ch
        for ch in unicodedata.normalize("NFKD", value.casefold())
        if not unicodedata.combining(ch)
    )


def _normalize(value: str) -> str:
    return "".join(ch for ch in _fold(value) if ch.isalnum())
