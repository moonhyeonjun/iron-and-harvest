"""Regression tests for actual path/management mistakes the validator must catch."""

import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("foundation", Path(__file__).resolve().parents[1] / "tools/validate_foundation.py")
foundation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(foundation)


class FoundationValidationTests(unittest.TestCase):
    def test_missing_main_scene_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "game").mkdir()
            (root / "game/project.godot").write_text('config_version=5\nrun/main_scene="res://missing.tscn"\n')
            self.assertTrue(any("Missing resource" in e for e in foundation.resource_errors(root)))

    def test_resource_cannot_escape_game_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "game").mkdir()
            (root / "outside.tscn").write_text('[gd_scene format=3]\n')
            (root / "game/project.godot").write_text('config_version=5\nrun/main_scene="res://../outside.tscn"\n')
            self.assertTrue(any("escapes" in e for e in foundation.resource_errors(root)))

    def test_valid_scene_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "game").mkdir()
            (root / "game/main.tscn").write_text('[gd_scene format=3]\n[node name="Root" type="Node"]\n')
            (root / "game/project.godot").write_text('config_version=5\nrun/main_scene="res://main.tscn"\n')
            self.assertEqual(foundation.resource_errors(root), [])

    def test_broken_live_link_but_archived_original_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "archive").mkdir()
            (root / "archive/old.md").write_text('[old](missing.md)')
            self.assertEqual(foundation.markdown_errors(root), [])
            (root / "README.md").write_text('[live](missing.md)')
            self.assertEqual(len(foundation.markdown_errors(root)), 1)

    def test_task_cycle_and_missing_dependency_are_reported(self):
        text = '\n'.join([
            '| IH-001 | A | feature | priority:high | status:backlog | IH-002 |',
            '| IH-002 | B | feature | priority:high | status:backlog | IH-001, IH-999 |',
            '## IH-001 — A', '## IH-002 — B',
        ])
        errors = foundation.task_errors(text)
        self.assertTrue(any('Cyclic' in e for e in errors))
        self.assertTrue(any('Missing dependency' in e for e in errors))

    def test_valid_dependency_graph(self):
        text = '\n'.join([
            '| IH-001 | A | documentation | priority:high | status:review | 없음 |',
            '| IH-002 | B | feature | priority:medium | status:backlog | IH-001 |',
            '## IH-001 — A', '## IH-002 — B',
        ])
        self.assertEqual(foundation.task_errors(text), [])


if __name__ == "__main__":
    unittest.main()
