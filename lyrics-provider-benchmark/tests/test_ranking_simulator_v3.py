import unittest

from benchmark.ranking_simulator_v3 import (
    CandidateEvidence,
    GroundTruthCase,
    evaluate_strategy,
    rank_with_identity_signals,
    select_exact_identity_duplicate,
    select_stable_id_duplicate,
)


def candidate(
    candidate_id: str,
    title: str = "Song",
    artist: str = "Artist",
    duration: float = 200.0,
    album: str = "",
    isrc: str = "",
) -> CandidateEvidence:
    return CandidateEvidence(candidate_id, title, artist, duration, album, isrc)


def case(
    *,
    label: str,
    top: CandidateEvidence | None = None,
    second: CandidateEvidence | None = None,
    current: str | None = None,
    source_title: str = "Song",
    source_artist: str = "Artist",
    source_duration: float = 200.0,
    source_album: str = "",
    source_isrc: str = "",
) -> GroundTruthCase:
    return GroundTruthCase(
        case_id="case",
        source_title=source_title,
        source_artist=source_artist,
        source_duration_seconds=source_duration,
        source_album=source_album,
        source_isrc=source_isrc,
        top=top or candidate("top"),
        second=second or candidate("second"),
        ground_truth=label,
        current_selection=current,
    )


class RankingSimulatorV3Tests(unittest.TestCase):
    def test_excludes_insufficient_metadata_from_accuracy_denominator(self):
        cases = [
            case(label="top", current="top"),
            case(label="insufficient_metadata"),
        ]

        result = evaluate_strategy(cases, lambda item: "top")

        self.assertEqual(result.evaluable, 1)
        self.assertEqual(result.excluded_insufficient, 1)
        self.assertEqual(result.experimental.correct, 1)
        self.assertEqual(result.experimental.false_positive, 0)

    def test_counts_a_wrong_selection_as_confirmed_false_positive(self):
        cases = [case(label="second", current=None)]

        result = evaluate_strategy(cases, lambda item: "top")

        self.assertEqual(result.experimental.correct, 0)
        self.assertEqual(result.experimental.wrong_candidate, 1)
        self.assertEqual(result.experimental.false_positive, 1)
        self.assertEqual(result.experimental.false_positive_rate, 1.0)

    def test_neither_selection_is_false_positive_but_not_wrong_candidate(self):
        result = evaluate_strategy(
            [case(label="neither", current=None)],
            lambda item: "top",
        )

        self.assertEqual(result.experimental.wrong_candidate, 0)
        self.assertEqual(result.experimental.false_positive, 1)

    def test_neither_rejection_is_correct(self):
        result = evaluate_strategy(
            [case(label="neither", current=None)],
            lambda item: None,
        )

        self.assertEqual(result.current.correct, 1)
        self.assertEqual(result.experimental.correct, 1)

    def test_ambiguity_resolution_counts_cases_not_aggregate_correct_delta(self):
        cases = [
            case(label="top", current=None),
            case(label="top", current="second"),
        ]

        result = evaluate_strategy(cases, lambda item: "top")

        self.assertEqual(result.ambiguity_resolution_rate, 1.0)

    def test_stable_id_dedup_only_resolves_identical_nonempty_ids(self):
        duplicate = case(
            label="indistinguishable",
            top=candidate("same"),
            second=candidate("same"),
        )
        missing_ids = case(
            label="indistinguishable",
            top=candidate(""),
            second=candidate(""),
        )

        self.assertEqual(select_stable_id_duplicate(duplicate), "top")
        self.assertIsNone(select_stable_id_duplicate(missing_ids))

    def test_exact_identity_dedup_requires_same_nonempty_candidate_id(self):
        exact = case(
            label="indistinguishable",
            top=candidate("same"),
            second=candidate("same"),
        )
        different_ids = case(label="indistinguishable")
        normalized_only = case(
            label="indistinguishable",
            top=candidate("a", title="Song!"),
            second=candidate("b", title="song"),
        )
        duration_differs = case(
            label="indistinguishable",
            top=candidate("a", duration=200.0),
            second=candidate("b", duration=200.1),
        )

        self.assertEqual(select_exact_identity_duplicate(exact), "top")
        self.assertIsNone(select_exact_identity_duplicate(different_ids))
        self.assertIsNone(select_exact_identity_duplicate(normalized_only))
        self.assertIsNone(select_exact_identity_duplicate(duration_differs))

    def test_version_conflict_guard_prefers_source_aligned_candidate(self):
        studio = case(
            label="top",
            top=candidate("studio", title="Song"),
            second=candidate("live", title="Song (Live)"),
        )

        self.assertEqual(rank_with_identity_signals(studio), "top")

    def test_album_and_isrc_are_used_only_when_present_on_both_sides(self):
        no_candidate_metadata = case(
            label="top",
            top=candidate("top"),
            second=candidate("second"),
            source_album="Album",
            source_isrc="US-AAA-01",
        )
        exact_isrc = case(
            label="top",
            top=candidate("top", isrc="US-AAA-01"),
            second=candidate("second", isrc="US-BBB-02"),
            source_isrc="US-AAA-01",
        )

        self.assertIsNone(rank_with_identity_signals(no_candidate_metadata))
        self.assertEqual(rank_with_identity_signals(exact_isrc), "top")

    def test_one_sided_isrc_or_album_evidence_does_not_select(self):
        one_isrc = case(
            label="top",
            top=candidate("top", isrc="US-AAA-01"),
            second=candidate("second"),
            source_isrc="US-AAA-01",
        )
        one_album = case(
            label="top",
            top=candidate("top", album="Album"),
            second=candidate("second"),
            source_album="Album",
        )

        self.assertIsNone(rank_with_identity_signals(one_isrc))
        self.assertIsNone(rank_with_identity_signals(one_album))

    def test_container_and_credit_markers_do_not_select(self):
        for marker in ("Deluxe", "Anniversary", "OST", "feat. Guest", "with Guest"):
            item = case(
                label="top",
                source_album=marker,
                top=candidate("top", album=marker),
                second=candidate("second", album="Other"),
            )
            with self.subTest(marker=marker):
                self.assertIsNone(rank_with_identity_signals(item))


if __name__ == "__main__":
    unittest.main()
