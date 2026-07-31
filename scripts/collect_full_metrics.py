#!/usr/bin/env python3
"""Collect comparable OpenLane metrics without converting missing values to zero."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


METRIC_KEYS = {
    "setup_wns_ns": "timing__setup__ws",
    "setup_tns_ns": "timing__setup__tns",
    "hold_wns_ns": "timing__hold__ws",
    "hold_tns_ns": "timing__hold__tns",
    "standard_cells": "design__instance__count",
    "instance_area_um2": "design__instance__area",
    "core_area_um2": "design__core__area",
    "wire_length_um": "route__wirelength",
    "timing_buffers": "design__instance__count__class:timing_repair_buffer",
    "hold_buffers": "design__instance__count__hold_buffer",
    "antenna_diodes": "antenna_diodes_count",
    "slew_violations": "design__max_slew_violation__count",
    "cap_violations": "design__max_cap_violation__count",
    "fanout_violations": "design__max_fanout_violation__count",
    "antenna_nets": "antenna__violating__nets",
    "antenna_pins": "antenna__violating__pins",
    "route_drc": "route__drc_errors",
    "magic_drc": "magic__drc_error__count",
    "klayout_drc": "klayout__drc_error__count",
    "lvs_errors": "design__lvs_error__count",
}


def read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def step_number(path: Path) -> int:
    match = re.match(r"(\d+)-", path.parent.name)
    return int(match.group(1)) if match else -1


def load_metrics(run_dir: Path) -> tuple[dict[str, Any], str | None]:
    final_metrics = run_dir / "final" / "metrics.json"
    if final_metrics.is_file():
        return read_json(final_metrics), str(final_metrics)

    states = sorted(run_dir.glob("*/state_out.json"), key=step_number)
    for state_path in reversed(states):
        state = read_json(state_path)
        metrics = state.get("metrics")
        if isinstance(metrics, dict):
            return metrics, str(state_path)
    return {}, None


def load_synthesis(run_dir: Path) -> tuple[Any, Any, str | None]:
    candidates = sorted(run_dir.glob("*/reports/stat.json"), key=lambda p: step_number(p.parent.parent))
    for path in candidates:
        report = read_json(path)
        design = report.get("design")
        if not isinstance(design, dict):
            modules = report.get("modules", {})
            if isinstance(modules, dict) and modules:
                design = next(iter(modules.values()))
        if isinstance(design, dict):
            return design.get("num_cells"), design.get("area"), str(path)
    return None, None, None


def parse_runtime_file(path: Path) -> float | None:
    try:
        value = path.read_text().strip()
    except OSError:
        return None
    match = re.fullmatch(r"(\d+):(\d+):(\d+(?:\.\d+)?)", value)
    if not match:
        return None
    hours, minutes, seconds = match.groups()
    return int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def total_runtime(run_dir: Path) -> float | None:
    values = [value for path in run_dir.glob("*/runtime.txt") if (value := parse_runtime_file(path)) is not None]
    return round(sum(values), 3) if values else None


def parse_antenna_ratio(run_dir: Path) -> float | None:
    reports = sorted(
        run_dir.glob("*/reports/antenna_summary.rpt"),
        key=lambda path: step_number(path.parent.parent),
    )
    if not reports:
        return None

    ratios: list[float] = []
    try:
        text = reports[-1].read_text(errors="replace")
    except OSError:
        return None
    for line in text.splitlines():
        match = re.search(r"[│|]\s*([0-9]+(?:\.[0-9]+)?)\s*[│|]", line)
        if match:
            ratios.append(float(match.group(1)))
    return max(ratios) if ratios else None


def last_stage(run_dir: Path) -> str | None:
    stages = []
    for path in run_dir.iterdir() if run_dir.is_dir() else []:
        if not path.is_dir():
            continue
        match = re.match(r"(\d+)-(.+)", path.name)
        if match:
            stages.append((int(match.group(1)), match.group(2)))
    return max(stages)[1] if stages else None


def flow_status(run_dir: Path) -> tuple[str, str | None]:
    flow_log = run_dir / "flow.log"
    text = flow_log.read_text(errors="replace") if flow_log.is_file() else ""
    if "Flow complete." in text:
        return "complete", None
    stage = last_stage(run_dir)
    if (run_dir / "error.log").is_file() or "failed" in text.lower():
        return "failed", stage
    return "partial", stage


def pass_if_complete(values: list[Any], predicate: bool) -> bool | None:
    return predicate if all(value is not None for value in values) else None


def collect(args: argparse.Namespace) -> dict[str, Any]:
    run_dir = Path(args.run_dir).resolve()
    metrics, metrics_source = load_metrics(run_dir)
    resolved = read_json(run_dir / "resolved.json")
    metadata = read_json(Path(args.metadata_json)) if args.metadata_json else {}
    synth_cells, synth_area, synth_source = load_synthesis(run_dir)
    status, failure_stage = flow_status(run_dir)

    result: dict[str, Any] = {
        "experiment": args.experiment,
        "description": metadata.get("description"),
        "result_original": metadata.get("result_original"),
        "git_branch": metadata.get("git_branch"),
        "git_commit": metadata.get("git_commit"),
        "rtl_commit": metadata.get("rtl_commit", metadata.get("git_commit")),
        "mapping_confidence": metadata.get("mapping_confidence"),
        "config_file": metadata.get("config_file"),
        "run_directory": str(run_dir),
        "flow_status": status,
        "failure_stage": failure_stage,
        "clock_ns": resolved.get("CLOCK_PERIOD", metadata.get("clock_ns")),
        "synthesis_cells": synth_cells,
        "synthesis_area_um2": synth_area,
        "power_mw": (
            metrics["power__total"] * 1000
            if isinstance(metrics.get("power__total"), (int, float))
            else None
        ),
        "worst_antenna_pr": parse_antenna_ratio(run_dir),
        "runtime_seconds": total_runtime(run_dir),
        "openlane_version": metadata.get("openlane_version"),
        "openroad_version": metadata.get("openroad_version"),
        "pdk_version": metadata.get("pdk_version"),
        "power_method": metadata.get("power_method"),
        "power_corner": metadata.get("power_corner", "max_ff_n40C_1v95"),
        "power_activity": metadata.get("power_activity", "OpenROAD vectorless defaults"),
        "thread_count": metadata.get("thread_count"),
        "random_seed": resolved.get("PL_RANDOM_GLB_PLACEMENT", metadata.get("random_seed")),
        "compatibility_patch": metadata.get("compatibility_patch"),
        "notes": metadata.get("notes"),
        "metrics_source": metrics_source,
        "synthesis_source": synth_source,
        "source_files": resolved.get("VERILOG_FILES"),
        "last_stage": last_stage(run_dir),
    }

    for output_key, metric_key in METRIC_KEYS.items():
        result[output_key] = metrics.get(metric_key)

    timing_values = [
        result["setup_wns_ns"],
        result["setup_tns_ns"],
        result["hold_wns_ns"],
        result["hold_tns_ns"],
    ]
    result["timing_pass"] = pass_if_complete(
        timing_values,
        result["setup_wns_ns"] is not None
        and result["setup_wns_ns"] >= 0
        and result["setup_tns_ns"] == 0
        and result["hold_wns_ns"] is not None
        and result["hold_wns_ns"] >= 0
        and result["hold_tns_ns"] == 0,
    )

    physical_values = [
        result["route_drc"],
        result["magic_drc"],
        result["klayout_drc"],
        result["lvs_errors"],
        result["antenna_nets"],
        result["antenna_pins"],
    ]
    result["physical_verification_pass"] = pass_if_complete(
        physical_values,
        all(value == 0 for value in physical_values if value is not None),
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--experiment", type=int, required=True)
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--metadata-json")
    args = parser.parse_args()

    result = collect(args)
    output = Path(args.output_json)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(output)


if __name__ == "__main__":
    main()
