"""Validate repository contracts; this is not a Godot parser or runtime test."""

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = {
    "00-overview": "PROJECT_OVERVIEW GAME_VISION ROADMAP",
    "01-game-design": "GDD GAME_LOOP LIFE_SYSTEM ESTATE_MANAGEMENT ECONOMY_SYSTEM CHARACTER_SYSTEM ITEM_SYSTEM COMBAT_SYSTEM WORLD_SYSTEM",
    "02-technical-design": "TDD ARCHITECTURE DATA_MODEL SAVE_SYSTEM PERFORMANCE TOOLCHAIN",
    "03-development": "MILESTONES TASKS WEEKLY_LOG BUGS",
    "05-art": "ART_GUIDE ASSET_LIST",
}
REQUIRED = [
    "README.md", "CLAUDE.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE",
    ".gitignore", ".gitattributes", "game/project.godot",
    "game/scenes/foundation.tscn", ".github/PULL_REQUEST_TEMPLATE.md",
    "docs/04-decisions/ADR/README.md",
]
REQUIRED += [f"docs/{folder}/{name}.md" for folder, names in DOCS.items() for name in names.split()]
REQUIRED += [f".claude/rules/{name}.md" for name in ("architecture", "coding-standards", "git-workflow", "testing")]
REQUIRED += [f".github/ISSUE_TEMPLATE/{name}.md" for name in ("feature_request", "bug_report", "tech_task")]


def resource_errors(root):
    errors = []
    game = (root / "game").resolve()
    config = game / "project.godot"
    if not config.exists():
        return ["Missing game/project.godot"]
    if (root / "project.godot").exists():
        errors.append("Unexpected second Godot root at repository root")
    text = config.read_text()
    if not re.search(r"^config_version=5$", text, re.M):
        errors.append("Expected Godot 4 family config_version=5")
    if not re.search(r'^run/main_scene="res://[^\"]+"$', text, re.M):
        errors.append("Main scene must use res://")
    candidates = [config] + list(game.rglob("*.tscn")) + list(game.rglob("*.tres"))
    for source in candidates:
        if ".godot" in source.relative_to(game).parts:
            continue
        for match in re.findall(r'"res://([^\"]+)"', source.read_text()):
            target = (game / match).resolve()
            try:
                target.relative_to(game)
            except ValueError:
                errors.append(f"Resource escapes game/: {match}")
                continue
            if not target.is_file():
                errors.append(f"Missing resource: {match}")
                continue
            current = game
            for part in Path(match).parts:
                if part not in {p.name for p in current.iterdir()}:
                    errors.append(f"Resource case mismatch: {match}")
                    break
                current /= part
    return errors


def markdown_errors(root):
    errors = []
    for path in root.rglob("*.md"):
        parts = path.relative_to(root).parts
        if ".git" in parts or ".godot" in parts or "archive" in parts:
            continue  # Archived originals deliberately retain historical paths.
        text = path.read_text()
        if len(re.findall(r"^```", text, re.M)) % 2:
            errors.append(f"Unclosed code fence: {path.relative_to(root)}")
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if "://" in link or link.startswith("#"):
                continue
            target = path.parent / link.split("#")[0]
            if not target.exists():
                errors.append(f"Broken local link: {path.relative_to(root)} -> {link}")
    return errors


def task_errors(text):
    errors, rows = [], {}
    for line in text.splitlines():
        if not re.match(r"^\| IH-\d{3} \|", line):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) != 6:
            errors.append(f"Invalid task row: {line}")
            continue
        task_id, _, kind, priority, status, deps = cells
        if task_id in rows:
            errors.append(f"Duplicate task: {task_id}")
        if kind not in {"feature", "bug", "refactor", "tech-debt", "design", "balance", "art", "documentation"}:
            errors.append(f"Invalid task type: {task_id}")
        if priority not in {f"priority:{x}" for x in ("critical", "high", "medium", "low")}:
            errors.append(f"Invalid task priority: {task_id}")
        if status not in {f"status:{x}" for x in ("backlog", "ready", "in-progress", "review", "done", "blocked")}:
            errors.append(f"Invalid task status: {task_id}")
        rows[task_id] = re.findall(r"IH-\d{3}", deps)
    visited, visiting = set(), set()

    def visit(task_id):
        if task_id in visiting:
            errors.append(f"Cyclic task dependency: {task_id}")
            return
        if task_id in visited:
            return
        if task_id not in rows:
            errors.append(f"Missing dependency: {task_id}")
            return
        visiting.add(task_id)
        for dep in rows[task_id]:
            visit(dep)
        visiting.remove(task_id)
        visited.add(task_id)

    for task_id in rows:
        visit(task_id)
        if not re.search(rf"^## {task_id} —", text, re.M):
            errors.append(f"Missing task specification: {task_id}")
    if not rows:
        errors.append("No task registry found")
    return errors


def ignore_errors(root):
    ignored = ["game/.godot/editor/cache", "build/test", "dist/test", "exports/test", "file.tmp", "file.bak", "file.log", ".DS_Store", "Thumbs.db", ".idea/test", ".env", ".env.local"]
    sources = ["game/project.godot", "game/scripts/example.gd", "game/scripts/example.gd.uid", "game/scenes/example.tscn", "game/data/example.tres", "game/assets/example.png", "game/assets/example.ogg", "game/assets/example.png.import", "game/ui/example.gdshader", ".env.example"]
    result = subprocess.run(["git", "check-ignore", "--no-index", "--stdin"], cwd=root, input="\n".join(ignored + sources) + "\n", text=True, capture_output=True)
    if result.returncode not in (0, 1):
        return [f"git check-ignore failed: {result.stderr.strip()}"]
    found = set(result.stdout.splitlines())
    return [f"Not ignored: {p}" for p in ignored if p not in found] + [f"Source wrongly ignored: {p}" for p in sources if p in found]


def main():
    errors = []
    for name in REQUIRED:
        path = ROOT / name
        if not path.is_file() or not path.read_text().strip():
            errors.append(f"Missing or empty required file: {name}")
    for name in (".github/workflows", "game/assets", "game/scripts", "game/systems", "game/data", "game/ui", "game/tests", "tests", "art/source"):
        if not (ROOT / name).is_dir():
            errors.append(f"Missing directory: {name}")
    errors += resource_errors(ROOT)
    errors += markdown_errors(ROOT)
    tasks = ROOT / "docs/03-development/TASKS.md"
    if tasks.exists():
        errors += task_errors(tasks.read_text())
    errors += ignore_errors(ROOT)
    for error in errors:
        print(f"FAIL: {error}")
    if errors:
        return 1
    print(f"PASS: {len(REQUIRED)} required files, directory layout, local Markdown links/fences, res:// references, task graph and Git ignore policy")
    print("Godot parsing/import/runtime NOT tested. Archived originals excluded from link checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
