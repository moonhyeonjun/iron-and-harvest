"""The launcher must not silently select an incompatible engine."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("launcher", Path(__file__).resolve().parents[1] / "tools/godot.py")
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class GodotLauncherTests(unittest.TestCase):
    def test_exact_stable_standard_build(self):
        self.assertTrue(launcher.matches_version("4.7.2.stable.official.ed1daf0bf\n", "4.7.2"))

    def test_wrong_patch_prerelease_and_mono_rejected(self):
        for actual in ("4.4.1.stable.official.49a5bc7b6", "4.7.2.rc1.official.abc123", "4.7.2.stable.mono.official.abc123", "4.7.2.stable.custom_build.abc123"):
            with self.subTest(actual=actual):
                self.assertFalse(launcher.matches_version(actual, "4.7.2"))

    def test_invalid_explicit_override_does_not_fall_back(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "Not found"):
                launcher.find_engine("4.7.2", str(Path(directory) / "missing"))

    def test_existing_override_with_wrong_version_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Godot"
            path.touch()
            result = subprocess.CompletedProcess([], 0, "4.4.1.stable.official.49a5bc7b6", "")
            with patch.object(launcher.subprocess, "run", return_value=result):
                with self.assertRaisesRegex(RuntimeError, "Version rejected"):
                    launcher.find_engine("4.7.2", str(path))

    def test_project_override_rejected_before_launch(self):
        with patch.object(launcher, "find_engine") as find:
            self.assertEqual(launcher.main(["--path", "/another/project"]), 2)
            find.assert_not_called()


if __name__ == "__main__":
    unittest.main()
