#!/usr/bin/env python3
"""Capture App Store screenshots from a running Provenance over the LAN.

Drives the `/api/debug/*` routes (PVUIBase `PVDebugAPIRoutes`) on a physical
iPhone / iPad / Apple TV or a simulator:

  1. waits for the library to finish booting,
  2. turns on screenshot-safe (pixel-mosaic) covers and grabs the library,
  3. boots each 240p Test Suite ROM in the library, cycles the Metal shaders,
     and saves a PNG per (game, shader),
  4. restores the shader / pixelate settings it changed.

The debug API is always on in DEBUG builds; Release builds need Settings >
Advanced > About (secret unlock) > Debug API & Screenshots > Enable Debug API.
Stdlib only.

Examples:
  # Simulator (port 8080), ROMs already imported
  Scripts/capture_device_screenshots.py --host localhost

  # Device on the LAN, upload the 240p ROMs first, password-protected API
  Scripts/capture_device_screenshots.py --host 192.168.1.42 --password hunter2 \\
      --upload ~/roms/240p/*.{md,sfc,nes,pce,gba,gb}
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

DEFAULT_SHADERS = ["none", "complexCRT", "lcd"]


class DebugAPI:
    def __init__(self, base: str, password: str | None, timeout: float = 15.0):
        self.base = base.rstrip("/")
        self.timeout = timeout
        self.headers: dict[str, str] = {}
        if password:
            token = base64.b64encode(f"Provenance:{password}".encode()).decode()
            self.headers["Authorization"] = f"Basic {token}"

    def _request(self, method: str, path: str, query: dict | None = None,
                 body: bytes | None = None, content_type: str | None = None) -> tuple[int, str, bytes]:
        url = self.base + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        headers = dict(self.headers)
        if content_type:
            headers["Content-Type"] = content_type
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return resp.status, resp.headers.get("Content-Type", ""), resp.read()
        except urllib.error.HTTPError as err:
            return err.code, err.headers.get("Content-Type", ""), err.read()

    def get(self, path: str, **query) -> dict:
        return self._json(*self._request("GET", path, query or None))

    def post(self, path: str, payload: dict | None = None, **query) -> dict:
        body = json.dumps(payload or {}).encode()
        return self._json(*self._request("POST", path, query or None, body, "application/json"))

    def screenshot(self, source: str = "window") -> bytes:
        status, ctype, body = self._request("GET", "/api/debug/screenshot", {"source": source})
        if status != 200 or not ctype.startswith("image/png"):
            raise RuntimeError(f"screenshot failed ({status}): {body[:200]!r}")
        return body

    def upload(self, path: Path) -> None:
        boundary = uuid.uuid4().hex
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="files[]"; filename="{path.name}"\r\n'
            "Content-Type: application/octet-stream\r\n\r\n"
        ).encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
        status, _, resp = self._request("POST", "/upload", None, body,
                                        f"multipart/form-data; boundary={boundary}")
        if status >= 300:
            raise RuntimeError(f"upload {path.name} failed ({status}): {resp[:200]!r}")

    @staticmethod
    def _json(status: int, _ctype: str, body: bytes) -> dict:
        try:
            data = json.loads(body or b"{}")
        except json.JSONDecodeError:
            data = {"ok": False, "error": body[:200].decode(errors="replace")}
        if status == 401:
            sys.exit("401 unauthorized — pass --password (username is 'Provenance')")
        data.setdefault("_status", status)
        return data


def wait_for(predicate, timeout: float, interval: float = 1.0, what: str = "condition"):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            last = predicate()
            if last:
                return last
        except (urllib.error.URLError, ConnectionError, TimeoutError) as err:
            last = err
        time.sleep(interval)
    raise TimeoutError(f"timed out waiting for {what} (last: {last!r})")


def slug(text: str) -> str:
    return "".join(c if c.isalnum() else "-" for c in text.lower()).strip("-").replace("--", "-")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="localhost", help="device IP / hostname (default: localhost = simulator)")
    parser.add_argument("--port", type=int, help="HTTP port (default: 8080 for localhost, 80 for a device)")
    parser.add_argument("--password", help="debug API Basic-auth password, if enabled on the device")
    parser.add_argument("--out", type=Path, default=Path("screenshots/device"), help="output directory")
    parser.add_argument("--query", default="240p", help="library title filter for games to boot (default: 240p)")
    parser.add_argument("--systems", nargs="*", help="only boot games whose system identifier contains one of these")
    parser.add_argument("--max-games", type=int, default=4, help="boot at most this many games (default: 4)")
    parser.add_argument("--shaders", nargs="*", default=DEFAULT_SHADERS,
                        help=f"Metal filters to cycle per game (default: {' '.join(DEFAULT_SHADERS)})")
    parser.add_argument("--settle", type=float, default=6.0, help="seconds to let a game run before capturing")
    parser.add_argument("--upload", nargs="*", type=Path, default=[], help="ROM files to upload first")
    parser.add_argument("--no-pixelate", action="store_true", help="leave library covers as-is")
    parser.add_argument("--game-source", action="store_true",
                        help="also save the emulator's own frame capture (screenshot?source=game)")
    args = parser.parse_args()

    port = args.port or (8080 if args.host in ("localhost", "127.0.0.1", "::1") else 80)
    api = DebugAPI(f"http://{args.host}:{port}", args.password)
    args.out.mkdir(parents=True, exist_ok=True)

    def save(name: str, png: bytes) -> None:
        path = args.out / f"{name}.png"
        path.write_bytes(png)
        print(f"  saved {path} ({len(png) // 1024} KB)")

    print(f"Provenance debug API at {api.base}")
    status = wait_for(lambda: (s := api.get("/api/debug/status")).get("ok") and s["data"].get("bootupCompleted") and s,
                      timeout=180, what="library bootup")["data"]
    original_shader = status.get("shader", "None")
    original_pixelate = status.get("pixelateLibraryArtwork", False)

    if status.get("game"):
        print(f"exiting running game {status['game'].get('title')!r}")
        api.post("/api/debug/exit")
        wait_for(lambda: "game" not in api.get("/api/debug/status")["data"], timeout=30, what="game exit")

    if args.upload:
        before = api.get("/api/debug/library")["data"]["count"]
        for rom in args.upload:
            print(f"uploading {rom.name}")
            api.upload(rom)
        wait_for(lambda: api.get("/api/debug/library")["data"]["count"] >= before + len(args.upload),
                 timeout=120, interval=2, what="uploaded ROMs to import")

    # Library shot.
    if not args.no_pixelate:
        api.post("/api/debug/pixelate", {"enabled": True})
    api.post("/api/debug/navigate", url="provenance://screen/library")
    time.sleep(3)
    print("library")
    save("01-library", api.screenshot())

    games = api.get("/api/debug/library", q=args.query)["data"]["games"]
    if args.systems:
        games = [g for g in games if any(s.lower() in g["system"].lower() for s in args.systems)]
    games = games[: args.max_games]
    if not games:
        print(f"no games matching {args.query!r} in the library — import the 240p Test Suite ROMs (--upload)")

    index = 2
    try:
        for game in games:
            print(f"boot {game['title']} [{game['system']}]")
            resp = api.post("/api/debug/boot", {"md5": game["md5"]})
            if not resp.get("ok"):
                print(f"  boot refused: {resp.get('error')}")
                continue
            wait_for(lambda: (api.get("/api/debug/status")["data"].get("core") or {}).get("running"),
                     timeout=60, what=f"{game['title']} to start")
            time.sleep(args.settle)
            system = game["system"].split(".")[-1]
            for shader in args.shaders:
                resp = api.post("/api/debug/shader", {"filter": shader})
                if not resp.get("ok"):
                    print(f"  shader {shader}: {resp.get('error')}")
                    continue
                time.sleep(1.5)
                name = f"{index:02d}-{system}-{slug(game['title'])}-{shader}"
                save(name, api.screenshot())
                if args.game_source:
                    save(name + "-frame", api.screenshot("game"))
                index += 1
            api.post("/api/debug/exit")
            wait_for(lambda: "game" not in api.get("/api/debug/status")["data"], timeout=30, what="game exit")
            time.sleep(2)
    finally:
        filter_name = "none"
        if original_shader.startswith("Always(") and original_shader.endswith(")"):
            filter_name = original_shader[len("Always("):-1]
        if not original_shader.startswith("Auto("):
            api.post("/api/debug/shader", {"filter": filter_name})
        api.post("/api/debug/pixelate", {"enabled": bool(original_pixelate)})

    print(f"done — {index - 1} screenshots in {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
