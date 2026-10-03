from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from .matcher import Track
from .runner import ProviderResult


def connect(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    return db


def init_db(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        create table if not exists songs(
          id integer primary key,
          spotify_track_id text,
          title text not null,
          artist text not null,
          album text not null default '',
          duration_seconds real not null,
          category text not null default '',
          source_dataset text not null default ''
        );
        create table if not exists providers(
          id integer primary key,
          name text not null unique,
          enabled integer not null default 1
        );
        create table if not exists benchmark_runs(
          id integer primary key,
          started_at text not null,
          finished_at text,
          dataset_name text not null,
          status text not null
        );
        create table if not exists provider_results(
          id integer primary key,
          run_id integer not null,
          song_id integer not null,
          provider text not null,
          status text not null,
          lyrics_available integer not null,
          line_count integer not null,
          latency_ms integer not null,
          failure_reason text,
          match_score integer,
          matched_title text,
          matched_artist text,
          matched_duration_seconds real,
          raw_error text,
          top_score integer,
          second_score integer,
          reject_reason text,
          second_matched_title text,
          second_matched_artist text,
          second_matched_duration_seconds real
        );
        create table if not exists missing_lyrics(
          id integer primary key,
          song_id integer not null,
          run_id integer not null,
          failed_providers text not null,
          first_seen_at text not null,
          last_seen_at text not null
        );
        create table if not exists failed_tracks(
          id integer primary key,
          run_id integer not null,
          song_id integer not null,
          title text not null,
          artist text not null,
          album text not null default '',
          language text not null default '',
          category text not null default '',
          duration_seconds real not null,
          attempted_providers text not null,
          provider_response text not null,
          primary_failure_reason text not null,
          possible_fix text not null
        );
        """
    )
    _add_column(db, "songs", "category", "text not null default ''")
    _add_column(db, "failed_tracks", "language", "text not null default ''")
    _add_column(db, "provider_results", "top_score", "integer")
    _add_column(db, "provider_results", "second_score", "integer")
    _add_column(db, "provider_results", "reject_reason", "text")
    _add_column(db, "provider_results", "second_matched_title", "text")
    _add_column(db, "provider_results", "second_matched_artist", "text")
    _add_column(db, "provider_results", "second_matched_duration_seconds", "real")
    db.commit()


def _add_column(db: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    columns = {row["name"] for row in db.execute(f"pragma table_info({table})")}
    if column not in columns:
        db.execute(f"alter table {table} add column {column} {definition}")


def upsert_songs(db: sqlite3.Connection, tracks: list[Track], dataset: str) -> dict[Track, int]:
    ids: dict[Track, int] = {}
    for track in tracks:
        existing = db.execute(
            "select id from songs where title=? and artist=? and album=? and duration_seconds=? and source_dataset=?",
            (track.title, track.artist, track.album, track.duration_seconds, dataset),
        ).fetchone()
        if existing:
            ids[track] = int(existing["id"])
            continue
        cursor = db.execute(
            "insert into songs(spotify_track_id, title, artist, album, duration_seconds, category, source_dataset) values(?,?,?,?,?,?,?)",
            (track.track_id, track.title, track.artist, track.album, track.duration_seconds, track.category, dataset),
        )
        ids[track] = int(cursor.lastrowid)
    db.commit()
    return ids


def insert_result(db: sqlite3.Connection, run_id: int, song_id: int, result: ProviderResult) -> None:
    db.execute(
        """
        insert into provider_results(
          run_id, song_id, provider, status, lyrics_available, line_count, latency_ms,
          failure_reason, match_score, matched_title, matched_artist, matched_duration_seconds, raw_error,
          top_score, second_score, reject_reason,
          second_matched_title, second_matched_artist, second_matched_duration_seconds
        ) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            run_id,
            song_id,
            result.provider,
            result.status,
            int(result.lyrics_available),
            result.line_count,
            result.latency_ms,
            result.failure_reason,
            result.match_score,
            result.matched_title,
            result.matched_artist,
            result.matched_duration_seconds,
            result.raw_error,
            result.top_score,
            result.second_score,
            result.reject_reason,
            result.second_matched_title,
            result.second_matched_artist,
            result.second_matched_duration_seconds,
        ),
    )


def refresh_missing_lyrics(db: sqlite3.Connection, run_id: int) -> None:
    now = datetime.now(timezone.utc).isoformat()
    rows = db.execute(
        """
        select song_id, group_concat(provider, ', ') as providers
        from provider_results
        where run_id=?
        group by song_id
        having max(lyrics_available)=0
        """,
        (run_id,),
    ).fetchall()
    for row in rows:
        db.execute(
            """
            insert into missing_lyrics(song_id, run_id, failed_providers, first_seen_at, last_seen_at)
            values(?,?,?,?,?)
            """,
            (row["song_id"], run_id, row["providers"], now, now),
        )
