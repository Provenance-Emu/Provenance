"""Local web dashboard for maint.py (`python3 Scripts/maint/maint.py serve`).

Serves dashboard.html plus a small JSON API on 127.0.0.1 only. Runs are limited
to jobs named in jobs.toml, one at a time, and every POST must carry the token
embedded in the page, so another site open in the browser cannot start a job.
"""
from __future__ import annotations

import errno
import json
import secrets
import subprocess
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import maint

DASHBOARD = Path(__file__).resolve().parent / "dashboard.html"
MAX_LOG_LINES = 20_000
PORT_ATTEMPTS = 20  # serve() tries --port, then the next ports up


class RunBuffer:
    def __init__(self, job_id: str, dry_run: bool):
        self.job_id = job_id
        self.dry_run = dry_run
        self.lines: list[str] = []
        self.running = True
        self.result: dict | None = None
        self.started = time.time()

    def emit(self, line: str) -> None:
        if len(self.lines) < MAX_LOG_LINES:
            self.lines.append(line)


class Runner:
    """Runs one job at a time so changed-file attribution stays correct."""

    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.buffers: dict[str, RunBuffer] = {}
        self.busy_with: str | None = None

    def start(self, job_ids: list[str], dry_run: bool) -> str | None:
        """Returns an error message, or None when the run started."""
        with self.lock:
            if self.busy_with:
                return f"{self.busy_with} is still running"
            self.busy_with = job_ids[0]
            for job_id in job_ids:
                self.buffers[job_id] = RunBuffer(job_id, dry_run)
        threading.Thread(target=self._run, args=(job_ids, dry_run), daemon=True).start()
        return None

    def _run(self, job_ids: list[str], dry_run: bool) -> None:
        try:
            registry = maint.load_registry()
            for job_id in job_ids:
                with self.lock:
                    self.busy_with = job_id
                buffer = self.buffers[job_id]
                try:
                    result = maint.run_job(registry.jobs[job_id], dry_run=dry_run, emit=buffer.emit,
                                           interactive=False)
                    buffer.result = {"exit": result.exit_code, "duration": round(result.duration, 1),
                                     "changed": result.changed}
                except Exception as error:  # surface any failure in the job's log
                    buffer.emit(f"maint: {error}")
                    buffer.result = {"exit": -1, "duration": 0, "changed": []}
                finally:
                    buffer.running = False
        finally:
            with self.lock:
                self.busy_with = None


def repo_info() -> dict:
    def git(*args: str) -> str:
        return subprocess.run(["git", *args], cwd=maint.REPO_ROOT, text=True,
                              capture_output=True).stdout.strip()

    return {
        "root": str(maint.REPO_ROOT),
        "branch": git("branch", "--show-current"),
        "head": git("log", "-1", "--format=%h %s"),
        "dirty": bool(git("status", "--porcelain")),
    }


def make_handler(token: str, port: int, runner: Runner):
    allowed_hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}

    class Handler(BaseHTTPRequestHandler):
        server_version = "maint/1"

        def log_message(self, fmt: str, *args) -> None:  # keep the terminal quiet
            pass

        def _send(self, code: int, body: bytes, content_type: str) -> None:
            self.send_response(code)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _json(self, code: int, payload) -> None:
            self._send(code, json.dumps(payload).encode(), "application/json")

        def _host_ok(self) -> bool:
            # Blocks DNS-rebinding: only our own host:port may talk to us.
            if self.headers.get("Host") not in allowed_hosts:
                self._json(403, {"error": "bad host"})
                return False
            return True

        def do_GET(self) -> None:
            if not self._host_ok():
                return
            url = urlparse(self.path)
            query = parse_qs(url.query)
            if url.path == "/":
                html = DASHBOARD.read_text().replace("__MAINT_TOKEN__", token)
                self._send(200, html.encode(), "text/html; charset=utf-8")
            elif url.path == "/api/status":
                registry = maint.load_registry()
                statuses = maint.evaluate_all(
                    registry,
                    run_checks=query.get("checks", ["1"])[0] == "1",
                    refresh=query.get("refresh", ["0"])[0] == "1",
                )
                self._json(200, {
                    "repo": repo_info(),
                    "jobs": [status.to_json() for status in statuses],
                    "unregistered": [{"path": path, "stub": maint.job_stub(path)}
                                     for path in maint.unregistered_scripts(registry)],
                    "busy": runner.busy_with,
                })
            elif url.path.startswith("/api/run/"):
                job_id = url.path.rsplit("/", 1)[-1]
                buffer = runner.buffers.get(job_id)
                if buffer is None:
                    log = maint.LOG_DIR / f"{job_id}.log"
                    lines = log.read_text(errors="replace").splitlines() if log.exists() else []
                    self._json(200, {"running": False, "lines": lines, "offset": len(lines),
                                     "result": None, "from_log": True})
                    return
                offset = int(query.get("offset", ["0"])[0])
                self._json(200, {"running": buffer.running, "lines": buffer.lines[offset:],
                                 "offset": len(buffer.lines), "result": buffer.result,
                                 "dry_run": buffer.dry_run})
            else:
                self._json(404, {"error": "not found"})

        def do_POST(self) -> None:
            if not self._host_ok():
                return
            if not secrets.compare_digest(self.headers.get("X-Maint-Token", ""), token):
                self._json(403, {"error": "bad token — reload the page"})
                return
            length = int(self.headers.get("Content-Length", "0"))
            try:
                body = json.loads(self.rfile.read(length) or b"{}")
            except ValueError:
                self._json(400, {"error": "bad json"})
                return
            registry = maint.load_registry()
            if self.path == "/api/run":
                job_id = body.get("job")
                job = registry.jobs.get(job_id)
                if job is None or job.run is None:
                    self._json(400, {"error": f"{job_id} is not a runnable job"})
                    return
                if job.cli_only and not body.get("dry_run"):
                    self._json(403, {"error": f"{job_id} only runs from the terminal"})
                    return
                blocked = maint.unmet_needs(job)
                if blocked:
                    self._json(409, {"error": f"can't run here: {', '.join(blocked)}"})
                    return
                error = runner.start([job_id], dry_run=bool(body.get("dry_run")))
            elif self.path == "/api/run-stale":
                statuses = maint.evaluate_all(registry, run_checks=False)
                ids = [s.job.id for s in statuses if s.state == maint.STALE and s.job.run
                       and not s.blocked and not s.job.cli_only
                       and (s.job.mode == "auto" or not body.get("auto_only", True))]
                if not ids:
                    self._json(200, {"started": []})
                    return
                error = runner.start(ids, dry_run=False)
                if not error:
                    self._json(202, {"started": ids})
                    return
            else:
                self._json(404, {"error": "not found"})
                return
            if error:
                self._json(409, {"error": error})
            else:
                self._json(202, {"started": [job_id]})

    return Handler


def bind_server(port: int, token: str, runner: Runner) -> ThreadingHTTPServer | None:
    """Binds the first free port from `port` up, or returns None if all are taken."""
    for candidate in range(port, port + PORT_ATTEMPTS):
        try:
            return ThreadingHTTPServer(("127.0.0.1", candidate), make_handler(token, candidate, runner))
        except OSError as error:
            if error.errno != errno.EADDRINUSE:
                raise
    return None


def serve(port: int, open_browser: bool = True) -> int:
    token = secrets.token_urlsafe(24)
    server = bind_server(port, token, Runner())
    if server is None:
        print(f"maint: ports {port}-{port + PORT_ATTEMPTS - 1} are all in use; pass --port")
        return 1
    if server.server_address[1] != port:
        print(f"maint: port {port} is in use, using {server.server_address[1]}")
    port = server.server_address[1]
    url = f"http://127.0.0.1:{port}/"
    print(f"maint dashboard: {url}  (Ctrl-C to stop)")
    if open_browser:
        threading.Timer(0.3, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()
    finally:
        server.server_close()
    return 0
