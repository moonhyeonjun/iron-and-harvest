"""Run the same bounded, failure-sensitive checks locally and in GitHub Actions."""

import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r"\x1b\[[0-9;]*m")
ENGINE_ERROR = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:)", re.MULTILINE)


def run_step(name, command, output_dir, *, marker=None, engine=False, timeout=300):
    """An exit-zero engine error or missing completion marker is still a failure."""
    output_dir.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    timed_out = False
    try:
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True,
                                   start_new_session=os.name == "posix")
        try:
            output, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            if os.name == "posix":
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
            output, _ = process.communicate()
        returncode = process.returncode
    except OSError as error:
        output = str(error) + "\n"
        returncode = 127
    clean = ANSI.sub("", output)
    reasons = []
    if timed_out:
        reasons.append("timeout")
    if returncode != 0:
        reasons.append("nonzero exit")
    if engine and ENGINE_ERROR.search(clean):
        reasons.append("engine error in log")
    if marker and marker not in clean.splitlines():
        reasons.append("missing completion marker")
    (output_dir / (name + ".log")).write_text(clean)
    print(clean, end="" if clean.endswith("\n") else "\n", flush=True)
    result = {"name": name, "command": command, "exit_code": returncode,
              "seconds": round(time.monotonic() - started, 3), "passed": not reasons,
              "failures": reasons}
    print(f"{name}: {'PASS' if result['passed'] else 'FAIL'} {reasons}", flush=True)
    return result


def ci_steps(python):
    """Ordered (name, command, options); each gameplay suite needs its PASS marker."""
    godot = [python, "tools/godot.py"]
    return [
        ("foundation", [python, "tools/validate_foundation.py"], {}),
        ("python-tests", [python, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], {}),
        ("economy-design", [python, "tools/check_economy.py"], {}),
        ("godot-version", godot + ["--version"], {"engine": True}),
        ("godot-import", godot + ["--headless", "--import"], {"engine": True}),
        ("foundation-smoke", godot + ["--headless", "--script", "res://tests/smoke_engine.gd"],
         {"engine": True, "marker": "PASS: typed GDScript and Foundation PackedScene instantiation"}),
        ("foundation-runtime", godot + ["--headless", "--quit-after", "10"], {"engine": True}),
        ("player-acceptance", godot + ["--headless", "--script", "res://tests/test_player_movement.gd"],
         {"engine": True, "marker": "RESULT: PASS"}),
        ("interaction-acceptance", godot + ["--headless", "--script", "res://tests/test_interaction.gd"],
         {"engine": True, "marker": "RESULT: PASS"}),
        ("source-tree-clean", [python, "-c",
         "import subprocess,sys; r=subprocess.run(['git','status','--porcelain','--untracked-files=all'],capture_output=True,text=True,check=True); print(r.stdout,end=''); sys.exit(bool(r.stdout))"], {}),
    ]


def main():
    results = []
    output_dir = ROOT / "build/ci"
    for name, command, options in ci_steps(sys.executable):
        print(f"Running {name}", flush=True)
        result = run_step(name, command, output_dir, **options)
        results.append(result)
        (output_dir / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        if not result["passed"]:
            print("CI failed; remaining steps were not run.", flush=True)
            return 1
    print("CI: PASS (headless checks only; GUI/export/Steam are not covered)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
