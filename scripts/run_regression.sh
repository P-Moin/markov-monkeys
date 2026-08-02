#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
build_dir="${MARKOV_BUILD_DIR:-build/sim}"
mkdir -p "$build_dir"

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
    iverilog -g2012 -s "$top" -o "$build_dir/$output.vvp" "$@"
    local log="$build_dir/$output.log"
    vvp "$build_dir/$output.vvp" | tee "$log"
    if ! grep -qx "RESULT: PASS" "$log"; then
        echo "ERROR: $top did not report an unambiguous pass" >&2
        return 1
    fi
}

run_test mac_unit_tb mac_unit_tb \
    rtl/compute/mac_unit.sv tb/mac_unit_tb.v

run_test Memory_tb mem_tb \
    rtl/compute/Memory.sv tb/mem_tb.v

run_test matvec_equiv_tb matvec_equiv_tb \
    "${compute_sources[@]}" tb/matvec_equiv_tb.sv

run_test matvec_equiv_tb matvec_equiv_n8_tb \
    -Pmatvec_equiv_tb.N=8 "${compute_sources[@]}" tb/matvec_equiv_tb.sv

run_test matvec_n1_tb matvec_n1_tb \
    "${compute_sources[@]}" tb/matvec_n1_tb.sv

run_test markov_protocol_tb markov_protocol_tb \
    "${compute_sources[@]}" rtl/controller/markov_top.v \
    tb/markov_protocol_tb.sv

run_test markov_top_tb markov_top_tb \
    "${compute_sources[@]}" rtl/controller/markov_top.v \
    tb/markov_top_tb.v

run_test markov_top_tb markov_top_converge_tb \
    "${compute_sources[@]}" rtl/controller/convergence_compare.sv \
    rtl/controller/markov_top.v rtl/controller/markov_top_converge.v \
    tb/markov_top_converge_tb.sv

run_test markov_top_tb markov_top_converge_n4_tb \
    -Pmarkov_top_tb.N=4 "${compute_sources[@]}" \
    rtl/controller/convergence_compare.sv \
    rtl/controller/markov_top.v rtl/controller/markov_top_converge.v \
    tb/markov_top_converge_tb.sv

run_test convergence_compare_tb convergence_compare_tb \
    rtl/controller/convergence_compare.sv tb/convergence_compare_tb.sv

echo "ALL REGRESSIONS COMPLETED"
