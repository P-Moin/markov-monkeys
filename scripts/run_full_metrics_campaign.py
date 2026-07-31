#!/usr/bin/env python3
"""Run a sequential subset of the full-metrics campaign."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def parse_experiments(value: str) -> list[int]:
    result: list[int] = []
    for part in value.split(","):
        if "-" in part:
            start, end = (int(item) for item in part.split("-", 1))
            result.extend(range(start, end + 1))
        else:
            result.append(int(part))
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--experiments", required=True)
    args = parser.parse_args()

    failures: list[int] = []
    for experiment in parse_experiments(args.experiments):
        available = shutil.disk_usage(Path.home()).free
        if available < 10 * 1024**3:
            print(f"EXP{experiment:02d} not started: free space below 10 GiB", flush=True)
            failures.append(experiment)
            break
        print(
            f"EXP{experiment:02d} START free_gib={available / 1024**3:.1f}",
            flush=True,
        )
        command = [
            sys.executable,
            str(ROOT / "scripts" / "run_full_metrics_experiment.py"),
            "--experiment",
            str(experiment),
            "--quiet",
        ]
        result = subprocess.run(command, cwd=ROOT)
        print(f"EXP{experiment:02d} END exit={result.returncode}", flush=True)
        if result.returncode:
            failures.append(experiment)

    if failures:
        print("FAILED=" + ",".join(f"{item:02d}" for item in failures), flush=True)
        raise SystemExit(1)
    print("CAMPAIGN_SUBSET_COMPLETE", flush=True)


if __name__ == "__main__":
    main()
