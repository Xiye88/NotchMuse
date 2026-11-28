#!/usr/bin/env python3
"""NotchMuse daily upstream lyrics provider health probe (zero external dependencies)."""
import datetime
import json
import sys
import time
import urllib.parse
import urllib.request

TIMEOUT = 6
UA = "NotchMuse-HealthProbe/1.0"

CANARY_TRACKS = [
    ("Blinding Lights", "The Weeknd", 200),
    ("Anti-Hero", "Taylor Swift", 200),
    ("Shape of You", "Ed Sheeran", 233),
    ("Someone Like You", "Adele", 285),
    ("Yellow", "Coldplay", 267),
    ("As It Was", "Harry Styles", 167),
    ("晴天", "周杰伦", 269),
    ("七里香", "周杰伦", 299),
    ("江南", "林俊杰", 268),
    ("十年", "陈奕迅", 205),
    ("演员", "薛之谦", 261),
    ("光年之外", "邓紫棋", 235),
    ("小幸运", "田馥甄", 265),
    ("Ditto", "NewJeans", 185),
    ("夜に駆ける", "YOASOBI", 261),
]


def http_get_json(url: str, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def probe_lrclib(title: str, artist: str, dur: int) -> bool:
    q = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
    data = http_get_json(f"https://lrclib.net/api/search?{q}")
    return isinstance(data, list) and any((item.get("syncedLyrics") or "").strip() for item in data)


def probe_kugou(title: str, artist: str, dur: int) -> bool:
    q = urllib.parse.urlencode({"ver": 1, "man": "yes", "client": "mobi", "keyword": f"{title} {artist}", "duration": dur * 1000})
    data = http_get_json(f"https://krcs.kugou.com/search?{q}")
    return bool(data.get("candidates"))


def probe_qq(title: str, artist: str, dur: int) -> bool:
    q = urllib.parse.urlencode({"w": f"{title} {artist}", "format": "json", "n": 5})
    data = http_get_json(
        f"https://c.y.qq.com/soso/fcgi-bin/client_search_cp?{q}",
        headers={"Referer": "https://y.qq.com/"},
    )
    return bool((((data.get("data") or {}).get("song") or {}).get("list")))


def probe_netease(title: str, artist: str, dur: int) -> bool:
    q = urllib.parse.urlencode({"s": f"{title} {artist}", "type": 1, "limit": 5})
    data = http_get_json(
        f"https://music.163.com/api/search/get/web?{q}",
        headers={"Referer": "https://music.163.com/"},
    )
    return bool(((data.get("result") or {}).get("songs")))


def probe_lrcmux(title: str, artist: str, dur: int) -> bool:
    q = urllib.parse.urlencode({"title": title, "artist": artist, "duration": dur})
    data = http_get_json(f"https://api.lrc.cx/lyrics?{q}")
    return bool(data)


PROVIDERS = [
    ("LRCLIB", probe_lrclib),
    ("Kugou", probe_kugou),
    ("QQ", probe_qq),
    ("NetEase", probe_netease),
    ("LRCMux", probe_lrcmux),
]


def main() -> int:
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"=== NotchMuse Lyrics Provider Health Probe ({ts}, n={len(CANARY_TRACKS)}) ===")
    overall_ok = True
    for name, fn in PROVIDERS:
        hits = errors = 0
        latencies = []
        last_err = ""
        for title, artist, dur in CANARY_TRACKS:
            t0 = time.monotonic()
            try:
                if fn(title, artist, dur):
                    hits += 1
            except Exception as exc:
                errors += 1
                last_err = type(exc).__name__
            latencies.append(int((time.monotonic() - t0) * 1000))
        latencies.sort()
        med = latencies[len(latencies) // 2] if latencies else 0
        status = "OK" if hits >= 8 and errors <= 3 else ("DEGRADED" if hits >= 3 else "DOWN")
        if status == "DOWN":
            overall_ok = False
        err_note = f" last_err={last_err}" if last_err else ""
        print(f"  {name:<8} status={status:<8} hits={hits:2d}/{len(CANARY_TRACKS)} errors={errors:2d} median={med:4d}ms{err_note}")
    return 0 if overall_ok else 1


if __name__ == "__main__":
    sys.exit(main())
