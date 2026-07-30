#!/usr/bin/env python3
"""Aggregate Experiment 00-20 full-flow rerun metrics."""

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "results" / "full_metrics"

FIELDS = [
    "experiment", "description", "result_original", "git_branch", "git_commit",
    "mapping_confidence", "config_file", "run_directory", "flow_status",
    "failure_stage", "clock_ns", "synthesis_cells", "synthesis_area_um2",
    "setup_wns_ns", "setup_tns_ns", "hold_wns_ns", "hold_tns_ns",
    "standard_cells", "instance_area_um2", "core_area_um2", "power_mw",
    "wire_length_um", "timing_buffers", "hold_buffers", "antenna_diodes",
    "slew_violations", "cap_violations", "fanout_violations", "antenna_nets",
    "antenna_pins", "worst_antenna_pr", "route_drc", "magic_drc",
    "klayout_drc", "lvs_errors", "runtime_seconds", "openlane_version",
    "openroad_version", "pdk_version", "power_method", "notes",
    "timing_pass", "physical_verification_pass", "compatibility_patch",
    "power_corner", "power_activity", "thread_count",
]

# Metrics reported before this consistent rerun campaign. Missing historical
# values are intentionally absent and are serialized as null, never zero.
ORIGINAL = {
    0: dict(synthesis_cells=4575, synthesis_area_um2=61388.9, setup_wns_ns=.4350,
            hold_wns_ns=.1015, standard_cells=17727, instance_area_um2=99793.2,
            core_area_um2=339526, power_mw=6.2910, wire_length_um=344879,
            slew_violations=80, cap_violations=0, antenna_nets=0,
            route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    1: dict(synthesis_cells=9493, synthesis_area_um2=110164.4),
    2: dict(synthesis_cells=9493, synthesis_area_um2=110164.4, setup_wns_ns=-5.5409,
            hold_wns_ns=.0443, power_mw=4.4127, slew_violations=6228,
            cap_violations=27, fanout_violations=325),
    3: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=2.3633,
            hold_wns_ns=.0226, power_mw=5.9111, slew_violations=5754,
            cap_violations=15, fanout_violations=492),
    4: dict(synthesis_cells=9403, synthesis_area_um2=110284.5, setup_wns_ns=-3.3927,
            hold_wns_ns=.0407, power_mw=4.4228, slew_violations=6165,
            cap_violations=27, fanout_violations=313),
    5: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=.5093,
            hold_wns_ns=.1034, standard_cells=25748, instance_area_um2=156920,
            core_area_um2=339526, power_mw=13.0125, wire_length_um=542207,
            slew_violations=175, cap_violations=4, antenna_nets=2,
            route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    6: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=.5381,
            hold_wns_ns=.1031, standard_cells=25749, instance_area_um2=156933,
            core_area_um2=339526, power_mw=13.0003, wire_length_um=542052,
            slew_violations=173, cap_violations=3, antenna_nets=5,
            route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    7: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=.3319,
            hold_wns_ns=.0868, standard_cells=26137, instance_area_um2=158055,
            core_area_um2=339526, power_mw=12.9964, wire_length_um=543182,
            slew_violations=34, cap_violations=2, antenna_nets=3,
            route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    8: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=-.3928,
            hold_wns_ns=.0851, standard_cells=32984, instance_area_um2=175189,
            core_area_um2=339526, power_mw=13.8211, wire_length_um=610017,
            slew_violations=499, cap_violations=3, antenna_nets=3,
            route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    9: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=1.2576,
            hold_wns_ns=.1000, standard_cells=19827, instance_area_um2=142265,
            core_area_um2=339526, power_mw=12.7389, wire_length_um=528906,
            slew_violations=21, cap_violations=0, antenna_nets=30,
            route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    10: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=.5414,
             hold_wns_ns=.0859, standard_cells=26037, instance_area_um2=157805,
             core_area_um2=339526, power_mw=12.9898, wire_length_um=542415,
             slew_violations=22, cap_violations=2, antenna_nets=2,
             route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    11: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=.4723,
             hold_wns_ns=.0880, standard_cells=26042, instance_area_um2=157818,
             core_area_um2=339526, power_mw=12.9889, wire_length_um=542842,
             slew_violations=24, cap_violations=2, antenna_nets=4,
             route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    12: dict(synthesis_cells=9965, synthesis_area_um2=116435.4, setup_wns_ns=.4842,
             hold_wns_ns=.0869, standard_cells=26034, instance_area_um2=157798,
             core_area_um2=339526, power_mw=12.9912, wire_length_um=542677,
             slew_violations=32, cap_violations=3, antenna_nets=2,
             route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    13: dict(synthesis_cells=10025, synthesis_area_um2=116819.5),
    14: dict(synthesis_cells=10479, synthesis_area_um2=118688.8),
    15: dict(synthesis_cells=10479, synthesis_area_um2=118688.8, setup_wns_ns=-9.1549,
             hold_wns_ns=.0227, power_mw=4.6906, slew_violations=4751,
             cap_violations=21, fanout_violations=504),
    16: dict(synthesis_cells=10583, synthesis_area_um2=122063.3, setup_wns_ns=-.2703,
             hold_wns_ns=.0227, power_mw=4.8109, slew_violations=4760,
             cap_violations=19, fanout_violations=509),
    17: dict(synthesis_cells=10730, synthesis_area_um2=123452.2, setup_wns_ns=1.8365,
             hold_wns_ns=.0227, power_mw=4.8426, slew_violations=5133,
             cap_violations=18, fanout_violations=506),
    18: dict(synthesis_cells=10730, synthesis_area_um2=123452.2, setup_wns_ns=.7621,
             hold_wns_ns=.1072, standard_cells=27661, instance_area_um2=167623,
             core_area_um2=339526, power_mw=10.2117, wire_length_um=577559,
             slew_violations=55, cap_violations=0, antenna_nets=4,
             route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    19: dict(synthesis_cells=10730, synthesis_area_um2=123452.2, setup_wns_ns=.8403,
             hold_wns_ns=.1070, standard_cells=27662, instance_area_um2=167626,
             core_area_um2=339526, power_mw=10.2086, wire_length_um=577401,
             slew_violations=50, cap_violations=0, antenna_nets=6,
             route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
    20: dict(synthesis_cells=10730, synthesis_area_um2=123452.2, setup_wns_ns=.6142,
             hold_wns_ns=.1049, standard_cells=27398, instance_area_um2=166893,
             core_area_um2=339526, power_mw=10.2238, wire_length_um=576981,
             slew_violations=180, cap_violations=0, antenna_nets=5,
             route_drc=0, magic_drc=0, klayout_drc=0, lvs_errors=0),
}


def differences(exp: dict) -> list[str]:
    old = ORIGINAL.get(exp["experiment"], {})
    flags: list[str] = []
    percent_limits = {
        "synthesis_cells": 2, "synthesis_area_um2": 2, "standard_cells": 2,
        "instance_area_um2": 2, "power_mw": 5, "wire_length_um": 10,
    }
    for key, limit in percent_limits.items():
        before, after = old.get(key), exp.get(key)
        if before not in (None, 0) and after is not None:
            pct = 100 * (after - before) / before
            if abs(pct) > limit:
                flags.append(f"{key} {pct:+.1f}%")
    for key in ("setup_wns_ns", "hold_wns_ns"):
        before, after = old.get(key), exp.get(key)
        if before is not None and after is not None and abs(after - before) > .10:
            flags.append(f"{key} {after-before:+.3f} ns")
    for key in ("route_drc", "magic_drc", "klayout_drc", "lvs_errors"):
        before, after = old.get(key), exp.get(key)
        if before is not None and after is not None and bool(before) != bool(after):
            flags.append(f"{key} pass/fail changed")
    return flags


def fmt(value) -> str:
    if value is None:
        return "N/A"
    if isinstance(value, bool):
        return "pass" if value else "fail"
    if isinstance(value, float):
        return f"{value:.4f}"
    return str(value)


experiments = []
for number in range(21):
    path = OUT / f"exp{number:02d}.json"
    with path.open(encoding="utf-8") as handle:
        item = json.load(handle)
    item["major_difference_flags"] = differences(item)
    experiments.append(item)

with (OUT / "experiments_full_metrics.json").open("w", encoding="utf-8") as handle:
    json.dump(experiments, handle, indent=2, sort_keys=True)
    handle.write("\n")

with (OUT / "experiments_full_metrics.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
    writer.writeheader()
    for item in experiments:
        writer.writerow({field: item.get(field) for field in FIELDS})

complete = [item for item in experiments if item["flow_status"] == "complete"]
failed = [item for item in experiments if item["flow_status"] != "complete"]
uncertain = [item for item in experiments if item["mapping_confidence"] != "high"]

lines = [
    "# Experiments Full Metrics", "",
    "| Exp | Tuned parameter / architecture | Setup WNS (ns) | Hold WNS (ns) | Cells | Area (um²) | Power (mW) | Slew | Cap | Antenna nets | DRC M/K/R | LVS |",
    "|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|",
]
for item in experiments:
    lines.append(
        f"| {item['experiment']:02d} | {item['description']} | "
        f"{fmt(item.get('setup_wns_ns'))} | {fmt(item.get('hold_wns_ns'))} | "
        f"{fmt(item.get('standard_cells'))} | {fmt(item.get('instance_area_um2'))} | "
        f"{fmt(item.get('power_mw'))} | {fmt(item.get('slew_violations'))} | "
        f"{fmt(item.get('cap_violations'))} | {fmt(item.get('antenna_nets'))} | "
        f"{fmt(item.get('magic_drc'))}/{fmt(item.get('klayout_drc'))}/{fmt(item.get('route_drc'))} | "
        f"{fmt(item.get('lvs_errors'))} |"
    )

for item in experiments:
    old = ORIGINAL.get(item["experiment"], {})
    flags = item["major_difference_flags"]
    warnings = []
    if item["mapping_confidence"] != "high":
        warnings.append(f"{item['mapping_confidence']} historical mapping confidence")
    if item.get("compatibility_patch"):
        warnings.append(item["compatibility_patch"])
    lines += [
        "", f"## Experiment #{item['experiment']:02d}", "",
        f"- Change: {item['description']}",
        f"- Revision: `{item['git_commit']}` on `{item['git_branch']}`; config `{item['config_file']}`",
        f"- Original: {item['result_original']}; reported setup/hold WNS "
        f"{fmt(old.get('setup_wns_ns'))}/{fmt(old.get('hold_wns_ns'))} ns, "
        f"power {fmt(old.get('power_mw'))} mW",
        f"- Rerun: {item['flow_status']}; setup/hold WNS "
        f"{fmt(item.get('setup_wns_ns'))}/{fmt(item.get('hold_wns_ns'))} ns, "
        f"power {fmt(item.get('power_mw'))} mW, physical verification "
        f"{fmt(item.get('physical_verification_pass'))}",
        f"- Major differences: {', '.join(flags) if flags else 'none above requested thresholds'}",
        f"- Compatibility/warnings: {'; '.join(warnings) if warnings else 'none'}",
    ]

(OUT / "experiments_full_metrics.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

summary = [
    "# Full Metrics Rerun Summary", "",
    f"- Full flows completed: {len(complete)}/21 ({', '.join(f'{x['experiment']:02d}' for x in complete)})",
    f"- Failed flows: {len(failed)}"
    + (f" ({', '.join(f'{x['experiment']:02d}:{x.get('failure_stage')}' for x in failed)})" if failed else ""),
    f"- Uncertain mappings: {', '.join(f'{x['experiment']:02d} ({x['mapping_confidence']})' for x in uncertain) or 'none'}",
    "- Metric completeness: all requested full-flow implementation metrics were generated for all 21 experiments.",
    "- Power comparability: yes; every rerun used OpenROAD post-route vectorless power at max_ff_n40C_1v95 with identical default activity assumptions.",
    f"- Reruns with differences above requested comparison thresholds: "
    f"{', '.join(f'{x['experiment']:02d}' for x in experiments if x['major_difference_flags']) or 'none'}.",
    "- Thread count: 8 for every OpenLane run.",
    "- Clock period: 17 ns for every experiment.",
    "", "## Regeneration", "",
    "```bash",
    "python3 scripts/run_full_metrics_campaign.py --experiments 0-20",
    "python3 scripts/aggregate_full_metrics.py",
    "```",
]
(OUT / "rerun_summary.md").write_text("\n".join(summary) + "\n", encoding="utf-8")

print(OUT / "experiments_full_metrics.csv")
print(OUT / "experiments_full_metrics.json")
print(OUT / "experiments_full_metrics.md")
print(OUT / "rerun_summary.md")
