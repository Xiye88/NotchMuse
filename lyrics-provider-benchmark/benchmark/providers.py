from __future__ import annotations

import asyncio
import base64
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib
from dataclasses import dataclass

from .matcher import ACCEPTANCE_THRESHOLD, Candidate, MatchDecision, Track, match_decision, score
from .parser import parse_krc, parse_lrc
from .runner import ProviderResult


USER_AGENT = "NotchMuse/0.3 (macOS)"
TIMEOUT = 8


@dataclass(frozen=True)
class HTTPResponse:
    status: int
    body: bytes


def default_providers() -> list[tuple[str, object]]:
    return [
        ("LRCLIB", LRCLIBProvider()),
        ("NetEase", NetEaseProvider()),
        ("LRCMux", LRCMuxProvider()),
        ("QQ", QQProvider()),
        ("Kugou", KugouProvider()),
        ("Soda", SodaProvider()),
    ]


async def call_provider(name: str, provider: object, track: Track) -> ProviderResult:
    started = time.monotonic()
    try:
        return await asyncio.to_thread(provider.fetch, track, started)
    except urllib.error.HTTPError as error:
        return _failed(name, started, "api_unavailable", str(error))
    except urllib.error.URLError as error:
        return _failed(name, started, "api_unavailable", str(error))
    except json.JSONDecodeError as error:
        return _failed(name, started, "invalid_response", str(error))
    except Exception as error:
        return _failed(name, started, "unknown_error", str(error))


def _failed(provider: str, started: float, reason: str, error: str | None = None) -> ProviderResult:
    return ProviderResult(provider, "failed", False, reason, 0, int((time.monotonic() - started) * 1000), raw_error=error)


def _matching_failed(provider: str, started: float, decision: MatchDecision) -> ProviderResult:
    candidate = decision.top_candidate
    second = decision.second_candidate
    return ProviderResult(
        provider,
        "failed",
        False,
        "matching_failed",
        0,
        int((time.monotonic() - started) * 1000),
        decision.top_score,
        candidate.title if candidate else None,
        " / ".join(candidate.artists) if candidate else None,
        candidate.duration_ms / 1000 if candidate else None,
        None,
        decision.top_score,
        decision.second_score,
        decision.reject_reason,
        second.title if second else None,
        " / ".join(second.artists) if second else None,
        second.duration_ms / 1000 if second else None,
    )


def _success(provider: str, started: float, line_count: int, candidate: Candidate | None = None, match_score: int | None = None) -> ProviderResult:
    return ProviderResult(
        provider,
        "success",
        True,
        None,
        line_count,
        int((time.monotonic() - started) * 1000),
        match_score,
        candidate.title if candidate else None,
        " / ".join(candidate.artists) if candidate else None,
        candidate.duration_ms / 1000 if candidate else None,
    )


def _request(url: str, method: str = "GET", data: bytes | None = None, headers: dict[str, str] | None = None) -> HTTPResponse:
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("User-Agent", USER_AGENT)
    for key, value in (headers or {}).items():
        request.add_header(key, value)
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return HTTPResponse(response.status, response.read())


def _json(response: HTTPResponse) -> object:
    if response.status != 200:
        raise urllib.error.HTTPError("", response.status, "bad status", {}, None)
    return json.loads(response.body.decode("utf-8"))


def _jsonp(body: bytes, callback: str) -> object | None:
    text = body.decode("utf-8").strip()
    if not text.startswith(callback + "(") or not text.endswith(")"):
        return None
    return json.loads(text[len(callback) + 1 : -1])


class LRCLIBProvider:
    name = "LRCLIB"

    def fetch(self, track: Track, started: float) -> ProviderResult:
        query = urllib.parse.urlencode({"track_name": track.title, "artist_name": track.artist})
        rows = _json(_request(f"https://lrclib.net/api/search?{query}"))
        usable = [row for row in rows if row.get("syncedLyrics")]
        if not usable:
            return _failed(self.name, started, "no_lyrics_found")
        candidates = [Candidate(row["trackName"], [row["artistName"]], int(float(row["duration"]) * 1000)) for row in usable]
        decision = match_decision(track, candidates)
        if decision.index is None:
            return _matching_failed(self.name, started, decision)
        index = decision.index
        lines = parse_lrc(usable[index]["syncedLyrics"])
        return _success(self.name, started, len(lines), candidates[index], score(track, candidates[index])) if lines else _failed(self.name, started, "invalid_response")


class NetEaseProvider:
    name = "NetEase"

    def fetch(self, track: Track, started: float) -> ProviderResult:
        body = urllib.parse.urlencode({"s": f"{track.title} {track.artist}", "type": "1", "limit": "10", "offset": "0"}).encode()
        search = _json(
            _request(
                "https://music.163.com/api/search/get/web",
                method="POST",
                data=body,
                headers={"Content-Type": "application/x-www-form-urlencoded", "Referer": "https://music.163.com/"},
            )
        )
        songs = (search.get("result") or {}).get("songs") or []
        candidates = [Candidate(song["name"], [artist["name"] for artist in song.get("artists", [])], int(song["duration"])) for song in songs]
        decision = match_decision(track, candidates)
        if decision.index is None:
            return _matching_failed(self.name, started, decision) if songs else _failed(self.name, started, "no_lyrics_found")
        index = decision.index
        song_id = songs[index]["id"]
        lyric = _json(_request(f"https://music.163.com/api/song/lyric?id={song_id}&lv=-1", headers={"Referer": "https://music.163.com/"}))
        lines = parse_lrc((lyric.get("lrc") or {}).get("lyric") or "")
        return _success(self.name, started, len(lines), candidates[index], score(track, candidates[index])) if lines else _failed(self.name, started, "no_lyrics_found")


class LRCMuxProvider:
    name = "LRCMux"

    def fetch(self, track: Track, started: float) -> ProviderResult:
        query = urllib.parse.urlencode(
            {
                "title": track.title,
                "artist": track.artist,
                "album": track.album,
                "duration": str(round(track.duration_seconds)),
                "level": "line",
                "strict": "true",
                "format": "json",
            }
        )
        payload = _json(_request(f"https://api.lrcmux.dev/get?{query}"))
        candidate = Candidate(payload["track"]["title"], [payload["track"]["artist"]], int(payload["track"]["duration"]) * 1000)
        decision = match_decision(track, [candidate])
        match_score = decision.top_score or 0
        if match_score < ACCEPTANCE_THRESHOLD:
            return _matching_failed(self.name, started, decision)
        lines = payload.get("lines") or []
        return _success(self.name, started, len(lines), candidate, match_score) if lines else _failed(self.name, started, "no_lyrics_found")


class QQProvider:
    name = "QQ"

    def fetch(self, track: Track, started: float) -> ProviderResult:
        best_reject: MatchDecision | None = None
        for query in (f"{track.title} {track.artist}", track.title):
            mid, candidate, match_score, reject = self._search(query, track)
            best_reject = _better_reject(best_reject, reject)
            if mid:
                lyric = _jsonp(_request(self._lyric_url(mid), headers={"Referer": "https://c.y.qq.com/"}).body, "MusicJsonCallback_lrc")
                if not lyric or lyric.get("code") != 0:
                    return _failed(self.name, started, "no_lyrics_found")
                decoded = base64.b64decode(lyric.get("lyric") or "").decode("utf-8", errors="replace")
                lines = parse_lrc(decoded)
                return _success(self.name, started, len(lines), candidate, match_score) if lines else _failed(self.name, started, "invalid_response")
        return _matching_failed(self.name, started, best_reject or match_decision(track, []))

    def _search(self, query: str, track: Track) -> tuple[str | None, Candidate | None, int | None, MatchDecision | None]:
        body = json.dumps(
            {
                "comm": {"ct": 19, "cv": "1859", "uin": "0"},
                "req_1": {
                    "method": "DoSearchForQQMusicDesktop",
                    "module": "music.search.SearchCgiService",
                    "param": {"grp": 1, "num_per_page": 20, "page_num": 1, "query": query, "search_type": 0},
                },
            }
        ).encode()
        payload = _json(_request("https://u.y.qq.com/cgi-bin/musicu.fcg", "POST", body, {"Content-Type": "application/json", "Referer": "https://c.y.qq.com/"}))
        songs = payload["req_1"]["data"]["body"]["song"]["list"]
        candidates = [Candidate(song["title"], [singer["name"] for singer in song.get("singer", [])], int(song["interval"]) * 1000) for song in songs]
        decision = match_decision(track, candidates)
        if decision.index is None:
            return None, None, None, decision
        index = decision.index
        return songs[index]["mid"], candidates[index], score(track, candidates[index]), None

    def _lyric_url(self, mid: str) -> str:
        query = urllib.parse.urlencode(
            {
                "callback": "MusicJsonCallback_lrc",
                "songmid": mid,
                "g_tk": "5381",
                "jsonpCallback": "MusicJsonCallback_lrc",
                "loginUin": "0",
                "hostUin": "0",
                "format": "jsonp",
                "inCharset": "utf8",
                "outCharset": "utf8",
                "notice": "0",
                "platform": "yqq",
                "needNewCode": "0",
            }
        )
        return f"https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?{query}"


class KugouProvider:
    name = "Kugou"

    def fetch(self, track: Track, started: float) -> ProviderResult:
        song, candidate, match_score, reject = self._song(track)
        if not song:
            return _matching_failed(self.name, started, reject or match_decision(track, []))
        query = urllib.parse.urlencode({"ver": "1", "man": "yes", "client": "pc", "keyword": f"{song['title']} {song['artist']}", "duration": str(song["duration"] * 1000), "hash": song["hash"]})
        payload = _json(_request(f"https://lyrics.kugou.com/search?{query}"))
        candidates = [
            Candidate(item["song"], [item["singer"]], int(item["duration"]))
            for item in payload.get("candidates", [])
        ]
        decision = match_decision(track, candidates)
        if decision.index is None:
            return _matching_failed(self.name, started, decision)
        index = decision.index
        lyric_meta = payload["candidates"][index]
        download_query = urllib.parse.urlencode({"ver": "1", "client": "pc", "id": lyric_meta["id"], "accesskey": lyric_meta["accesskey"], "fmt": "krc", "charset": "utf8"})
        download = _json(_request(f"https://lyrics.kugou.com/download?{download_query}"))
        if download.get("status") != 200 or not download.get("content"):
            return _failed(self.name, started, "no_lyrics_found")
        lines = parse_krc(_decrypt_krc(download["content"]))
        return _success(self.name, started, len(lines), candidate, match_score) if lines else _failed(self.name, started, "invalid_response")

    def _song(self, track: Track) -> tuple[dict | None, Candidate | None, int | None, MatchDecision | None]:
        query = urllib.parse.urlencode({"format": "json", "keyword": f"{track.title} {track.artist}", "page": "1", "pagesize": "20", "showtype": "1"})
        payload = _json(_request(f"http://mobilecdn.kugou.com/api/v3/search/song?{query}"))
        songs = []
        for item in (payload.get("data") or {}).get("info", []):
            songs.append(item)
            songs.extend(item.get("group") or [])
        candidates = [Candidate(song["songname"], [song["singername"]], int(song["duration"]) * 1000) for song in songs]
        decision = match_decision(track, candidates)
        if decision.index is None:
            return None, None, None, decision
        index = decision.index
        song = {"hash": songs[index]["hash"], "title": songs[index]["songname"], "artist": songs[index]["singername"], "duration": int(songs[index]["duration"])}
        return song, candidates[index], score(track, candidates[index]), None


class SodaProvider:
    name = "Soda"

    def __init__(self) -> None:
        self.device_id = "7381234567812345678"
        self.install_id = "7391234567812345678"

    def fetch(self, track: Track, started: float) -> ProviderResult:
        common = self._common()
        search_query = urllib.parse.urlencode(common | {"q": f"{track.title} {track.artist}", "cursor": "", "search_id": "", "search_method": "input"})
        payload = _json(_request(f"https://api.qishui.com/luna/pc/search/track?{search_query}", headers={"User-Agent": "LunaPC/2.1.0(12292405)", "Referer": "https://api.qishui.com/"}))
        tracks = [
            item["entity"]["track"]
            for group in payload.get("result_groups", [])
            for item in group.get("data", [])
            if item.get("meta", {}).get("item_type") == "track" and item.get("entity", {}).get("track")
        ]
        candidates = [Candidate(item["name"], [artist["name"] for artist in item.get("artists", [])], int(item["duration"])) for item in tracks]
        decision = match_decision(track, candidates)
        if decision.index is None:
            return _matching_failed(self.name, started, decision) if tracks else _failed(self.name, started, "no_lyrics_found")
        index = decision.index
        body = urllib.parse.urlencode({"track_id": tracks[index]["id"], "media_type": "track", "queue_type": ""}).encode()
        detail_query = urllib.parse.urlencode(common)
        detail = _json(_request(f"https://api.qishui.com/luna/pc/track_v2?{detail_query}", "POST", body, {"Content-Type": "application/x-www-form-urlencoded", "User-Agent": "LunaPC/2.1.0(12292405)", "Referer": "https://api.qishui.com/"}))
        lyric = detail.get("lyric")
        if not lyric:
            return _failed(self.name, started, "no_lyrics_found")
        lines = parse_krc(lyric["content"]) if lyric.get("type", "").lower() == "krc" else parse_lrc(lyric["content"])
        return _success(self.name, started, len(lines), candidates[index], score(track, candidates[index])) if lines else _failed(self.name, started, "invalid_response")

    def _common(self) -> dict[str, str]:
        return {
            "aid": "386088",
            "app_name": "luna_pc",
            "device_id": self.device_id,
            "install_id": self.install_id,
            "did": self.device_id,
            "iid": self.install_id,
            "device_platform": "PC",
            "device_type": "pc",
            "version_code": "2.1.0",
            "version_name": "2.1.0",
        }


def _decrypt_krc(encoded: str) -> str:
    encrypted = base64.b64decode(encoded)
    if len(encrypted) <= 4 or encrypted[:4] != b"krc1":
        raise ValueError("invalid KRC")
    key = bytes([0x40, 0x47, 0x61, 0x77, 0x5E, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2D, 0xCE, 0xD2, 0x6E, 0x69])
    compressed = bytes(value ^ key[index % len(key)] for index, value in enumerate(encrypted[4:]))
    return zlib.decompress(compressed).decode("utf-8-sig")


def _better_reject(current: MatchDecision | None, candidate: MatchDecision | None) -> MatchDecision | None:
    if candidate is None:
        return current
    if current is None:
        return candidate
    return candidate if (candidate.top_score or -1) > (current.top_score or -1) else current
