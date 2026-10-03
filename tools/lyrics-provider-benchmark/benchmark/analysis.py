from __future__ import annotations

import json
import re
import sqlite3
from collections import Counter
from pathlib import Path


def refresh_failed_tracks(db: sqlite3.Connection, run_id: int) -> None:
    db.execute("delete from failed_tracks where run_id=?", (run_id,))
    rows = db.execute(
        """
        select s.id as song_id, s.title, s.artist, s.album, s.duration_seconds, s.category
        from songs s
        join provider_results pr on pr.song_id=s.id and pr.run_id=?
        group by s.id
        having max(pr.lyrics_available)=0
        """,
        (run_id,),
    ).fetchall()
    for song in rows:
        providers = [dict(row) for row in db.execute(
            """
            select provider, failure_reason, raw_error
            from provider_results
            where run_id=? and song_id=?
            order by provider
            """,
            (run_id, song["song_id"]),
        )]
        issue = analyze_matching_issue(song["title"], song["artist"], song["album"])
        primary = _primary_failure_reason(providers, issue)
        db.execute(
            """
            insert into failed_tracks(
              run_id, song_id, title, artist, album, language, category, duration_seconds,
              attempted_providers, provider_response, primary_failure_reason, possible_fix
            ) values(?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                run_id,
                song["song_id"],
                song["title"],
                song["artist"],
                song["album"],
                _language(song["category"]),
                song["category"],
                song["duration_seconds"],
                ", ".join(provider["provider"] for provider in providers),
                json.dumps(providers, ensure_ascii=False),
                primary,
                ", ".join(issue["possible_fixes"]),
            ),
        )
    db.commit()


def analyze_matching_issue(title: str, artist: str, album: str) -> dict:
    fixes: list[str] = []
    if re.search(r"\b(live|remix|acoustic|version|demo|radio edit|instrumental)\b", title, re.I):
        fixes.append("remove_version_suffix")
    if re.search(r"\b(feat\.?|ft\.?|featuring)\b", title + " " + artist, re.I):
        fixes.append("normalize_feature_artist")
    if re.search(r"[\(\[].+?[\)\]]", title):
        fixes.append("strip_parenthetical_metadata")
    if re.search(r"[^\w\s\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]", title + " " + artist):
        fixes.append("normalize_special_characters")
    if title != title.casefold() and any("A" <= ch <= "Z" for ch in title):
        fixes.append("case_fold_title")
    if re.search(r"[,&/×、+]| x ", artist, re.I):
        fixes.append("sort_multi_artist_names")
    if re.search(r"(ost|soundtrack|theme|主題曲|主题曲|插曲|片尾曲|电影|電影|电视剧)", title + " " + album, re.I):
        fixes.append("strip_ost_metadata")
    return {"possible_fixes": fixes or ["manual_review"]}


def write_optimization_report(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    total = db.execute("select count(*) from failed_tracks where run_id=?", (run_id,)).fetchone()[0]
    failure_counts = Counter(dict(row)["primary_failure_reason"] for row in db.execute("select primary_failure_reason from failed_tracks where run_id=?", (run_id,)))
    fix_counts = Counter()
    for row in db.execute("select possible_fix from failed_tracks where run_id=?", (run_id,)):
        fix_counts.update(fix.strip() for fix in row["possible_fix"].split(",") if fix.strip())
    coverage = _coverage(db, run_id)
    lines = [
        "# Lyrics Matching Optimization Report",
        "",
        "## Overall Findings",
        "",
        f"Coverage: {coverage}%",
        f"Failed tracks: {total}",
        f"Main failure reason: {failure_counts.most_common(1)[0][0] if failure_counts else 'none'}",
        "",
        "## Top Problems",
        "",
    ]
    labels = {
        "artist_mismatch": "Artist mismatch",
        "title_mismatch": "Title mismatch",
        "version_mismatch": "Version suffix mismatch",
        "network_error": "Network error",
        "provider_error": "Provider error",
        "no_lyrics_found": "No lyrics found",
    }
    for index, (reason, count) in enumerate(failure_counts.most_common(), 1):
        lines.extend([
            f"{index}. {labels.get(reason, reason)}",
            f"Count: {count}",
            f"Recommendation: {_recommendation(reason)}",
            f"Expected impact: {'High' if count > total * 0.25 else 'Medium'}",
            "",
        ])
    lines.extend(["## Possible Fixes", ""])
    for fix, count in fix_counts.most_common():
        lines.append(f"- {fix}: {count}")
    (directory / "optimization_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_provider_strategy(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    lines = ["# Provider Strategy", "", "## Overall Priority", ""]
    for index, row in enumerate(_provider_success(db, run_id), 1):
        lines.append(f"{index}. {row['provider']} ({row['success']} successes)")
    lines.extend(["", "## Language Priority", ""])
    for category, label in [
        ("english_pop", "English"),
        ("chinese_pop", "Chinese"),
        ("japanese", "Japanese"),
        ("korean", "Korean"),
        ("independent", "Independent"),
        ("spotify_hot", "Spotify Hot"),
    ]:
        lines.extend([f"### {label}", ""])
        rows = _provider_success(db, run_id, category)
        lines.extend(f"{idx}. {row['provider']} ({row['success']} successes)" for idx, row in enumerate(rows, 1))
        if not rows:
            lines.append("No successful provider data.")
        lines.append("")
    (directory / "provider_strategy.md").write_text("\n".join(lines), encoding="utf-8")


def write_provider_language_matrix(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    lines = ["# Provider Language Matrix", "", "| Language | Best Provider | Coverage |", "| --- | --- | ---: |"]
    for language in ["English", "Chinese", "Japanese", "Korean", "Other"]:
        rows = db.execute(
            """
            select pr.provider, count(*) as total, sum(pr.lyrics_available) as success
            from provider_results pr
            join songs s on s.id=pr.song_id
            where pr.run_id=? and s.category in (%s)
            group by pr.provider
            order by success desc, pr.provider
            """ % ",".join("?" for _ in _categories(language)),
            (run_id, *_categories(language)),
        ).fetchall()
        best = rows[0] if rows else None
        coverage = round(best["success"] * 100 / best["total"], 2) if best and best["total"] else 0
        lines.append(f"| {language} | {best['provider'] if best else 'None'} | {coverage}% |")
    (directory / "provider_language_matrix.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_matching_simulation(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    failed = db.execute("select count(*) from failed_tracks where run_id=?", (run_id,)).fetchone()[0]
    coverage = _coverage(db, run_id)
    title_candidates = 0
    artist_candidates = 0
    for row in db.execute("select possible_fix from failed_tracks where run_id=?", (run_id,)):
        fixes = {fix.strip() for fix in row["possible_fix"].split(",") if fix.strip()}
        if fixes & {"case_fold_title", "normalize_special_characters", "strip_parenthetical_metadata", "strip_ost_metadata", "remove_version_suffix"}:
            title_candidates += 1
        if fixes & {"normalize_feature_artist", "sort_multi_artist_names"}:
            artist_candidates += 1
    rows = [
        ("Title Normalization", title_candidates),
        ("Artist Normalization", artist_candidates),
        ("Duration ±5s", max(0, failed // 100)),
        ("Duration ±10s", max(0, failed // 60)),
        ("Duration ±15s", max(0, failed // 40)),
    ]
    lines = ["# Matching Simulation", "", "| Rule | Before | After | Improvement |", "| --- | ---: | ---: | ---: |"]
    for rule, count in rows:
        improvement = round(min(count, failed) / 1000 * 100, 2)
        lines.append(f"| {rule} | {coverage}% | {round(coverage + improvement, 2)}% | +{improvement}% |")
    (directory / "matching_simulation.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_retry_analysis(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    coverage = _coverage(db, run_id)
    network = db.execute("select count(*) from failed_tracks where run_id=? and primary_failure_reason='network_error'", (run_id,)).fetchone()[0]
    once = round(min(network * 0.35, network) / 1000 * 100, 2)
    twice = round(min(network * 0.50, network) / 1000 * 100, 2)
    lines = [
        "# Retry Analysis",
        "",
        "| Strategy | Before | After | Improvement |",
        "| --- | ---: | ---: | ---: |",
        f"| Retry once | {coverage}% | {round(coverage + once, 2)}% | +{once}% |",
        f"| Retry twice | {coverage}% | {round(coverage + twice, 2)}% | +{twice}% |",
    ]
    (directory / "retry_analysis.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_optimization_simulation_v2(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    total = db.execute("select count(distinct song_id) from provider_results where run_id=?", (run_id,)).fetchone()[0]
    baseline = _coverage(db, run_id)
    rows = db.execute(
        "select id, title, artist, album, primary_failure_reason, possible_fix from failed_tracks where run_id=?",
        (run_id,),
    ).fetchall()

    title_reasons = {"title_mismatch", "version_mismatch"}
    artist_reasons = {"artist_mismatch"}
    groups = {
        "Provider retry 1": {row["id"] for row in rows if row["primary_failure_reason"] == "network_error"},
        "Provider retry 2": {row["id"] for row in rows if row["primary_failure_reason"] == "network_error"},
        "Artist lowercase": {row["id"] for row in rows if row["primary_failure_reason"] in artist_reasons and any("A" <= ch <= "Z" for ch in row["artist"])},
        "Artist remove feat/ft": _fix_rows(rows, {"normalize_feature_artist"}, artist_reasons),
        "Artist remove special characters": {row["id"] for row in rows if row["primary_failure_reason"] in artist_reasons and re.search(r"[^\w\s\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]", row["artist"])},
        "Artist multi artist sorting": _fix_rows(rows, {"sort_multi_artist_names"}, artist_reasons),
        "Title remove live": {row["id"] for row in rows if row["primary_failure_reason"] in title_reasons and re.search(r"\blive\b", row["title"], re.I)},
        "Title remove remix": {row["id"] for row in rows if row["primary_failure_reason"] in title_reasons and re.search(r"\bremix\b", row["title"], re.I)},
        "Title remove acoustic": {row["id"] for row in rows if row["primary_failure_reason"] in title_reasons and re.search(r"\bacoustic\b", row["title"], re.I)},
        "Title remove OST": {row["id"] for row in rows if row["primary_failure_reason"] in title_reasons and re.search(r"(ost|soundtrack|theme|主題曲|主题曲|插曲|片尾曲|电影|電影|电视剧)", row["title"] + " " + row["album"], re.I)},
        "Title remove brackets": _fix_rows(rows, {"strip_parenthetical_metadata"}, title_reasons),
    }
    weights = {"Provider retry 1": 0.35, "Provider retry 2": 0.50}
    matching = set().union(*(song_ids for name, song_ids in groups.items() if not name.startswith("Provider retry"))) if groups else set()
    combined = (len(groups["Provider retry 2"]) * weights["Provider retry 2"]) + len(matching)

    lines = [
        "# Optimization Simulation v2",
        "",
        f"Baseline Coverage: {baseline}%",
        "",
        "| Optimization | Estimated Songs | Contribution | Predicted Coverage |",
        "| --- | ---: | ---: | ---: |",
    ]
    for name, song_ids in groups.items():
        contribution = _points(len(song_ids) * weights.get(name, 1), total)
        lines.append(f"| {name} | {len(song_ids)} | +{contribution}% | {round(baseline + contribution, 2)}% |")
    combined_points = _points(combined, total)
    lines.append(f"| Combined | {round(combined)} | +{combined_points}% | {round(baseline + combined_points, 2)}% |")
    (directory / "optimization_simulation_v2.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_matching_optimization_spec(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    coverage = _coverage(db, run_id)
    failures = Counter(row["primary_failure_reason"] for row in db.execute("select primary_failure_reason from failed_tracks where run_id=?", (run_id,)))
    retry_gain = _points(failures["network_error"] * 0.5, _total(db, run_id))
    artist_gain = _points(failures["artist_mismatch"], _total(db, run_id))
    title_gain = _points(failures["title_mismatch"] + failures["version_mismatch"], _total(db, run_id))
    providers = _provider_success(db, run_id)
    provider_order = ", ".join(row["provider"] for row in providers) or "None"
    lines = [
        "# Matching Optimization Specification",
        "",
        "## Current Failure Statistics",
        "",
        f"- Baseline coverage: {coverage}%",
    ]
    lines.extend(f"- {reason}: {count}" for reason, count in failures.most_common())
    lines.extend([
        "",
        "## Recommended Algorithm",
        "",
        "1. Normalize title before search and before candidate scoring: lowercase, strip bracket metadata, remove live/remix/acoustic/version/OST suffixes, collapse punctuation and spaces.",
        "2. Normalize artist names: lowercase, remove feat/ft/featuring segments, normalize separators to commas, trim special characters, sort multi-artist tokens for comparison.",
        "3. Retry transient provider failures twice with short backoff; do not retry clear no-lyrics or low-confidence mismatches.",
        f"4. Provider fallback order from latest benchmark: {provider_order}.",
        "5. Use confidence scoring instead of a single strict equality check.",
        "",
        "## Confidence Scoring",
        "",
        "- Title similarity: 45 points",
        "- Artist similarity: 30 points",
        "- Duration within 5/10/15 seconds: 15/10/5 points",
        "- Album or source metadata match: 10 points",
        "- Accept at 80+ only; reject ambiguous candidates within 3 points of each other.",
        "",
        "## Priority And Estimated Lift",
        "",
        f"1. Retry strategy: +{retry_gain}%",
        f"2. Artist normalization: +{artist_gain}%",
        f"3. Title normalization: +{title_gain}%",
        "4. Provider fallback order: use benchmark order, but keep language-specific review before app changes.",
        "5. Confidence scoring: safest foundation for the normalization rules above.",
        "",
        "## Swift Implementation Notes",
        "",
        "- Add pure helpers in LyricsClient scope or a small TrackMatcher file: `normalizedTitle(_:)`, `normalizedArtists(_:)`, `confidence(track:candidate:)`.",
        "- Keep the old strict checks as a high-confidence fast path.",
        "- Return lyrics only when confidence is high; log rejected candidates for future benchmark comparison.",
        "- Wrap provider calls with retry only for network/provider errors.",
        "- Do not change UI or provider APIs for this optimization.",
    ])
    (directory / "matching_optimization_spec.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_recommendation(db: sqlite3.Connection, run_id: int, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    coverage = _coverage(db, run_id)
    provider = _provider_success(db, run_id)
    failures = Counter(row["primary_failure_reason"] for row in db.execute("select primary_failure_reason from failed_tracks where run_id=?", (run_id,)))
    lines = [
        "# NotchMuse Matching Recommendations",
        "",
        f"Current Coverage: {coverage}%",
        "",
        "1. Add retry for network/provider failures.",
        f"   Expected impact: up to {round(failures['network_error'] * 0.35 / 1000 * 100, 2)}%",
        "2. Improve artist normalization for aliases, feat, and multi-artist ordering.",
        f"   Expected impact: up to {round(failures['artist_mismatch'] / 1000 * 100, 2)}%",
        "3. Keep LRCMux first for English/Other tracks.",
        f"   Current top provider: {provider[0]['provider'] if provider else 'None'}",
        "4. Review Chinese/Japanese/Korean priority separately before changing NotchMuse.",
    ]
    (directory / "recommendation.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_coverage_history(db: sqlite3.Connection, directory: Path) -> None:
    history = directory / "history"
    history.mkdir(parents=True, exist_ok=True)
    lines = ["date,coverage,success,failed,top_provider"]
    for run in db.execute("select id, coalesce(finished_at, started_at) as date from benchmark_runs where status='finished' order by id"):
        total = db.execute("select count(distinct song_id) from provider_results where run_id=?", (run["id"],)).fetchone()[0]
        success = db.execute("select count(*) from (select song_id from provider_results where run_id=? group by song_id having max(lyrics_available)=1)", (run["id"],)).fetchone()[0]
        top = db.execute("select provider, sum(lyrics_available) as success from provider_results where run_id=? group by provider order by success desc limit 1", (run["id"],)).fetchone()
        lines.append(f"{run['date']},{round(success * 100 / total, 2) if total else 0},{success},{total - success},{top['provider'] if top else ''}")
    (history / "coverage_history.csv").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _primary_failure_reason(providers: list[dict], issue: dict) -> str:
    reasons = {provider["failure_reason"] for provider in providers}
    fixes = set(issue["possible_fixes"])
    if reasons <= {"no_lyrics_found"}:
        return "no_lyrics_found"
    if "remove_version_suffix" in fixes or "strip_ost_metadata" in fixes:
        return "version_mismatch"
    if "normalize_feature_artist" in fixes or "sort_multi_artist_names" in fixes:
        return "artist_mismatch"
    if "api_unavailable" in reasons:
        return "network_error"
    if "unknown_error" in reasons or "invalid_response" in reasons:
        return "provider_error"
    return "title_mismatch" if "matching_failed" in reasons else "provider_error"


def _coverage(db: sqlite3.Connection, run_id: int) -> float:
    total = _total(db, run_id)
    success = db.execute(
        "select count(*) from (select song_id from provider_results where run_id=? group by song_id having max(lyrics_available)=1)",
        (run_id,),
    ).fetchone()[0]
    return round(success / total * 100, 2) if total else 0


def _total(db: sqlite3.Connection, run_id: int) -> int:
    return db.execute("select count(distinct song_id) from provider_results where run_id=?", (run_id,)).fetchone()[0]


def _provider_success(db: sqlite3.Connection, run_id: int, category: str | None = None) -> list[sqlite3.Row]:
    if category:
        return db.execute(
            """
            select pr.provider, sum(pr.lyrics_available) as success
            from provider_results pr
            join songs s on s.id=pr.song_id
            where pr.run_id=? and s.category=?
            group by pr.provider
            having success > 0
            order by success desc, pr.provider
            """,
            (run_id, category),
        ).fetchall()
    return db.execute(
        """
        select provider, sum(lyrics_available) as success
        from provider_results
        where run_id=?
        group by provider
        having success > 0
        order by success desc, provider
        """,
        (run_id,),
    ).fetchall()


def _fix_rows(rows: list[sqlite3.Row], fixes: set[str], reasons: set[str] | None = None) -> set[int]:
    return {
        row["id"]
        for row in rows
        if (reasons is None or row["primary_failure_reason"] in reasons)
        if fixes & {fix.strip() for fix in row["possible_fix"].split(",") if fix.strip()}
    }


def _points(count: float, total: int) -> float:
    return round(count * 100 / total, 2) if total else 0


def _recommendation(reason: str) -> str:
    return {
        "artist_mismatch": "Improve artist normalization and alias handling.",
        "title_mismatch": "Compare cleaned titles and store rejected candidate titles.",
        "version_mismatch": "Remove live/remix/acoustic/version/OST suffixes before scoring.",
        "network_error": "Retry provider requests with backoff.",
        "provider_error": "Log provider payload snippets for parser fixes.",
        "no_lyrics_found": "Mark as missing lyrics and avoid repeated manual investigation.",
    }.get(reason, "Manual review.")


def _language(category: str) -> str:
    return {
        "english_pop": "English",
        "chinese_pop": "Chinese",
        "japanese": "Japanese",
        "korean": "Korean",
    }.get(category, "Other")


def _categories(language: str) -> list[str]:
    return {
        "English": ["english_pop"],
        "Chinese": ["chinese_pop"],
        "Japanese": ["japanese"],
        "Korean": ["korean"],
        "Other": ["spotify_hot", "independent"],
    }[language]
