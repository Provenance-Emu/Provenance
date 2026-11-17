#!/usr/bin/env python3
"""Unit tests for audit_controls: the --check mode and the submodule guard."""

import contextlib
import importlib.util
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[1] / "audits" / "audit_controls.py"
_spec = importlib.util.spec_from_file_location("audit_controls", _SCRIPT)
audit = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
# The module's dataclasses resolve their annotations through sys.modules.
sys.modules["audit_controls"] = audit
_spec.loader.exec_module(audit)

BRIDGE = "Cores/Toy/Sources/PVToyBridge/PVToyBridge.m"
SUBMODULE_BRIDGE = "Cores/Vendored/Sources/PVVendoredBridge/PVVendoredBridge.m"


def bridge(a_source: str, save_state_body: str = "return YES;") -> str:
    """A bridge binding two buttons on an extended gamepad, plus unrelated code."""
    return f"""
- (BOOL)saveStateToFileAtPath:(NSString *)path {{ {save_state_body} }}

- (NSInteger)controllerStateForPlayer:(NSInteger)player button:(PVToyButton)button {{
    if ([controller extendedGamepad]) {{
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        switch (button) {{
            case PVToyButtonA:
                return [[gamepad {a_source}] isPressed];
            case PVToyButtonStart:
                return [[gamepad buttonMenu] isPressed];
            default:
                break;
        }}
    }}
    return 0;
}}
"""


class AuditControlsTests(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.saved_root = audit.REPO_ROOT
        audit.REPO_ROOT = self.root
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        self.write(BRIDGE, bridge("buttonA"))

    def tearDown(self):
        audit.REPO_ROOT = self.saved_root
        self.tmp.cleanup()

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_audit(self, *args: str) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = audit.main(list(args))
        return code, out.getvalue()

    def report(self) -> str:
        return (self.root / audit.REPORT_PATH).read_text()

    def test_writes_the_report(self):
        code, _ = self.run_audit()
        self.assertEqual(code, 0)
        self.assertIn("### Toy", self.report())
        self.assertIn("| A | buttonA |", self.report())

    def test_check_passes_on_a_fresh_report_and_writes_nothing(self):
        self.run_audit()
        before = self.report()
        code, output = self.run_audit("--check")
        self.assertEqual(code, audit.CHECK_CURRENT)
        self.assertIn("matches a fresh audit", output)
        self.assertEqual(self.report(), before)

    # The case the maintenance report kept warning about: a bridge file changes,
    # but not in a way that moves a button.
    def test_a_change_that_moves_no_button_leaves_the_check_passing(self):
        self.run_audit()
        self.write(BRIDGE, bridge("buttonA", save_state_body="[self flush]; return YES;"))
        self.assertEqual(self.run_audit("--check")[0], audit.CHECK_CURRENT)

    def test_check_fails_when_a_mapping_changed_and_names_the_system(self):
        self.run_audit()
        before = self.report()
        self.write(BRIDGE, bridge("buttonB"))
        code, output = self.run_audit("--check")
        self.assertEqual(code, audit.CHECK_STALE)
        self.assertIn("2 line(s) differ", output)
        self.assertIn("(Toy)", output)
        self.assertEqual(self.report(), before)

    def test_check_fails_when_there_is_no_report_yet(self):
        self.assertEqual(self.run_audit("--check")[0], audit.CHECK_STALE)

    def test_no_bridge_files_is_an_error_not_a_stale_report(self):
        (self.root / BRIDGE).unlink()
        self.assertEqual(self.run_audit("--check")[0], audit.CANNOT_AUDIT)
        self.assertEqual(self.run_audit()[0], 1)

    def test_a_listed_file_in_a_submodule_that_is_not_checked_out_stops_the_audit(self):
        self.write(SUBMODULE_BRIDGE, bridge("buttonX").replace("PVToy", "PVVendored"))
        self.run_audit()
        self.assertIn(SUBMODULE_BRIDGE, self.report())
        before = self.report()
        # The submodule is declared but its folder is empty, as in a CI checkout.
        self.write(".gitmodules", '[submodule "Cores/Vendored"]\n\tpath = Cores/Vendored\n\turl = https://example.invalid/v.git\n')
        (self.root / SUBMODULE_BRIDGE).unlink()
        for mode in ((), ("--check",)):
            code, output = self.run_audit(*mode)
            self.assertEqual(code, audit.CANNOT_AUDIT)
            self.assertIn("submodule is not checked out", output)
        self.assertEqual(self.report(), before)

    def test_a_listed_file_deleted_from_the_repo_is_an_ordinary_change(self):
        self.write("Cores/Gone/Sources/PVGoneBridge/PVGoneBridge.m", bridge("buttonY").replace("PVToy", "PVGone"))
        self.run_audit()
        (self.root / "Cores/Gone/Sources/PVGoneBridge/PVGoneBridge.m").unlink()
        code, output = self.run_audit("--check")
        self.assertEqual(code, audit.CHECK_STALE)
        self.assertIn("(Gone)", output)
        self.assertEqual(self.run_audit()[0], 0)
        self.assertNotIn("### Gone", self.report())


if __name__ == "__main__":
    unittest.main()
