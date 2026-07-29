#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p .codex_build

compute_sources=(
    rtl/compute/Memory.sv
    rtl/compute/mac_unit.sv
    rtl/compute/parallel_matvec_core.sv
    rtl/compute/matmul_top.sv
)

run_test() {
    local top="$1"
    local output="$2"
    shift 2
    echo "== $top =="
    iverilog -g2012 -s "$top" -o ".codex_build/$output.vvp" "$@"
    vvp ".codex_build/$output.vvp"
}

run_test mac_unit_tb mac_unit_tb \
    rtl/compute/mac_unit.sv tb/mac_unit_tb.v

run_test Memory_tb mem_tb \
    rtl/compute/Memory.sv tb/mem_tb.v

run_test matvec_equiv_tb matvec_equiv_tb \
    "${compute_sources[@]}" tb/matvec_equiv_tb.sv

run_test matvec_n1_tb matvec_n1_tb \
    "${compute_sources[@]}" tb/matvec_n1_tb.sv

run_test markov_protocol_tb markov_protocol_tb \
    "${compute_sources[@]}" rtl/controller/markov_top.v \
    tb/markov_protocol_tb.sv

run_test markov_top_tb markov_top_tb \
    "${compute_sources[@]}" rtl/controller/markov_top.v \
    tb/markov_top_tb.v

run_test markov_top_tb markov_top_converge_tb \
    "${compute_sources[@]}" rtl/controller/markov_top_converge.v \
    tb/markov_top_converge_tb

echo "ALL REGRESSIONS COMPLETED"
