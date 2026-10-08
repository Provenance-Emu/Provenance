"""Tests for maint.py: python3 -m unittest discover -s Scripts/maint -p 'test_*.py'"""
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import maint  # noqa: E402


class GlobTests(unittest.TestCase):
    def test_single_star_stays_in_one_segment(self):
        self.assertTrue(maint.matches_any("Scripts/a.py", ["Scripts/*.py"]))
        self.assertFalse(maint.matches_any("Scripts/x/a.py", ["Scripts/*.py"]))

    def test_double_star_crosses_segments(self):
        self.assertTrue(maint.matches_any("Cores/A/B/C/Core.plist", ["Cores/*/**/Core.plist"]))
        self.assertTrue(maint.matches_any("Cores/A/Core.plist", ["Cores/*/**/Core.plist"]))
        self.assertTrue(maint.matches_any("Scripts/x/y/z.swift", ["Scripts/x/**"]))

    def test_durations(self):
        self.assertEqual(maint.parse_duration("30d"), 30 * 86400)
        self.assertEqual(maint.parse_duration("2w"), 14 * 86400)
        self.assertEqual(maint.parse_duration("12h"), 12 * 3600)
        with self.assertRaises(ValueError):
            maint.parse_duration("soon")


class RepoTestCase(unittest.TestCase):
    """Runs against a throwaway git repo with its own Scripts/maint/jobs.toml."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.saved = {name: getattr(maint, name) for name in
                      ("REPO_ROOT", "STATE_DIR", "STATE_PATH", "LOG_DIR", "REGISTRY_PATH")}
        maint.REPO_ROOT = self.root
        maint.STATE_DIR = self.root / ".maint"
        maint.STATE_PATH = maint.STATE_DIR / "state.json"
        maint.LOG_DIR = maint.STATE_DIR / "logs"
        maint.REGISTRY_PATH = self.root / "jobs.toml"
        maint._needs_cache.clear()
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@example.com")
        self.git("config", "user.name", "Test")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", "/dev/null")
        (self.root / ".gitignore").write_text(".maint/\n")
        self.clock = 1_700_000_000

    def tearDown(self):
        for name, value in self.saved.items():
            setattr(maint, name, value)
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True, text=True,
                              capture_output=True).stdout

    def write(self, rel, text, mode=None):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if mode:
            path.chmod(mode)

    def commit(self, message="c", same_second=False):
        """Commits with increasing timestamps, or the previous one with same_second."""
        if not same_second:
            self.clock += 60
        env = dict(os.environ, GIT_AUTHOR_DATE=f"@{self.clock}", GIT_COMMITTER_DATE=f"@{self.clock}")
        subprocess.run(["git", "add", "-A"], cwd=self.root, check=True)
        subprocess.run(["git", "commit", "-q", "-m", message], cwd=self.root, check=True, env=env)

    def registry(self, toml):
        self.write("jobs.toml", textwrap.dedent(toml))
        return maint.load_registry(maint.REGISTRY_PATH)

    def status(self, registry, job_id):
        return maint.evaluate(registry.jobs[job_id], maint.load_state())


class StalenessTests(RepoTestCase):
    TOML = """
        [jobs.gen]
        title = "gen"
        run = ["python3", "gen.py"]
        mode = "auto"
        inputs = ["data/*.txt"]
        outputs = ["out.txt"]
        """

    def setUp(self):
        super().setUp()
        self.write("gen.py", "import pathlib\npathlib.Path('out.txt').write_text("
                             "pathlib.Path('data/a.txt').read_text().upper())\n")
        self.write("data/a.txt", "one")
        self.write("out.txt", "ONE")
        self.commit()

    def test_current_when_outputs_newer_than_inputs(self):
        self.assertEqual(self.status(self.registry(self.TOML), "gen").state, maint.CURRENT)

    def test_stale_when_input_changes_after_outputs(self):
        self.write("data/a.txt", "two")
        self.commit()
        status = self.status(self.registry(self.TOML), "gen")
        self.assertEqual(status.state, maint.STALE)
        self.assertIn("data/a.txt", status.reasons[0])

    def test_input_committed_in_the_same_second_is_still_newer(self):
        self.write("data/a.txt", "two")
        self.commit(same_second=True)
        self.assertEqual(self.status(self.registry(self.TOML), "gen").state, maint.STALE)

    def test_script_named_in_run_is_an_implicit_input(self):
        self.write("gen.py", self.root.joinpath("gen.py").read_text() + "# tweak\n")
        self.commit()
        status = self.status(self.registry(self.TOML), "gen")
        self.assertEqual(status.state, maint.STALE)
        self.assertIn("gen.py", status.reasons[0])

    def test_uncommitted_input_change_is_stale(self):
        self.write("data/a.txt", "dirty")
        status = self.status(self.registry(self.TOML), "gen")
        self.assertEqual(status.state, maint.STALE)
        self.assertIn("uncommitted", status.reasons[0])

    def test_running_the_job_clears_staleness(self):
        self.write("data/a.txt", "two")
        self.commit()
        registry = self.registry(self.TOML)
        result = maint.run_job(registry.jobs["gen"], emit=lambda line: None)
        self.assertEqual(result.exit_code, 0)
        self.assertEqual(result.changed, ["out.txt"])
        self.assertEqual((self.root / "out.txt").read_text(), "TWO")
        self.commit()
        self.assertEqual(self.status(registry, "gen").state, maint.CURRENT)

    def test_run_with_identical_output_still_counts(self):
        # Input commit changes nothing the generator reads differently.
        self.write("data/a.txt", "one")  # same content, but touch another input
        self.write("data/b.txt", "unused")
        self.commit()
        registry = self.registry(self.TOML)
        self.assertEqual(self.status(registry, "gen").state, maint.STALE)
        maint.run_job(registry.jobs["gen"], emit=lambda line: None)
        self.assertEqual(self.status(registry, "gen").state, maint.CURRENT)

    def test_discarded_regeneration_does_not_count(self):
        # Output was committed wrong; regenerating fixes it, then the fix is thrown away.
        self.write("out.txt", "WRONG")
        self.commit()
        self.write("data/a.txt", "one ")  # input changes after the bad output
        self.commit()
        registry = self.registry(self.TOML)
        maint.run_job(registry.jobs["gen"], emit=lambda line: None)
        self.assertIn("not committed", self.status(registry, "gen").reasons[0])
        self.git("checkout", "--", "out.txt")
        self.assertEqual(self.status(registry, "gen").state, maint.STALE)

    def test_dry_run_does_not_execute(self):
        self.write("data/a.txt", "two")
        self.commit()
        lines = []
        maint.run_job(self.registry(self.TOML).jobs["gen"], dry_run=True, emit=lines.append)
        self.assertEqual((self.root / "out.txt").read_text(), "ONE")
        self.assertTrue(any("gen.py" in line for line in lines))

    def test_outputs_never_committed(self):
        registry = self.registry(self.TOML.replace('"out.txt"', '"missing.txt"'))
        self.assertIn("never been committed", self.status(registry, "gen").reasons[0])


class MaxAgeAndCheckTests(RepoTestCase):
    def test_max_age_uses_output_commit_time(self):
        self.write("out.txt", "x")
        self.commit()  # committed in 2023 (fixed clock), so far older than 7 days
        registry = self.registry("""
            [jobs.old]
            title = "old"
            run = "true"
            outputs = ["out.txt"]
            max_age = "7d"
            """)
        status = self.status(registry, "old")
        self.assertEqual(status.state, maint.STALE)
        self.assertIn("limit 7d", status.reasons[0])

    def test_max_age_without_outputs_needs_a_local_run(self):
        self.write("x", "x")
        self.commit()
        registry = self.registry("""
            [jobs.fetch]
            title = "fetch"
            run = "true"
            max_age = "7d"
            """)
        self.assertIn("never run", self.status(registry, "fetch").reasons[0])
        maint.run_job(registry.jobs["fetch"], emit=lambda line: None)
        self.assertEqual(self.status(registry, "fetch").state, maint.CURRENT)

    def test_check_exit_codes(self):
        self.write("x", "x")
        self.commit()
        registry = self.registry("""
            [jobs.ok]
            title = "ok"
            check = "echo all good; exit 0"
            [jobs.behind]
            title = "behind"
            check = "echo noise; echo 3 things behind; exit 1"
            [jobs.broken]
            title = "broken"
            check = "echo boom; exit 2"
            [jobs.pattern]
            title = "pattern"
            check = "echo 'CHECK: 5 missing'; echo trailing detail; exit 1"
            reason_pattern = "^CHECK:"
            """)
        self.assertEqual(self.status(registry, "ok").state, maint.CURRENT)
        behind = self.status(registry, "behind")
        self.assertEqual((behind.state, behind.reasons), (maint.STALE, ["3 things behind"]))
        self.assertEqual(self.status(registry, "broken").state, maint.ERROR)
        self.assertEqual(self.status(registry, "pattern").reasons, ["CHECK: 5 missing"])

    def test_check_results_are_cached(self):
        self.write("x", "x")
        self.commit()
        marker = self.root / "ran"
        registry = self.registry(f"""
            [jobs.c]
            title = "c"
            check = "echo x >> '{marker}'; exit 0"
            """)
        self.status(registry, "c")
        self.status(registry, "c")
        self.assertEqual(marker.read_text().count("x"), 1)

    def test_unmet_needs_block_checks_and_runs(self):
        self.write("x", "x")
        self.commit()
        registry = self.registry("""
            [jobs.secret]
            title = "secret"
            run = "true"
            check = "exit 1"
            needs = ["env:MAINT_TEST_SURELY_UNSET"]
            """)
        status = self.status(registry, "secret")
        self.assertEqual(status.blocked, ["$MAINT_TEST_SURELY_UNSET not set"])
        self.assertEqual(status.state, maint.CURRENT)  # check skipped, nothing known stale


class RegistryTests(RepoTestCase):
    def test_unregistered_scripts(self):
        self.write("Scripts/gen/a.py", "")
        self.write("Scripts/gen/b.sh", "")
        self.write("Scripts/gen/helper.py", "")
        self.write("Scripts/ci/c.sh", "")
        self.write("Scripts/gen/data.json", "{}")
        self.write("Scripts/gen/__pycache__/a.cpython.py", "")
        registry = self.registry("""
            [scan]
            roots = ["Scripts"]
            extensions = [".py", ".sh"]
            skip_dirs = ["__pycache__"]
            [ignore]
            paths = ["Scripts/ci/*.sh"]
            [jobs.a]
            title = "a"
            run = ["python3", "Scripts/gen/a.py"]
            files = ["Scripts/gen/helper.py"]
            """)
        self.assertEqual(maint.unregistered_scripts(registry), ["Scripts/gen/b.sh"])
        self.assertIn('run = "Scripts/gen/b.sh"', maint.job_stub("Scripts/gen/b.sh"))

    def test_rejects_unknown_keys_and_bad_modes(self):
        with self.assertRaises(ValueError):
            self.registry('[jobs.x]\ntitle = "x"\nrunn = "true"\n')
        with self.assertRaises(ValueError):
            self.registry('[jobs.x]\ntitle = "x"\nrun = "true"\nmode = "sometimes"\n')
        with self.assertRaises(ValueError):
            self.registry('[jobs.x]\ntitle = "x"\nmode = "auto"\n')

    def test_on_demand_job_has_no_rules(self):
        self.write("x", "x")
        self.commit()
        registry = self.registry('[jobs.x]\ntitle = "x"\nrun = "true"\n')
        self.assertEqual(self.status(registry, "x").state, maint.ON_DEMAND)

    def test_non_executable_script_runs_through_interpreter(self):
        self.write("tool.sh", "echo hi\n", mode=0o644)
        self.assertEqual(maint.shell_command(["tool.sh", "--x"]), ["bash", "tool.sh", "--x"])
        self.assertEqual(maint.shell_command("echo", ["a b"])[-1], "a b")

    def test_report_lists_stale_and_unregistered(self):
        self.write("data.txt", "1")
        self.write("out.txt", "1")
        self.commit()
        self.write("data.txt", "2")
        self.commit()
        self.write("Scripts/orphan.py", "")
        registry = self.registry("""
            [scan]
            roots = ["Scripts"]
            [jobs.gen]
            title = "Gen"
            run = "true"
            inputs = ["data.txt"]
            outputs = ["out.txt"]
            """)
        report = maint.markdown_report(maint.evaluate_all(registry),
                                       maint.unregistered_scripts(registry), manual_only=False)
        self.assertIn("`gen` — Gen", report)
        self.assertIn("Scripts/orphan.py", report)


class RealRegistryTests(unittest.TestCase):
    def test_repo_registry_loads_and_names_real_files(self):
        registry = maint.load_registry()
        missing = []
        for job in registry.jobs.values():
            for command in (job.run, job.check):
                if isinstance(command, list):
                    first = command[0]
                    if "/" in first and not (maint.REPO_ROOT / first).exists():
                        missing.append(f"{job.id}: {first}")
                    for arg in command[1:]:
                        if arg.endswith((".py", ".sh")) and not (maint.REPO_ROOT / arg).exists():
                            missing.append(f"{job.id}: {arg}")
        for path in registry.ignore:
            if "*" not in path and not (maint.REPO_ROOT / path).exists():
                missing.append(f"[ignore] {path}")
        self.assertEqual(missing, [])

    def test_every_script_in_repo_is_registered(self):
        self.assertEqual(maint.unregistered_scripts(maint.load_registry()), [])


class ServerTests(unittest.TestCase):
    def test_rejects_foreign_host_and_missing_token(self):
        import http.client
        import threading
        from http.server import ThreadingHTTPServer

        import server

        httpd = ThreadingHTTPServer(("127.0.0.1", 0), server.make_handler("tok", 0, server.Runner()))
        port = httpd.server_address[1]
        httpd.RequestHandlerClass = server.make_handler("tok", port, server.Runner())
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        try:
            def request(method, path, host, headers=None, body=None):
                conn = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                conn.putrequest(method, path, skip_host=True)
                conn.putheader("Host", host)
                for key, value in (headers or {}).items():
                    conn.putheader(key, value)
                data = json.dumps(body or {}).encode()
                conn.putheader("Content-Length", str(len(data)))
                conn.endheaders(data)
                response = conn.getresponse()
                result = (response.status, response.read())
                conn.close()
                return result

            self.assertEqual(request("GET", "/", "evil.example:80")[0], 403)
            self.assertEqual(request("POST", "/api/run", f"127.0.0.1:{port}", body={"job": "x"})[0], 403)
            bad_job = request("POST", "/api/run", f"127.0.0.1:{port}", {"X-Maint-Token": "tok"}, {"job": "nope"})
            self.assertEqual(bad_job[0], 400)
            release = request("POST", "/api/run", f"127.0.0.1:{port}", {"X-Maint-Token": "tok"}, {"job": "release"})
            self.assertEqual(release[0], 403)  # cli_only: never one-click from the page
            status, page = request("GET", "/", f"localhost:{port}")
            self.assertEqual(status, 200)
            self.assertIn(b'"tok"', page)
        finally:
            httpd.shutdown()
            httpd.server_close()

    def test_bind_server_skips_a_port_in_use(self):
        import socket

        import server

        with socket.socket() as busy:
            busy.bind(("127.0.0.1", 0))
            busy.listen()
            taken = busy.getsockname()[1]
            httpd = server.bind_server(taken, "tok", server.Runner())
            try:
                self.assertIsNotNone(httpd)
                self.assertGreater(httpd.server_address[1], taken)
            finally:
                httpd.server_close()


if __name__ == "__main__":
    unittest.main()
