"""Run the pinned Godot Standard editor against game/ without changing PATH."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def matches_version(actual, expected):
    # Reject dev/RC, another patch version, custom builds and .NET/Mono builds.
    return re.fullmatch(re.escape(expected) + r"\.stable\.official\.[0-9a-f]+", actual.strip()) is not None


def find_engine(expected, override=None):
    if override:
        candidates = [Path(override).expanduser()]
    else:
        candidates = [
            Path.home() / f"Applications/Godot-{expected}.app/Contents/MacOS/Godot",
            Path(f"/Applications/Godot-{expected}.app/Contents/MacOS/Godot"),
            Path("/Applications/Godot.app/Contents/MacOS/Godot"),
        ]
        for name in ("godot", "godot4"):
            found = shutil.which(name)
            if found:
                candidates.append(Path(found))
    reasons = []
    for path in candidates:
        if not path.is_file():
            reasons.append(f"Not found: {path}")
            continue
        try:
            result = subprocess.run([str(path), "--version"], capture_output=True, text=True, timeout=20)
        except (OSError, subprocess.TimeoutExpired) as error:
            reasons.append(f"Cannot query {path}: {error}")
            continue
        actual = result.stdout.strip()
        if result.returncode == 0 and matches_version(actual, expected):
            return path
        reasons.append(f"Version rejected at {path}: {actual!r} (exit {result.returncode})")
    raise RuntimeError(f"Godot {expected} stable official Standard is required. Set GODOT_BIN to its executable.\n" + "\n".join(reasons))


def main(argv=None):
    arguments = sys.argv[1:] if argv is None else argv
    if any(arg == "--path" or arg.startswith("--path=") for arg in arguments):
        print("This launcher always uses this repository's game/ project; omit --path.", file=sys.stderr)
        return 2
    expected = (ROOT / ".godot-version").read_text().strip()
    try:
        engine = find_engine(expected, os.environ.get("GODOT_BIN"))
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 2
    return subprocess.call([str(engine), "--path", str(ROOT / "game"), *arguments])


if __name__ == "__main__":
    raise SystemExit(main())
