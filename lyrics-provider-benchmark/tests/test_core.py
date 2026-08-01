import asyncio
import json
import sqlite3
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from benchmark.analysis import analyze_matching_issue, refresh_failed_tracks
from benchmark.db import connect, init_db, insert_result
from benchmark.dataset import sample_tracks
from benchmark.dataset import load_tracks
from benchmark.matcher import Candidate, Track, best_match_index, match_decision, score
from benchmark.offline_simulator import RankingCase, Signals, evaluate_cases, load_cases_from_csv, load_cases_from_sqlite
from benchmark.providers import HTTPResponse, KugouProvider, LRCLIBProvider, NetEaseProvider, _matching_failed
from benchmark.report import build_summary, write_reports
from benchmark.runner import ProviderResult, run_track


class MatcherTests(unittest.TestCase):
    def test_accepts_exact_title_artist_and_close_duration(self):
        track = Track("t1", "七里香", "周杰伦", "七里香", 299)
        candidate = Candidate("七里香", ["周杰伦"], 299_000)

        self.assertGreaterEqual(score(track, candidate), 82)
        self.assertEqual(best_match_index(track, [candidate]), 0)

    def test_rejects_version_mismatch(self):
        track = Track("t1", "Song - Live", "Artist", "", 200)
        candidate = Candidate("Song", ["Artist"], 200_000)

        self.assertEqual(score(track, candidate), 0)
        self.assertIsNone(best_match_index(track, [candidate]))

    def test_rejects_ambiguous_candidates(self):
        track = Track("t1", "Song", "Artist", "", 200)
        candidates = [
            Candidate("Song", ["Artist"], 200_000),
            Candidate("Song", ["Artist"], 201_000),
        ]

        self.assertIsNone(best_match_index(track, candidates))

    def test_accepts_feat_and_ost_title_noise(self):
        track = Track("t1", "像晴天像雨天(电视剧《难哄》心动曲)", "Silence Wang", "难哄", 237)
        candidate = Candidate("像晴天像雨天", ["汪苏泷"], 237_000)

        self.assertGreaterEqual(score(track, candidate), 82)
        self.assertEqual(best_match_index(track, [candidate]), 0)

    def test_accepts_artist_order_and_separator_differences(self):
        track = Track("t1", "STAY", "The Kid LAROI & Justin Bieber", "", 142)
        candidate = Candidate("STAY", ["Justin Bieber", "The Kid LAROI"], 142_000)

        self.assertGreaterEqual(score(track, candidate), 82)

    def test_accepts_main_artist_when_title_and_duration_are_exact(self):
        track = Track("t1", "One Kiss", "Calvin Harris, Dua Lipa", "", 212)
        candidate = Candidate("One Kiss", ["Calvin Harris"], 212_000)

        self.assertEqual(best_match_index(track, [candidate]), 0)

    def test_rejects_similar_but_wrong_song(self):
        track = Track("t1", "Love Story", "Taylor Swift", "", 235)
        candidate = Candidate("Love Song", ["Taylor Swift"], 235_000)

        self.assertLess(score(track, candidate), 82)
        self.assertIsNone(best_match_index(track, [candidate]))

    def test_saves_below_threshold_rejected_candidate_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = connect(Path(tmp) / "bench.sqlite3")
            init_db(db)
            track = Track("t1", "Love Story", "Taylor Swift", "", 235)
            candidate = Candidate("Love Song", ["Taylor Swift"], 235_000)

            result = _matching_failed("Unit", time.monotonic(), match_decision(track, [candidate]))
            db.execute("insert into benchmark_runs(id, started_at, dataset_name, status) values(1, 'now', 'unit', 'finished')")
            db.execute("insert into songs(id, spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(1, 't1', 'Love Story', 'Taylor Swift', '', 235, '', 'unit')")
            insert_result(db, 1, 1, result)
            row = db.execute("select * from provider_results").fetchone()

        self.assertEqual(row["failure_reason"], "matching_failed")
        self.assertEqual(row["reject_reason"], "below_threshold")
        self.assertEqual(row["matched_title"], "Love Song")
        self.assertEqual(row["top_score"], row["match_score"])

    def test_saves_ambiguous_rejected_candidate_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = connect(Path(tmp) / "bench.sqlite3")
            init_db(db)
            track = Track("t1", "Song", "Artist", "", 200)
            candidates = [
                Candidate("Song", ["Artist"], 200_000),
                Candidate("Song", ["Artist"], 201_000),
            ]

            result = _matching_failed("Unit", time.monotonic(), match_decision(track, candidates))
            db.execute("insert into benchmark_runs(id, started_at, dataset_name, status) values(1, 'now', 'unit', 'finished')")
            db.execute("insert into songs(id, spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(1, 't1', 'Song', 'Artist', '', 200, '', 'unit')")
            insert_result(db, 1, 1, result)
            row = db.execute("select * from provider_results").fetchone()

        self.assertEqual(row["failure_reason"], "matching_failed")
        self.assertEqual(row["reject_reason"], "ambiguous_gap")
        self.assertEqual(row["matched_title"], "Song")
        self.assertIsNotNone(row["top_score"])
        self.assertIsNotNone(row["second_score"])
        self.assertEqual(row["second_matched_title"], "Song")
        self.assertEqual(row["second_matched_artist"], "Artist")
        self.assertEqual(row["second_matched_duration_seconds"], 201)


class RunnerTests(unittest.IsolatedAsyncioTestCase):
    async def test_runs_every_provider_for_a_track(self):
        calls = []

        async def provider(name, ok):
            calls.append(name)
            return ProviderResult(
                provider=name,
                status="success" if ok else "failed",
                lyrics_available=ok,
                failure_reason=None if ok else "no_lyrics_found",
                line_count=2 if ok else 0,
                latency_ms=1,
            )

        track = Track("t1", "Song", "Artist", "", 200)
        results = await run_track(
            track,
            [
                ("first", lambda t: provider("first", True)),
                ("second", lambda t: provider("second", True)),
                ("third", lambda t: provider("third", False)),
            ],
        )

        self.assertEqual(calls, ["first", "second", "third"])
        self.assertEqual([r.provider for r in results], ["first", "second", "third"])


class ProviderRecoveryTests(unittest.TestCase):
    def test_lrclib_ignores_rows_without_duration(self):
        payload = [
            {
                "trackName": "Song",
                "artistName": "Artist",
                "duration": None,
                "syncedLyrics": "[00:01.00]Incomplete",
            },
            {
                "trackName": "Song",
                "artistName": "Artist",
                "duration": 200,
                "syncedLyrics": "[00:01.00]Complete",
            },
            {
                "trackName": "song",
                "artistName": "ARTIST",
                "duration": 199,
                "syncedLyrics": "[00:01.00]Duplicate",
            },
        ]
        track = Track("t1", "Song", "Artist", "", 200)
        with patch("benchmark.providers._request", return_value=HTTPResponse(200, json.dumps(payload).encode())):
            result = LRCLIBProvider().fetch(track, time.monotonic())

        self.assertTrue(result.lyrics_available)
        self.assertEqual(result.line_count, 1)

    def test_netease_uses_plain_search_endpoint(self):
        responses = [
            HTTPResponse(
                200,
                json.dumps(
                    {
                        "result": {
                            "songs": [
                                {
                                    "id": 1,
                                    "name": "Song",
                                    "artists": [{"name": "Artist"}],
                                    "duration": 200_000,
                                },
                                {
                                    "id": 2,
                                    "name": "song",
                                    "artists": [{"name": "ARTIST"}],
                                    "duration": 200_000,
                                }
                            ]
                        }
                    }
                ).encode(),
            ),
            HTTPResponse(200, json.dumps({"lrc": {"lyric": "[00:01.00]Line"}}).encode()),
        ]
        urls = []

        def request(url, *args, **kwargs):
            urls.append(url)
            return responses.pop(0)

        with patch("benchmark.providers._request", side_effect=request):
            result = NetEaseProvider().fetch(Track("t1", "Song", "Artist", "", 200), time.monotonic())

        self.assertTrue(result.lyrics_available)
        self.assertEqual(urls[0], "https://music.163.com/api/search/get")

    def test_kugou_song_search_deduplicates_equivalent_rows(self):
        payload = {
            "data": {
                "info": [
                    {"hash": "first", "songname": "Song", "singername": "Artist", "duration": 200},
                    {"hash": "second", "songname": "song", "singername": "ARTIST", "duration": 200},
                ]
            }
        }
        with patch("benchmark.providers._request", return_value=HTTPResponse(200, json.dumps(payload).encode())):
            song, _, _, reject = KugouProvider()._song(Track("t1", "Song", "Artist", "", 200))

        self.assertIsNotNone(song)
        self.assertIsNone(reject)


class ReportTests(unittest.TestCase):
    def test_summary_counts_coverage_and_unique_provider_contribution(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = connect(Path(tmp) / "bench.sqlite3")
            init_db(db)
            db.executemany(
                "insert into songs(id, spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(?,?,?,?,?,?,?,?)",
                [
                    (1, "a", "A", "Artist", "", 100, "pop", "unit"),
                    (2, "b", "B", "Artist", "", 100, "pop", "unit"),
                    (3, "c", "C", "Artist", "", 100, "pop", "unit"),
                ],
            )
            db.execute("insert into benchmark_runs(id, started_at, dataset_name, status) values(1, 'now', 'unit', 'finished')")
            db.executemany(
                "insert into provider_results(run_id, song_id, provider, status, lyrics_available, line_count, latency_ms, failure_reason) values(?,?,?,?,?,?,?,?)",
                [
                    (1, 1, "A", "success", 1, 10, 20, None),
                    (1, 1, "B", "success", 1, 10, 30, None),
                    (1, 2, "A", "failed", 0, 0, 10, "no_lyrics_found"),
                    (1, 2, "B", "success", 1, 9, 40, None),
                    (1, 3, "A", "failed", 0, 0, 11, "matching_failed"),
                    (1, 3, "B", "failed", 0, 0, 12, "api_unavailable"),
                ],
            )
            db.commit()

            summary = build_summary(db, 1)

        self.assertEqual(summary["total_songs"], 3)
        self.assertEqual(summary["successful_songs"], 2)
        self.assertEqual(summary["coverage_rate"], 66.67)
        self.assertEqual(summary["providers"]["B"]["success"], 2)
        self.assertEqual(summary["providers"]["B"]["unique_success"], 1)
        self.assertEqual(summary["failure_reasons"]["api_unavailable"], 1)

    def test_reports_keep_history_trend_and_missing_songs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db = connect(root / "bench.sqlite3")
            init_db(db)
            db.executemany(
                "insert into songs(id, spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(?,?,?,?,?,?,?,?)",
                [
                    (1, "a", "A", "Artist", "", 100, "english_pop", "unit"),
                    (2, "b", "B", "Artist", "", 100, "japanese", "unit"),
                ],
            )
            db.executemany(
                "insert into benchmark_runs(id, started_at, finished_at, dataset_name, status) values(?,?,?,?,?)",
                [
                    (1, "2026-07-10T00:00:00+00:00", "2026-07-10T00:05:00+00:00", "unit", "finished"),
                    (2, "2026-07-16T00:00:00+00:00", "2026-07-16T00:05:00+00:00", "unit", "finished"),
                ],
            )
            db.executemany(
                "insert into provider_results(run_id, song_id, provider, status, lyrics_available, line_count, latency_ms, failure_reason) values(?,?,?,?,?,?,?,?)",
                [
                    (1, 1, "A", "success", 1, 10, 20, None),
                    (1, 2, "A", "failed", 0, 0, 20, "no_lyrics_found"),
                    (2, 1, "A", "success", 1, 10, 20, None),
                    (2, 1, "B", "success", 1, 10, 20, None),
                    (2, 2, "A", "failed", 0, 0, 20, "no_lyrics_found"),
                    (2, 2, "B", "failed", 0, 0, 20, "matching_failed"),
                ],
            )
            db.commit()

            summary = build_summary(db, 2)
            write_reports(summary, root / "reports")

            latest = (root / "reports" / "latest.md").read_text(encoding="utf-8")
            history = list((root / "reports" / "history").glob("run-2-*.md"))

        self.assertEqual(summary["seven_day_average_coverage_rate"], 50.0)
        self.assertEqual(summary["provider_ranking"][0]["provider"], "A")
        self.assertEqual(summary["failed_songs_detail"][0]["title"], "B")
        self.assertIn("Trend", latest)
        self.assertEqual(len(history), 1)

    def test_matcher_evidence_counts_only_matching_failed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            db = connect(root / "bench.sqlite3")
            init_db(db)
            db.execute(
                "insert into songs(id, spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(1, 'a', 'A', 'Artist', '', 100, 'pop', 'unit')"
            )
            db.execute("insert into benchmark_runs(id, started_at, dataset_name, status) values(1, 'now', 'unit', 'finished')")
            db.executemany(
                """
                insert into provider_results(
                  run_id, song_id, provider, status, lyrics_available, line_count, latency_ms,
                  failure_reason, matched_title, top_score, second_score, reject_reason
                ) values(?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                [
                    (1, 1, "A", "failed", 0, 0, 10, "matching_failed", "Candidate A", 70, None, "below_threshold"),
                    (1, 1, "A", "failed", 0, 0, 10, "matching_failed", None, None, None, "no_candidates"),
                    (1, 1, "B", "failed", 0, 0, 10, "matching_failed", "Candidate B", 90, 88, "ambiguous_gap"),
                    (1, 1, "B", "failed", 0, 0, 10, "api_unavailable", "Ignored", 99, None, "below_threshold"),
                    (1, 1, "B", "failed", 0, 0, 10, "no_lyrics_found", "Ignored", 99, None, "below_threshold"),
                ],
            )
            db.commit()

            summary = build_summary(db, 1)
            write_reports(summary, root / "reports")
            latest = (root / "reports" / "latest.md").read_text(encoding="utf-8")
            latest_json = json.loads((root / "reports" / "latest.json").read_text(encoding="utf-8"))

        evidence = latest_json["matcher_evidence"]
        self.assertEqual(evidence["total_matching_failed"], 3)
        self.assertEqual(evidence["candidate_backed"], 2)
        self.assertEqual(evidence["no_candidates"], 1)
        self.assertEqual(evidence["below_threshold"], 1)
        self.assertEqual(evidence["ambiguous_gap"], 1)
        self.assertEqual(evidence["providers"]["A"]["total_matching_failed"], 2)
        self.assertEqual(evidence["providers"]["B"]["total_matching_failed"], 1)
        self.assertIn("Matcher Evidence", latest)
        self.assertIn("| Overall | 3 | 2 | 1 | 1 | 1 | 66.67% |", latest)


class OfflineRankingSimulatorTests(unittest.TestCase):
    def test_supports_artist_album_and_live_title_signals(self):
        base = dict(
            source_duration_seconds=200,
            top_duration_seconds=200,
            second_duration_seconds=200,
            old_decision="ambiguous_gap",
            label="second",
        )
        cases = [
            (
                RankingCase(
                    case_id="artist",
                    source_title="Song",
                    source_artist="Artist",
                    top_title="Song",
                    top_artist="Guest",
                    second_title="Song",
                    second_artist="Artist",
                    **base,
                ),
                Signals(complete_artist_exact=True),
            ),
            (
                RankingCase(
                    case_id="album",
                    source_title="Song",
                    source_artist="Artist",
                    source_album="Studio",
                    top_title="Song",
                    top_artist="Artist",
                    top_album="Live",
                    second_title="Song",
                    second_artist="Artist",
                    second_album="Studio",
                    **base,
                ),
                Signals(album_version_metadata=True),
            ),
            (
                RankingCase(
                    case_id="live",
                    source_title="Song",
                    source_artist="Artist",
                    top_title="Song Live",
                    top_artist="Artist",
                    second_title="Song",
                    second_artist="Artist",
                    **base,
                ),
                Signals(title_live=True),
            ),
        ]

        for case, signals in cases:
            with self.subTest(case=case.case_id):
                result = evaluate_cases([case], signals)
                self.assertEqual(result.experimental.correct_candidate_rate, 1.0)
                self.assertEqual(result.experimental.false_positive_rate, 0.0)

    def test_title_marker_signal_requires_a_marker(self):
        case = RankingCase(
            case_id="no-marker",
            source_title="Song",
            source_artist="Artist",
            source_duration_seconds=200,
            top_title="Song",
            top_artist="Artist",
            top_duration_seconds=200,
            second_title="Song Extended",
            second_artist="Artist",
            second_duration_seconds=200,
            old_decision="ambiguous_gap",
            label="top",
        )

        result = evaluate_cases([case], Signals(title_feat=True))

        self.assertEqual(result.experimental.correct_candidate_rate, 0.0)
        self.assertEqual(result.experimental.false_positive_rate, 0.0)
        self.assertEqual(result.experimental.unresolved, 1)

    def test_title_marker_signal_recognizes_remastered_and_featuring(self):
        cases = [
            RankingCase(
                case_id="remastered",
                source_title="Song Remastered",
                source_artist="Artist",
                source_duration_seconds=200,
                top_title="Song Remastered Live",
                top_artist="Artist",
                top_duration_seconds=200,
                second_title="Song",
                second_artist="Artist",
                second_duration_seconds=200,
                old_decision="ambiguous_gap",
                label="second",
            ),
            RankingCase(
                case_id="featuring",
                source_title="Song featuring Guest",
                source_artist="Artist",
                source_duration_seconds=200,
                top_title="Song Live",
                top_artist="Artist",
                top_duration_seconds=200,
                second_title="Song",
                second_artist="Artist",
                second_duration_seconds=200,
                old_decision="ambiguous_gap",
                label="second",
            ),
        ]

        for case, signals in (
            (cases[0], Signals(title_remastered=True)),
            (cases[1], Signals(title_feat=True)),
        ):
            with self.subTest(case=case.case_id):
                result = evaluate_cases([case], signals)
                self.assertEqual(result.experimental.correct_candidate_rate, 1.0)
                self.assertEqual(result.experimental.false_positive_rate, 0.0)

    def test_keeps_rows_without_second_identity_or_ground_truth_unresolved(self):
        cases = [
            RankingCase(
                case_id="missing-second",
                source_title="Song",
                source_artist="Artist",
                source_duration_seconds=200,
                top_title="Song",
                top_artist="Artist",
                top_duration_seconds=200,
                second_score=90,
                old_decision="ambiguous_gap",
                label="top",
            ),
            RankingCase(
                case_id="uncertain-label",
                source_title="Song",
                source_artist="Artist",
                source_duration_seconds=200,
                top_title="Song",
                top_artist="Artist",
                top_duration_seconds=200,
                second_title="Song",
                second_artist="Artist",
                second_duration_seconds=201,
                second_score=90,
                old_decision="ambiguous_gap",
                label="uncertain",
            ),
        ]

        result = evaluate_cases(cases, Signals(duration_difference=True))

        self.assertEqual(result.eligibility["eligible"], 0)
        self.assertEqual(result.eligibility["missing_evidence"], 1)
        self.assertEqual(result.ambiguous_unresolved, 1)

    def test_reports_correct_and_false_positive_rates_from_manual_labels(self):
        cases = [
            RankingCase(
                case_id="correct-top",
                source_title="Song",
                source_artist="Artist",
                source_duration_seconds=200,
                top_title="Song",
                top_artist="Artist",
                top_duration_seconds=200,
                second_title="Song",
                second_artist="Artist",
                second_duration_seconds=201,
                second_score=90,
                old_decision="ambiguous_gap",
                label="top",
            ),
            RankingCase(
                case_id="wrong-top",
                source_title="Other",
                source_artist="Artist",
                source_duration_seconds=200,
                top_title="Other",
                top_artist="Artist",
                top_duration_seconds=200,
                second_title="Other",
                second_artist="Artist",
                second_duration_seconds=201,
                second_score=90,
                old_decision="ambiguous_gap",
                label="neither",
            ),
        ]

        result = evaluate_cases(cases, Signals(duration_difference=True))

        self.assertEqual(result.experimental.correct_candidate_rate, 0.5)
        self.assertEqual(result.experimental.false_positive_rate, 0.5)
        self.assertEqual(result.old.correct_candidate_rate, 0.0)
        self.assertEqual(result.old.false_positive_rate, 0.0)

    def test_loads_cases_from_csv_and_sqlite_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            csv_path = root / "cases.csv"
            csv_path.write_text(
                "case_id,source_title,source_artist,source_duration_seconds,matched_title,matched_artist,matched_duration_seconds,second_matched_title,second_matched_artist,second_matched_duration_seconds,reject_reason,manual_label\n"
                "c1,Song,Artist,200,Song,Artist,200,Song,Artist,201,ambiguous_gap,top\n",
                encoding="utf-8",
            )
            db = connect(root / "bench.sqlite3")
            init_db(db)
            db.execute("insert into benchmark_runs(id, started_at, dataset_name, status) values(1, 'now', 'unit', 'finished')")
            db.execute("insert into songs(id, spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(1, 's1', 'Song', 'Artist', '', 200, '', 'unit')")
            db.execute(
                """
                insert into provider_results(
                  run_id, song_id, provider, status, lyrics_available, line_count, latency_ms,
                  failure_reason, matched_title, matched_artist, matched_duration_seconds,
                  second_score, reject_reason, second_matched_title, second_matched_artist, second_matched_duration_seconds
                ) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (1, 1, "Unit", "failed", 0, 0, 1, "matching_failed", "Song", "Artist", 200, 90, "ambiguous_gap", "Song", "Artist", 201),
            )
            db.commit()

            csv_cases = load_cases_from_csv(csv_path)
            sqlite_cases = load_cases_from_sqlite(db, 1)

        self.assertEqual(csv_cases[0].label, "top")
        self.assertEqual(sqlite_cases[0].second_title, "Song")

    def test_failed_tracks_records_attempted_providers_and_analysis(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = connect(Path(tmp) / "bench.sqlite3")
            init_db(db)
            db.execute(
                "insert into songs(id, spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(?,?,?,?,?,?,?,?)",
                (1, "s1", "Flowers - Demo Version", "Miley Cyrus feat. Artist", "Album", 200, "english_pop", "unit"),
            )
            db.execute("insert into benchmark_runs(id, started_at, dataset_name, status) values(1, 'now', 'unit', 'finished')")
            db.executemany(
                "insert into provider_results(run_id, song_id, provider, status, lyrics_available, line_count, latency_ms, failure_reason, raw_error) values(?,?,?,?,?,?,?,?,?)",
                [
                    (1, 1, "LRCMux", "failed", 0, 0, 10, "matching_failed", "candidate title Flowers"),
                    (1, 1, "QQ", "failed", 0, 0, 10, "api_unavailable", "HTTP 502"),
                ],
            )
            db.commit()

            refresh_failed_tracks(db, 1)
            row = db.execute("select * from failed_tracks").fetchone()
            summary = build_summary(db, 1)
            write_reports(summary, Path(tmp) / "reports")

            optimization = (Path(tmp) / "reports" / "optimization_report.md").read_text(encoding="utf-8")
            strategy = (Path(tmp) / "reports" / "provider_strategy.md").read_text(encoding="utf-8")
            matrix = (Path(tmp) / "reports" / "provider_language_matrix.md").read_text(encoding="utf-8")
            simulation = (Path(tmp) / "reports" / "matching_simulation.md").read_text(encoding="utf-8")
            retry = (Path(tmp) / "reports" / "retry_analysis.md").read_text(encoding="utf-8")
            recommendation = (Path(tmp) / "reports" / "recommendation.md").read_text(encoding="utf-8")
            simulation_v2 = (Path(tmp) / "reports" / "optimization_simulation_v2.md").read_text(encoding="utf-8")
            matching_spec = (Path(tmp) / "reports" / "matching_optimization_spec.md").read_text(encoding="utf-8")
            history_csv = (Path(tmp) / "reports" / "history" / "coverage_history.csv").read_text(encoding="utf-8")
            run_history_exists = (Path(tmp) / "reports" / "history" / "run-1.md").exists()

        self.assertEqual(row["primary_failure_reason"], "version_mismatch")
        self.assertEqual(row["language"], "English")
        self.assertIn("LRCMux", row["attempted_providers"])
        self.assertIn("remove_version_suffix", row["possible_fix"])
        self.assertIn("Version suffix mismatch", optimization)
        self.assertIn("English", strategy)
        self.assertIn("| Language | Best Provider | Coverage |", matrix)
        self.assertIn("Title Normalization", simulation)
        self.assertIn("Retry once", retry)
        self.assertIn("Current Coverage", recommendation)
        self.assertIn("Optimization Simulation v2", simulation_v2)
        self.assertIn("Combined", simulation_v2)
        self.assertIn("Matching Optimization Specification", matching_spec)
        self.assertIn("Swift Implementation Notes", matching_spec)
        self.assertIn("Confidence Scoring", matching_spec)
        self.assertIn("date,coverage,success,failed,top_provider", history_csv)
        self.assertTrue(run_history_exists)

    def test_matching_issue_suggests_title_and_artist_fixes(self):
        issue = analyze_matching_issue("Flowers - Demo Version", "Artist feat. Guest", "Album")

        self.assertIn("remove_version_suffix", issue["possible_fixes"])
        self.assertIn("normalize_feature_artist", issue["possible_fixes"])


class DatasetTests(unittest.TestCase):
    def test_loads_optional_category_column(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "tracks.tsv"
            path.write_text("track_id\ttitle\tartist\talbum\tduration_seconds\tcategory\n1\tSong\tArtist\tAlbum\t123\tjapanese\n", encoding="utf-8")

            tracks = load_tracks(path)

        self.assertEqual(tracks[0].category, "japanese")

    def test_samples_tracks_with_seed_without_repeating(self):
        tracks = [Track(str(i), f"Song {i}", "Artist", "", 100) for i in range(20)]

        first = sample_tracks(tracks, 5, seed="2026-07-16")
        second = sample_tracks(tracks, 5, seed="2026-07-16")

        self.assertEqual(first, second)
        self.assertEqual(len(first), 5)
        self.assertEqual(len({track.track_id for track in first}), 5)


if __name__ == "__main__":
    asyncio.run(unittest.main())
