#!/usr/bin/env python3
"""Build paired NotchMuse fixtures from public iTunes Search metadata.

YT rows are deterministic metadata transformations of the same recordings.
They are not YouTube uploads, and their times are the source audio durations.
"""
import argparse
import csv
import hashlib
import itertools
import json
import re
import sys
import time
import unicodedata
from pathlib import Path
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import urlopen


# Quotas spread the sample across markets and genres. Seeds are artist searches.
GROUPS = [
    ("mandopop", "TW", 144, "周杰倫|林俊傑|孫燕姿|蔡依林|五月天|張惠妹|田馥甄|陳奕迅|王力宏|李榮浩"),
    ("cantopop", "HK", 100, "陳奕迅|張國榮|梅艷芳|Beyond|容祖兒|陳慧琳|王菲|張學友|楊千嬅"),
    ("mainland_online", "TW", 64, "周深|毛不易|薛之謙|趙雷|李宇春|鄧紫棋|汪蘇瀧|告五人|任然|陳粒"),
    ("western_pop", "US", 104, "Taylor Swift|Adele|Billie Eilish|The Weeknd|Lady Gaga|Bruno Mars|Dua Lipa|Ed Sheeran"),
    ("western_rock", "US", 85, "Coldplay|Linkin Park|Queen|Paramore|Fall Out Boy|The Killers|The Strokes"),
    ("rnb_hiphop", "US", 85, "Beyoncé|SZA|Rihanna|Kendrick Lamar|J. Cole|Alicia Keys|Lauryn Hill|Nas"),
    ("jpop_anime", "JP", 102, "宇多田ヒカル|Aimer|YOASOBI|米津玄師|LiSA|椎名林檎|RADWIMPS|ポルノグラフィティ|King Gnu"),
    ("kpop", "US", 100, "BTS|BLACKPINK|TWICE|IU|NewJeans|Red Velvet|SEVENTEEN|Girls' Generation|SHINee"),
]
GUARD_ALBUMS = {
    "Yiruma": ("Yiruma 2nd Album 'First Love'", "Yiruma 3rd Album 'From The Yellow Room'", "Piano Museum", "Poemusic"),
    "Ludovico Einaudi": ("Divenire", "Una Mattina", "I Giorni", "Le Onde", "In a Time Lapse"),
    "Max Richter": ("Infra", "Recomposed by Max Richter: Vivaldi, The Four Seasons", "Richter: On the Nature of Daylight (Piano Version)"),
    "Joe Hisaishi": ("Piano Stories", "FREEDOM PIANO STORIES 4", "Encore", "Etude - A Wish to the Moon"),
    "Explosions in the Sky": ("The Earth Is Not a Cold Dead Place", "All of a Sudden I Miss Everyone"),
    "Ólafur Arnalds": ("Eulogy for Evolution", "And They Have Escaped", "Living Room Songs"),
    "Nils Frahm": ("Felt", "Solo", "Spaces", "Screws"),
    "Brian Eno": ("Ambient 1: Music for Airports", "Ambient 4: On Land", "Reflection"),
}
# Taiwan Apple catalog IDs from the project's existing chart-seed dataset.
# These rows cover newer viral pop, soundtrack titles and collaboration credits.
VIRAL_SEEDS = (
    1790602218, 1692508528, 1815583986, 1766456183, 1796520821, 1497822969,
    1874801993, 1884874215, 1321295662, 1788007696, 1112093259, 1721456390,
)
LAB_CHART = Path(__file__).resolve().parents[1] / "tools/lyrics-provider-benchmark/datasets/top_songs_weighted.tsv"
VERSION = re.compile(r"\b(?:live|karaoke|instrumental|off.vocal|backing track|sped up|slowed)\b|伴奏|現場|现场|純音樂|カラオケ|インスト", re.I)
VARIANT = re.compile(r"\s*[([][^)\]]*(?:live|remaster|version|mix|edit|acoustic|feat\.|伴奏|instrumental)[^)\]]*[)\]]\s*$", re.I)


def key(value):
    folded = unicodedata.normalize("NFKC", value).casefold()
    return "".join(character for character in folded if character.isalnum())


def fetch(path, endpoint, params):
    if path.exists():
        return json.loads(path.read_text())["results"]
    for attempt in range(3):
        time.sleep(3.1 if attempt == 0 else 8 * attempt)
        try:
            with urlopen(f"https://itunes.apple.com/{endpoint}?{urlencode(params)}", timeout=25) as response:
                raw = response.read()
            results = json.loads(raw)["results"]
            path.write_bytes(raw)
            print(f"{path.stem}: {len(results)}", file=sys.stderr, flush=True)
            return results
        except (URLError, TimeoutError, ValueError, KeyError) as error:
            print(f"{path.stem}: {error}", file=sys.stderr, flush=True)
    return []


def studio_row(row, store):
    title, name, album = (row.get(field, "") for field in ("trackName", "artistName", "collectionName"))
    duration = row.get("trackTimeMillis", 0)
    if not all((title, name, album, row.get("trackId"))) or not 90_000 <= duration <= 480_000:
        return None
    if VERSION.search(title + " " + album):
        return None
    return title, name, album, f"{duration / 1000:.3f}", str(row["trackId"]), store


def recordings(store, artist, cache, guard=False):
    params = dict(term=artist, country=store, media="music", entity="song", limit=100, attribute="artistTerm")
    for row in fetch(cache / f"{store}-{key(artist)}.json", "search", params):
        recording = studio_row(row, store)
        if recording is None:
            continue
        _, name, album, _, _, _ = recording
        if key(artist) != key(name) and not re.search(
            rf"(?:^|\W){re.escape(artist)}(?:$|\W)", name, re.I
        ):
            continue
        if guard and (key(name) != key(artist) or not any(
            key(album).startswith(key(allowed)) for allowed in GUARD_ALBUMS[artist]
        )):
            continue
        yield recording


def chart_pool(cache):
    with LAB_CHART.open(newline="", encoding="utf-8") as file:
        chart = list(csv.DictReader(file, delimiter="\t"))
    seeds = list(VIRAL_SEEDS)
    seeds.extend(int(row["track_id"]) for row in chart if row["category"] == "spotify_hot" and (
        re.search(r"[\u3400-\u9fff]", row["title"] + row["artist"]) or
        re.search(r"OST|soundtrack|theme song", row["title"] + row["album"], re.I)
    ))
    seeds.extend(int(row["track_id"]) for row in chart if row["category"] == "chinese_pop")
    # Use Apple metadata for identities and durations, with local-language TW credits.
    seeds = list(dict.fromkeys(seeds))
    for index in range(0, len(seeds), 75):
        ids = seeds[index:index + 75]
        params = dict(id=",".join(map(str, ids)), country="TW")
        batch = hashlib.sha256(params["id"].encode()).hexdigest()[:12]
        rows = fetch(cache / f"TW-chart-{batch}.json", "lookup", params)
        by_id = {row.get("trackId"): row for row in rows}
        for identifier in ids:
            row = studio_row(by_id.get(identifier, {}), "TW")
            if row is not None:
                yield row


def sample(bucket, pools, count, seen, ids):
    rows = []
    for level in itertools.zip_longest(*pools):
        for row in filter(None, level):
            title, artist, _, _, identifier, _ = row
            identity = (key(VARIANT.sub("", title)), key(artist))
            if identity in seen or identifier in ids:
                continue
            seen.add(identity)
            ids.add(identifier)
            rows.append((bucket, *row))
            if len(rows) == count:
                return rows
    raise ValueError(f"{bucket}: found {len(rows)} of {count} required distinct recordings")


def youtube(row, index):
    bucket, title, artist, album, duration, identifier, store = row
    if index % 7 == 0:
        return ("topic", title, f"{artist} - Topic", album, duration, identifier, store)
    if index % 7 == 1:
        return ("official_video", f"{artist} - {title} (Official Video)", artist, "", duration, identifier, store)
    if index % 7 == 2:
        return ("lyrics", f"{title} (Lyrics)", f"{artist} - Topic", "", duration, identifier, store)
    if index % 7 == 3:
        return ("cjk_lyrics", f"{title}【動態歌詞】", f"{artist} - Topic", "", duration, identifier, store)
    if index % 7 == 4:
        return ("packed_mv", f"{artist} - {title} (MV)", "", "", duration, identifier, store)
    if index % 7 == 5:
        return ("official_audio", f"{title} (Official Audio)", artist, album, duration, identifier, store)
    return ("quality", f"{artist} - {title} [4K]", artist, "", duration, identifier, store)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=Path("/tmp/notchmuse-itunes-metadata"))
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent / "fixtures")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    seen, ids = set(), set()
    vocal = sample("viral_chart_ost", [list(chart_pool(args.cache))], 16, seen, ids)
    for bucket, market, count, seeds in GROUPS:
        pools = [list(recordings(market, seed, args.cache)) for seed in seeds.split("|")]
        vocal.extend(sample(bucket, pools, count, seen, ids))
    guards = sample("guard_inst", [list(recordings("US", seed, args.cache, guard=True))
                                   for seed in GUARD_ALBUMS], 40, seen, ids)
    dirty = [youtube(row, index) for index, row in enumerate(vocal)]
    dirty_guards = [(row[0], *youtube(row, index)[1:]) for index, row in enumerate(guards)]
    header = ["bucket", "title", "artist", "album", "duration_seconds", "itunes_track_id", "storefront"]
    for name, rows in (("benchmark_800_catalog.tsv", vocal + guards), ("ytm_800.tsv", dirty + dirty_guards)):
        with (args.output / name).open("w", newline="", encoding="utf-8") as output:
            writer = csv.writer(output, delimiter="\t", lineterminator="\n", quoting=csv.QUOTE_NONE, quotechar=None)
            writer.writerow(header)
            writer.writerows([field.replace("\n", " ").replace("\r", " ").replace("\t", " ") for field in row] for row in rows)


if __name__ == "__main__":
    main()
