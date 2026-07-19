from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

from .analysis import (
    write_coverage_history,
    write_matching_simulation,
    write_matching_optimization_spec,
    write_optimization_report,
    write_optimization_simulation_v2,
    write_provider_language_matrix,
    write_provider_strategy,
    write_recommendation,
    write_retry_analysis,
)


def build_summary(db: sqlite3.Connection, run_id: int) -> dict:
    run = db.execute("select * from benchmark_runs where id=?", (run_id,)).fetchone()
    total = db.execute("select count(distinct song_id) from provider_results where run_id=?", (run_id,)).fetchone()[0]
    successful = db.execute(
        "select count(*) from (select song_id from provider_results where run_id=? group by song_id having max(lyrics_available)=1)",
        (run_id,),
    ).fetchone()[0]
    provider_rows = db.execute(
        """
        select provider,
               sum(lyrics_available) as success,
               count(*) - sum(lyrics_available) as failed,
               avg(latency_ms) as avg_latency_ms
        from provider_results
        where run_id=?
        group by provider
        order by provider
        """,
        (run_id,),
    ).fetchall()
    unique_rows = db.execute(
        """
        select provider, count(*) as unique_success
        from provider_results pr
        where run_id=? and lyrics_available=1
          and (select count(*) from provider_results other
               where other.run_id=pr.run_id and other.song_id=pr.song_id and other.lyrics_available=1) = 1
        group by provider
        """,
        (run_id,),
    ).fetchall()
    unique = {row["provider"]: row["unique_success"] for row in unique_rows}
    failures = {
        row["failure_reason"]: row["count"]
        for row in db.execute(
            """
            select failure_reason, count(*) as count
            from provider_results
            where run_id=? and lyrics_available=0 and failure_reason is not null
            group by failure_reason
            """,
            (run_id,),
        )
    }
    provider_ranking = [
        {"provider": row["provider"], "first_success": row["first_success"]}
        for row in db.execute(
            """
            select provider, count(*) as first_success
            from provider_results pr
            where run_id=? and lyrics_available=1
              and latency_ms = (select min(latency_ms) from provider_results other
                                where other.run_id=pr.run_id and other.song_id=pr.song_id and other.lyrics_available=1)
            group by provider
            order by first_success desc, provider
            """,
            (run_id,),
        )
    ]
    failed_songs = [
        dict(row)
        for row in db.execute(
            """
            select s.title, s.artist, s.duration_seconds, s.category
            from songs s
            join provider_results pr on pr.song_id=s.id and pr.run_id=?
            group by s.id
            having max(pr.lyrics_available)=0
            order by s.title
            limit 100
            """,
            (run_id,),
        )
    ]
    seven_day_average = _seven_day_average(db, run_id, run["finished_at"] or run["started_at"]) if run else 0
    return {
        "run_id": run_id,
        "_db_path": db.execute("pragma database_list").fetchone()["file"],
        "started_at": run["started_at"] if run else "",
        "finished_at": run["finished_at"] if run else "",
        "total_songs": total,
        "successful_songs": successful,
        "failed_songs": total - successful,
        "coverage_rate": round(successful / total * 100, 2) if total else 0,
        "providers": {
            row["provider"]: {
                "success": int(row["success"] or 0),
                "failed": int(row["failed"] or 0),
                "unique_success": int(unique.get(row["provider"], 0)),
                "avg_latency_ms": round(row["avg_latency_ms"] or 0),
            }
            for row in provider_rows
        },
        "failure_reasons": failures,
        "provider_ranking": provider_ranking,
        "failed_songs_detail": failed_songs,
        "seven_day_average_coverage_rate": seven_day_average,
    }


def write_reports(summary: dict, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    history = directory / "history"
    history.mkdir(exist_ok=True)
    (directory / "latest.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Lyrics Provider Benchmark",
        "",
        "## Overall Coverage",
        "",
        f"Total Songs: {summary['total_songs']}",
        f"Successful Songs: {summary['successful_songs']}",
        f"Failed Songs: {summary['failed_songs']}",
        f"Coverage Rate: {summary['coverage_rate']}%",
        f"7 Day Average Coverage Rate: {summary['seven_day_average_coverage_rate']}%",
        "",
        "## Provider Ranking",
        "",
        "| Provider | First Success |",
        "| --- | ---: |",
    ]
    for row in summary["provider_ranking"]:
        lines.append(f"| {row['provider']} | {row['first_success']} |")
    lines.extend([
        "",
        "## Unique Contribution",
        "",
        "| Provider | Success | Failed | Unique Success | Avg Latency ms |",
        "| --- | ---: | ---: | ---: | ---: |",
    ])
    for provider, values in summary["providers"].items():
        lines.append(
            f"| {provider} | {values['success']} | {values['failed']} | {values['unique_success']} | {values['avg_latency_ms']} |"
        )
    lines.extend(["", "## Failed Songs", ""])
    if summary["failed_songs_detail"]:
        lines.extend(["| Title | Artist | Duration | Category |", "| --- | --- | ---: | --- |"])
        for song in summary["failed_songs_detail"]:
            lines.append(f"| {song['title']} | {song['artist']} | {song['duration_seconds']} | {song['category']} |")
    else:
        lines.append("None")
    lines.extend(["", "## Trend", "", f"- 7 day average coverage: {summary['seven_day_average_coverage_rate']}%", "", "## Failure Reasons", ""])
    for reason, count in sorted(summary["failure_reasons"].items()):
        lines.append(f"- {reason}: {count}")
    content = "\n".join(lines) + "\n"
    (directory / "latest.md").write_text(content, encoding="utf-8")
    stamp = (summary.get("finished_at") or summary.get("started_at") or datetime.now(timezone.utc).isoformat()).replace(":", "").replace("+", "Z")
    (history / f"run-{summary['run_id']}-{stamp}.md").write_text(content, encoding="utf-8")
    (history / f"run-{summary['run_id']}.md").write_text(content, encoding="utf-8")
    db_path = summary.get("_db_path")
    if db_path:
        db = sqlite3.connect(db_path)
        db.row_factory = sqlite3.Row
        write_optimization_report(db, summary["run_id"], directory)
        write_provider_strategy(db, summary["run_id"], directory)
        write_provider_language_matrix(db, summary["run_id"], directory)
        write_matching_simulation(db, summary["run_id"], directory)
        write_matching_optimization_spec(db, summary["run_id"], directory)
        write_optimization_simulation_v2(db, summary["run_id"], directory)
        write_retry_analysis(db, summary["run_id"], directory)
        write_recommendation(db, summary["run_id"], directory)
        write_coverage_history(db, directory)


def _seven_day_average(db: sqlite3.Connection, run_id: int, finished_at: str) -> float:
    try:
        end = datetime.fromisoformat(finished_at)
    except ValueError:
        finished_at = db.execute("select coalesce(finished_at, started_at) from benchmark_runs where id=?", (run_id,)).fetchone()[0]
        return _single_run_rate(db, run_id) if finished_at else 0
    start = end - timedelta(days=7)
    rates = []
    for row in db.execute(
        """
        select id
        from benchmark_runs
        where id<=? and status='finished' and coalesce(finished_at, started_at) between ? and ?
        order by id
        """,
        (run_id, start.isoformat(), end.isoformat()),
    ):
        total = db.execute("select count(distinct song_id) from provider_results where run_id=?", (row["id"],)).fetchone()[0]
        successful = db.execute(
            "select count(*) from (select song_id from provider_results where run_id=? group by song_id having max(lyrics_available)=1)",
            (row["id"],),
        ).fetchone()[0]
        if total:
            rates.append(successful / total * 100)
    return round(sum(rates) / len(rates), 2) if rates else 0


def _single_run_rate(db: sqlite3.Connection, run_id: int) -> float:
    total = db.execute("select count(distinct song_id) from provider_results where run_id=?", (run_id,)).fetchone()[0]
    successful = db.execute(
        "select count(*) from (select song_id from provider_results where run_id=? group by song_id having max(lyrics_available)=1)",
        (run_id,),
    ).fetchone()[0]
    return round(successful / total * 100, 2) if total else 0
