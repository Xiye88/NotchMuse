from __future__ import annotations

import argparse
import asyncio
from datetime import date, datetime, timezone
from pathlib import Path

from .dataset import load_tracks, sample_tracks
from .db import connect, init_db, insert_result, refresh_missing_lyrics, upsert_songs
from .analysis import refresh_failed_tracks
from .providers import call_provider, default_providers
from .report import build_summary, write_reports
from .runner import gather_tracks


def main() -> None:
    parser = argparse.ArgumentParser(prog="lyrics-benchmark")
    parser.add_argument("--db", default="data/benchmark.sqlite3")
    subcommands = parser.add_subparsers(dest="command", required=True)

    init = subcommands.add_parser("init")

    run = subcommands.add_parser("run")
    run.add_argument("--dataset", required=True)
    run.add_argument("--dataset-name", default="default")
    run.add_argument("--reports", default="reports")
    run.add_argument("--concurrency", type=int, default=4)
    run.add_argument("--sample-size", type=int)
    run.add_argument("--sample-seed", default=None)

    report = subcommands.add_parser("report")
    report.add_argument("--run-id", type=int)
    report.add_argument("--reports", default="reports")

    args = parser.parse_args()
    db = connect(Path(args.db))
    init_db(db)

    if args.command == "init":
        return
    if args.command == "run":
        asyncio.run(_run(db, args))
        return
    if args.command == "report":
        run_id = args.run_id or db.execute("select max(id) from benchmark_runs").fetchone()[0]
        refresh_failed_tracks(db, run_id)
        summary = build_summary(db, run_id)
        summary["_db_path"] = str(Path(args.db))
        write_reports(summary, Path(args.reports))


async def _run(db, args) -> None:
    tracks = sample_tracks(load_tracks(Path(args.dataset)), args.sample_size, args.sample_seed or date.today().isoformat())
    song_ids = upsert_songs(db, tracks, args.dataset_name)
    started = datetime.now(timezone.utc).isoformat()
    cursor = db.execute(
        "insert into benchmark_runs(started_at, dataset_name, status) values(?,?,?)",
        (started, args.dataset_name, "running"),
    )
    run_id = int(cursor.lastrowid)
    providers = [(name, lambda track, n=name, p=provider: call_provider(n, p, track)) for name, provider in default_providers()]
    for provider, _ in providers:
        db.execute("insert or ignore into providers(name, enabled) values(?, 1)", (provider,))
    db.commit()

    results = await gather_tracks(tracks, providers, args.concurrency)
    for track, provider_results in results.items():
        for result in provider_results:
            insert_result(db, run_id, song_ids[track], result)
    refresh_missing_lyrics(db, run_id)
    refresh_failed_tracks(db, run_id)
    finished = datetime.now(timezone.utc).isoformat()
    db.execute("update benchmark_runs set finished_at=?, status=? where id=?", (finished, "finished", run_id))
    db.commit()
    summary = build_summary(db, run_id)
    summary["_db_path"] = str(Path(args.db))
    write_reports(summary, Path(args.reports))


if __name__ == "__main__":
    main()
