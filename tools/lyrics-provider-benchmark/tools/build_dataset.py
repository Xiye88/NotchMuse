from __future__ import annotations

import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path


COUNTRIES = "us gb ca au nz cn hk tw jp kr sg my th id ph in br mx de fr es it nl se no dk fi".split()
LANGUAGE_BY_COUNTRY = {
    "cn": "chinese_pop",
    "hk": "chinese_pop",
    "tw": "chinese_pop",
    "jp": "japanese",
    "kr": "korean",
}


def main() -> None:
    rows = []
    seen = set()
    for country in COUNTRIES:
        for item in chart(country) or []:
            key = (item["name"].casefold(), item["artistName"].casefold())
            if key in seen:
                continue
            seen.add(key)
            rows.append(item | {"country": country})
    details = lookup([row["id"] for row in rows])
    output = []
    for row in rows:
        detail = details.get(int(row["id"]))
        duration_ms = detail.get("trackTimeMillis") if detail else None
        if not duration_ms:
            continue
        genres = [genre["name"] for genre in row.get("genres", [])]
        output.append(
            {
                "track_id": row["id"],
                "title": row["name"],
                "artist": row["artistName"],
                "album": detail.get("collectionName", "") if detail else "",
                "duration_seconds": round(duration_ms / 1000),
                "category": category(row["country"], genres),
            }
        )
        if len(output) == 1000:
            break
    if len(output) < 1000:
        raise SystemExit(f"only built {len(output)} tracks")
    target = Path(__file__).resolve().parents[1] / "datasets" / "extended_1000.tsv"
    with target.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["track_id", "title", "artist", "album", "duration_seconds", "category"], delimiter="\t")
        writer.writeheader()
        writer.writerows(output)
    print(target)


def chart(country: str) -> list[dict]:
    url = f"https://rss.applemarketingtools.com/api/v2/{country}/music/most-played/100/songs.json"
    for _ in range(2):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                return json.load(response)["feed"]["results"]
        except Exception:
            time.sleep(1)
    return []


def lookup(ids: list[str]) -> dict[int, dict]:
    results = {}
    for offset in range(0, len(ids), 200):
        query = urllib.parse.urlencode({"id": ",".join(ids[offset : offset + 200]), "entity": "song"})
        with urllib.request.urlopen(f"https://itunes.apple.com/lookup?{query}", timeout=20) as response:
            for item in json.load(response).get("results", []):
                if item.get("kind") == "song":
                    results[item["trackId"]] = item
        time.sleep(0.2)
    return results


def category(country: str, genres: list[str]) -> str:
    genre_text = " ".join(genres).casefold()
    if "alternative" in genre_text or "indie" in genre_text:
        return "independent"
    return LANGUAGE_BY_COUNTRY.get(country, "english_pop" if country in {"us", "gb", "ca", "au", "nz"} else "spotify_hot")


if __name__ == "__main__":
    main()
