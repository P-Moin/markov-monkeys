#!/usr/bin/env python3
"""Run one isolated full-metrics experiment and persist its provenance/status."""

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results" / "full_metrics"
RERUN_ROOT = ROOT / "openlane" / "reruns" / "full_metrics"
WORKTREE_ROOT = Path("/tmp/markov_experiment_worktrees")
OPENLANE = [
    "/nix/var/nix/profiles/default/bin/nix",
    "run",
    "--offline",
    "/home/pmoin/openlane2#openlane",
    "--",
]


def now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def run_capture(command: list[str], cwd: Path) -> str:
    return subprocess.run(
        command,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    ).stdout


def append_progress(message: str) -> None:
    with (RESULTS / "progress.log").open("a") as stream:
        stream.write(f"{now()} {message}\n")


def update_status(
    experiment: int,
    status: str,
    stage: str,
    start: str,
    end: str,
    run_dir: Path,
    error: str,
) -> None:
    path = RESULTS / "status.csv"
    with path.open(newline="") as stream:
        rows = list(csv.DictReader(stream))
        fieldnames = list(rows[0].keys())
    for row in rows:
        if int(row["experiment"]) == experiment:
            row.update(
                {
                    "status": status,
                    "current_stage": stage,
                    "start_time": start,
                    "end_time": end,
                    "run_dir": str(run_dir.relative_to(ROOT)),
                    "error": error.replace("\n", " ")[:500],
                }
            )
            break
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def manifest_entry(experiment: int) -> dict[str, Any]:
    entries = json.loads((RESULTS / "campaign_manifest.json").read_text())
    for entry in entries:
        if entry["experiment"] == experiment:
            return entry
    raise SystemExit(f"experiment {experiment:02d} is not in campaign_manifest.json")


def ensure_worktree(entry: dict[str, Any], worktree: Path, output_parent: Path) -> None:
    if not worktree.exists():
        subprocess.run(
            ["git", "worktree", "add", "--detach", str(worktree), entry["git_commit"]],
            cwd=ROOT,
            check=True,
        )
    actual = run_capture(["git", "rev-parse", "HEAD"], worktree).strip()
    expected = run_capture(["git", "rev-parse", entry["git_commit"]], ROOT).strip()
    if actual != expected:
        raise SystemExit(f"{worktree} is at {actual}, expected {expected}")

    runs_link = worktree / "runs"
    if runs_link.is_symlink():
        if runs_link.resolve() != output_parent.resolve():
            raise SystemExit(f"{runs_link} points to unexpected target")
    elif runs_link.exists():
        raise SystemExit(f"{runs_link} already exists and is not a symlink")
    else:
        runs_link.symlink_to(output_parent, target_is_directory=True)


def config_path(entry: dict[str, Any], worktree: Path) -> Path:
    value = entry["config_file"]
    if value.startswith("project::"):
        return ROOT / value.removeprefix("project::")
    return worktree / value


def metadata(entry: dict[str, Any]) -> dict[str, Any]:
    environment = json.loads((RESULTS / "environment_manifest.json").read_text())
    return {
        **entry,
        "rtl_commit": entry["git_commit"],
        "openlane_version": environment["openlane_version"],
        "openroad_version": environment["openroad_version"],
        "pdk_version": environment["pdk_version"],
        "power_method": environment["power_method"],
        "power_corner": environment["power_reference_corner"],
        "power_activity": environment["power_activity"],
        "thread_count": environment["jobs"],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--experiment", type=int, required=True)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    entry = manifest_entry(args.experiment)
    label = f"exp{args.experiment:02d}"
    worktree = WORKTREE_ROOT / label
    output_parent = RERUN_ROOT / label
    run_dir = output_parent / f"RERUN_FULL_EXP{args.experiment:02d}"
    output_parent.mkdir(parents=True, exist_ok=True)
    if run_dir.exists():
        raise SystemExit(f"refusing to overwrite existing run: {run_dir}")

    ensure_worktree(entry, worktree, output_parent)
    config = config_path(entry, worktree)
    if not config.is_file():
        raise SystemExit(f"configuration does not exist: {config}")

    command = [
        *OPENLANE,
        str(config),
        "--design-dir",
        str(worktree),
        "--run-tag",
        run_dir.name,
        "--condensed",
        "--hide-progress-bar",
        "-j",
        "8",
    ]
    if entry.get("archived_state"):
        initial_state = ROOT / entry["archived_state"]
        if not initial_state.is_file():
            raise SystemExit(f"archived state does not exist: {initial_state}")
        command.extend(
            [
                "--from",
                "OpenROAD.CheckSDCFiles",
                "--with-initial-state",
                str(initial_state),
            ]
        )

    start = now()
    provenance_dir = output_parent / "provenance"
    provenance_dir.mkdir(exist_ok=True)
    (provenance_dir / "git_state.txt").write_text(
        run_capture(["git", "rev-parse", "HEAD"], worktree)
        + run_capture(["git", "branch", "--show-current"], worktree)
        + run_capture(["git", "status", "--short"], worktree)
    )
    (provenance_dir / "git_diff.patch").write_text(
        run_capture(["git", "diff", "--binary"], worktree)
    )
    (provenance_dir / "command.txt").write_text(
        subprocess.list2cmdline(command) + "\n"
    )
    (provenance_dir / "start_time.txt").write_text(start + "\n")
    shutil.copy2(RESULTS / "environment_manifest.json", provenance_dir)
    metadata_path = provenance_dir / "metadata.json"
    metadata_path.write_text(json.dumps(metadata(entry), indent=2) + "\n")

    update_status(args.experiment, "running", "flow", start, "", run_dir, "")
    append_progress(f"EXP{args.experiment:02d} flow started commit={entry['git_commit']}")

    console_log = output_parent / "campaign_console.log"
    returncode = 1
    error = ""
    try:
        with console_log.open("w") as stream:
            process = subprocess.Popen(
                command,
                cwd=worktree,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
            assert process.stdout is not None
            for line in process.stdout:
                stream.write(line)
                stream.flush()
                if not args.quiet:
                    print(line, end="", flush=True)
            returncode = process.wait()
    except Exception as exc:
        error = f"{type(exc).__name__}: {exc}"

    end = now()
    (provenance_dir / "end_time.txt").write_text(end + "\n")
    status = "complete" if returncode == 0 else "failed"
    if returncode != 0 and not error:
        error = f"OpenLane exit code {returncode}; see {console_log}"

    collector = [
        sys.executable,
        str(ROOT / "scripts" / "collect_full_metrics.py"),
        "--experiment",
        str(args.experiment),
        "--run-dir",
        str(run_dir),
        "--output-json",
        str(RESULTS / f"exp{args.experiment:02d}.json"),
        "--metadata-json",
        str(metadata_path),
    ]
    subprocess.run(collector, cwd=ROOT, check=True)
    extracted = json.loads((RESULTS / f"exp{args.experiment:02d}.json").read_text())
    stage = extracted.get("last_stage") or "not_started"
    update_status(args.experiment, status, stage, start, end, run_dir, error)
    append_progress(
        f"EXP{args.experiment:02d} flow {status} stage={stage} run={run_dir}"
    )
    raise SystemExit(returncode)


if __name__ == "__main__":
    main()
