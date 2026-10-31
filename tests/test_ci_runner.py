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


if __name__ == "__main__":
    unittest.main()
