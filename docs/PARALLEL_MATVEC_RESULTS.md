# Parallel Matrix-Vector Engine: Architecture and Results

## Outcome

The integrated `matmul_top` now defaults to a full N-lane parallel
matrix-vector engine and retains the original one-MAC implementation as
`serial_matvec_core`. The wrapper parameter `USE_PARALLEL` selects the
implementation without changing Owen's ports or load/start/readback protocol.

All RTL, equivalence, edge-case, and end-to-end controller tests pass. The
selected 17 ns OpenLane candidate passes setup and hold at every reported PVT
corner, routing/Magic/KLayout DRC, and LVS. It is **not a complete signoff
pass**: two max-capacitance violations and two antenna violations remain.

## Authoritative interface convention

The checked-in integrated RTL was treated as authoritative where it disagreed
with prose supplied with the task:

- `ld_sel_ab = 0`: load flattened transition matrix P/B
- `ld_sel_ab = 1`: load state vector X/A
- P address: `k*N + j`
- operation: `X_next[j] = sum(k=0..N-1) X[k] * P[k][j]`

Loads are accepted only while the selected compute engine is idle. `start`
while busy is ignored. Results are retained internally and read after `done`
with `rd_en`, `rd_addr`, and `rd_data`; there is no live result stream.
Disabled reads and defined out-of-range result reads return zero.

## Datapath and memory organization

The parallel core instantiates one signed, two-stage `mac_unit` per output
column. During FEED cycle k, X[k] is broadcast and lane j reads P[k][j].
Each lane therefore accumulates one complete output column.

The memories synthesize as registers, not SRAMs:

- X: N signed DW-bit registers with N combinational read paths
- P: N*N signed DW-bit registers, flattened row-major, with one simultaneous
  combinational read per lane
- result: N signed ACC_W-bit registers

This organization deliberately provides the N simultaneous P reads that a
full-lane architecture requires. CAPTURE assigns all N result registers in one
clocked loop; synthesis implements N parallel register write enables, not a
single multiwrite memory.

The synthesized parallel design contains eight multiplier structures at N=8,
versus one in the serial reference. Per-lane feed-index registers and local
synchronous reset distribution registers were retained after pre-PnR evidence
showed that shared `k_count` and reset nets caused high-fanout timing failures.

## Pipeline and state machine

`mac_unit` registers the signed 8x8 product on one edge and accumulates that
registered product on the next valid edge. The parallel control sequence is:

`IDLE -> FEED (N cycles) -> DRAIN -> CAPTURE -> IDLE`

The final accumulator update occurs in DRAIN. CAPTURE is a separate later edge,
so the engine never copies an accumulator on the same edge as its last update.
CAPTURE writes every result register, deasserts `busy`, and pulses `done` for
exactly one cycle. Every result is readable during and after that pulse.

The serial reference retains its `IDLE -> FEED (N*N cycles) -> DRAIN` schedule
and writes one completed output after each dot product.

For N=4, the measured start-to-done latencies are 18 serial cycles and 7
parallel cycles. The formulas and N=8 integration values are:

| Implementation | Start-to-done cycles | Latency at 17 ns | Operations/s |
|---|---:|---:|---:|
| Serial one-MAC | `N*N + 2` = 66 | 1122 ns | 0.891 million |
| Parallel N-lane | `N + 3` = 11 | 187 ns | 5.348 million |

The interface accepts a new operation only after returning to IDLE, so
operation throughput equals reciprocal start-to-done latency. At N=8 the
parallel engine is 6.0x faster.

## Owen controller integration

Owen's loader still loads P only on the first pass and loads X on every pass.
The controller waits for `load_ready` before asserting `mm_start`, waits for
`mm_done`, and then reads all stored compute results.

`markov_top.v` and `markov_top_converge.v` gained a minimal COMMIT state. Their
state-memory write enable/address/data are registered; previously
`chain_done` or the next iteration could be selected one edge before the final
write actually committed. COMMIT waits that extra edge. The convergence
controller also latches the final combined tolerance result across COMMIT.

`num_cycles = 0` retains the repository's tested behavior: one matrix-vector
iteration is executed and then the chain completes. The three-iteration N=4
protocol test measures 75 cycles from `start` through committed
`chain_done`, and reads the complete final vector immediately on the
`chain_done` cycle.

## Numeric behavior and fixed-point status

Arithmetic is intentionally signed integer:

- `DW = 8`
- signed product width = 16 bits
- `ACC_W = 32`
- products are sign-extended before accumulation
- result storage and external readback are ACC_W bits
- feedback into the next DW-bit state vector uses the low DW bits, matching
  the pre-existing controller

`FRAC_W` exists in the legacy wrapper/controller parameter lists but no RTL
rounding, right shift, or saturation is implemented. Fixed-point parameters
and policy have not been finalized, so this work does not invent a format.
The result-register CAPTURE boundary is the appropriate place to add a future
round/shift/saturate function.

For N=8 signed INT8 inputs, an individual product is in
[-16256, 16384] and the mathematical dot-product range is
[-130048, 131072]. ACC_W=32 is therefore comfortably safe. It was not reduced
because the required external ACC_W behavior must remain stable.

## Verification

`scripts/run_regression.sh` compiles each test independently with Icarus
SystemVerilog mode and runs it with `vvp`. The final run reported:

| Test | Result |
|---|---|
| `mac_unit_tb` | PASS, 351 checks, 0 errors |
| `Memory_tb` | PASS, 552 checks, 0 errors |
| `matvec_equiv_tb` | PASS, 46 tests / 921 checks, 0 errors |
| `matvec_n1_tb` | PASS, -7 * 5 = -35 in serial and parallel |
| `markov_protocol_tb` | PASS, 3 iterations, 75 cycles, 0 errors |
| `markov_top_tb` | PASS, 25 tests / 200 checks, 0 errors |
| convergence `markov_top_tb` | PASS, 26 tests / 234 checks, 0 errors |

The deterministic equivalence seed is `0x4d415456`. Coverage includes identity,
zero, deterministic permutation, nonsymmetric/transposition-sensitive, signed
extremes, final-k-dependent results, 40 constrained-random cases,
back-to-back operations, stored result readback, one-cycle done, load and
start attempts while busy, disabled/invalid reads, idle reset, active reset,
N=1, and N=4.

No official staff UVM environment is present in this repository; a UVM score
is therefore pending rather than inferred.

## Baseline versus selected parallel PPA

The serial baseline is the existing successful run
`openlane/runs/RUN_2026-07-28_14-16-12`. The selected parallel candidate is
`runs/RUN_CODEX_PAR_FULL06_TWOITER_2026-07-28`.

| Metric | Serial baseline | Selected parallel | Change |
|---|---:|---:|---:|
| N=8 cycles | 66 | 11 | 6.0x faster |
| Synthesis cells | 4,575 | 9,965 | +117.8% |
| Synthesis area | 61,388.9 um2 | 116,435.4 um2 | +89.7% |
| Combinational area | 34,972.3 um2 | 82,011.2 um2 | +134.5% |
| Sequential area | 26,416.6 um2 | 34,424.3 um2 | +30.3% |
| Multiplier structures | 1 | 8 | +7 |
| Mapped mux cells | 1,293 | 1,456 | +12.6% |
| Synthesized flip-flops | 1,195 | 1,569 | +31.3% |
| Final standard cells | 17,727 | 26,037 | +46.3% |
| Final instance area | 99,793.2 um2 | 157,805 um2 | +58.1% |
| Core area | 339,526 um2 | 339,526 um2 | unchanged |
| Routed wire length | 344,879 um | 542,415 um | +57.3% |
| Estimated power | 0.006291 W | 0.012990 W | +106.5% |

Yosys flattened both register memories; it reported no inferred memory bits.
The parallel engine trades area and power for the measured 6x operation-rate
increase.

## Timing and critical path

Both designs use a 17 ns requested period (58.824 MHz).

| Post-route metric | Serial baseline | Selected parallel |
|---|---:|---:|
| Worst setup slack | +0.4350 ns | +0.5414 ns |
| Setup TNS / violations | 0 / 0 | 0 / 0 |
| Worst hold slack | +0.1015 ns | +0.0859 ns |
| Hold TNS / violations | 0 / 0 | 0 / 0 |
| Estimated maximum frequency | 60.37 MHz | 60.76 MHz |

Maximum frequency is estimated as
`1 / (17 ns - worst positive setup slack)`; it is an estimate, not a separate
faster-clock signoff run.

The selected candidate's worst setup path is at `max_ss_100C_1v60`, from
flip-flop `_16872_` (`load_count[1]`) to `_17511_`, with +0.541384 ns slack.
The path crosses the controller/load-address distribution and mux/decode
network. It is not an N-lane multiplier accumulation path. The pre-PnR
parallel critical paths had instead been dominated by global reset and shared
k-index fanout; per-lane distribution removed those failures.

## OpenLane signoff and optimization history

The selected candidate's exact post-route status is:

- setup: pass in all 9 reported corners, WNS +0.5414 ns, TNS 0
- hold: pass in all 9 reported corners, WNS +0.0859 ns, TNS 0
- routing DRC: 0
- Magic DRC: 0
- KLayout DRC: 0
- LVS: 0
- max slew: 22 violations
- max capacitance: 2 violations
- antenna: 2 nets / 2 pins
- final antenna `_04264_ -> _09046_/B1`, met1, P/R 1.08
- final antenna `net628 -> output628/A`, met1, P/R 1.06

The selected electrical settings reduced the first parallel run from 175 to
22 max-slew violations and from 4 to 2 max-capacitance violations. Limiting
antenna repair to two productive iterations reduced repair diodes from 33 to
17 and produced the best final antenna ratios. Post-GRT design repair,
aggressive 20-iteration repair, extra heuristic diodes/padding, no heuristic
insertion, 40% ratio margin, and one repair iteration were all measured and
rejected. Full details are in `optimization/experiments.csv`.

The selected candidate is a strong timing/DRC/LVS result but **must not be
called signoff-quality** until max capacitance and antenna both reach zero.
The eight-run campaign boundary was reached, so no additional full run was
started. A future campaign should target CTS outputs
`clkbuf_4_14__f_clk/X` (0.212506 pF versus 0.200000 pF) and
`clkbuf_4_12__f_clk/X` (0.205539 pF versus 0.200000 pF), plus the two named
antenna pins, with a narrowly supported clock-cluster or routing change
starting from `openlane/config.json`.

## Exact commands

Full RTL regression:

```sh
cd /home/pmoin/asic/markov-monkeys
scripts/run_regression.sh
```

The script uses this pattern for every test:

```sh
iverilog -g2012 -s TOP -o .codex_build/TEST.vvp RTL_SOURCES TB_SOURCE
vvp .codex_build/TEST.vvp
```

The exact source lists are recorded in `scripts/run_regression.sh`.

OpenLane 2.3.10 was invoked offline through the already installed local flake.
The standalone wrapper was not on the login shell's PATH:

```sh
cd /home/pmoin/asic/markov-monkeys
nix run --offline /home/pmoin/openlane2#openlane -- \
  openlane/config_parallel_exp06.json \
  --design-dir /home/pmoin/asic/markov-monkeys \
  --run-tag RUN_CODEX_PAR_FULL06_TWOITER_2026-07-28 \
  --condensed --hide-progress-bar -j 8
```

Every full experiment used the same command, substituting the config and run
tag recorded in `optimization/experiments.csv`. Before each launch:

```sh
df -h /home/pmoin
du -sh runs
```

At least 896 GB remained free throughout the campaign. No packages were
installed, no network access was used, no pre-existing run was deleted, and
no git commit, remote modification, push, or pull request was made.
