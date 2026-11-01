"""Regression checks for false-green results and bounded CI execution."""

import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("run_ci", Path(__file__).resolve().parents[1] / "tools/run_ci.py")
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class CIRunnerTests(unittest.TestCase):
    def check_command(self, code, **options):
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            result = ci.run_step("probe", [sys.executable, "-c", code], Path(directory), **options)
            self.assertTrue((Path(directory) / "probe.log").is_file())
            return result

    def test_complete_success(self):
        self.assertTrue(self.check_command("print('RESULT: PASS')", marker="RESULT: PASS", engine=True)["passed"])

    def test_nonzero_even_after_success_marker(self):
        self.assertFalse(self.check_command("print('RESULT: PASS'); raise SystemExit(1)", marker="RESULT: PASS")["passed"])

    def test_exit_zero_engine_error_is_failure(self):
        result = self.check_command("print('SCRIPT ERROR: broken'); print('RESULT: PASS')", engine=True, marker="RESULT: PASS")
        self.assertEqual(result["exit_code"], 0)
        self.assertIn("engine error in log", result["failures"])

    def test_missing_marker_cannot_pass(self):
        result = self.check_command("print('some tests ran')", marker="RESULT: PASS")
        self.assertIn("missing completion marker", result["failures"])

    def test_timeout_is_failure(self):
        result = self.check_command("import time; time.sleep(5)", timeout=0.1)
        self.assertIn("timeout", result["failures"])

    def test_ansi_error_is_detected(self):
        result = self.check_command("print('\\x1b[31mERROR: broken\\x1b[0m')", engine=True)
        self.assertIn("engine error in log", result["failures"])

    def test_gameplay_suites_are_registered_with_markers(self):
        steps = {name: (command, options) for name, command, options in ci.ci_steps("python3")}
        names = [name for name, _, _ in ci.ci_steps("python3")]
        for name, script in (("player-acceptance", "res://tests/test_player_movement.gd"),
                             ("interaction-acceptance", "res://tests/test_interaction.gd"),
                             ("inventory-acceptance", "res://tests/test_inventory.gd"),
                             ("gathering-acceptance", "res://tests/test_gathering.gd")):
            command, options = steps[name]
            self.assertIn(script, command)
            self.assertEqual(options, {"engine": True, "marker": "RESULT: PASS"})
            self.assertNotIn("--inject-failure", command)
        self.assertLess(names.index("player-acceptance"), names.index("interaction-acceptance"))
        self.assertLess(names.index("interaction-acceptance"), names.index("inventory-acceptance"))
        self.assertLess(names.index("inventory-acceptance"), names.index("gathering-acceptance"))
        self.assertEqual(names[-1], "source-tree-clean")

    def test_failed_suite_output_cannot_pass(self):
        # Mirrors an injected runner failure: exit 1, an ERROR line and no PASS marker.
        result = self.check_command("print('ERROR: FAIL AC-I12: deliberate'); print('RESULT: FAIL (1)'); raise SystemExit(1)",
                                    engine=True, marker="RESULT: PASS")
        self.assertEqual(set(result["failures"]), {"nonzero exit", "engine error in log", "missing completion marker"})


if __name__ == "__main__":
    unittest.main()
