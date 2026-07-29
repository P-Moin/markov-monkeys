# Final Parallel-Convergence Metrics

## Result

This report records the final measured metrics for the selected
parallel-convergence implementation:

`runs/RUN_CODEX_CONV_FULL09_2026-07-29`

The design passes the complete RTL regression and closes setup, hold, maximum
capacitance, routing DRC, Magic DRC, KLayout DRC, XOR, and LVS. It is
**near-clean, not signoff-clean**, because 55 maximum-slew violations, 1,082
reported maximum-fanout violations, and four antenna net/pin violations remain.

| Category | Final result |
|---|---:|
| RTL regression | PASS |
| Clock period | 17.000 ns |
| Operating frequency | 58.824 MHz |
| Worst setup slack | +0.762094 ns |
| Setup TNS | 0 ns |
| Worst hold slack | +0.107201 ns |
| Hold TNS | 0 ns |
| Synthesis cells | 10,730 |
| Synthesis cell area | 123,452.1504 um² |
| Post-route standard cells | 27,661 |
| Post-route instance area | 167,623 um² |
| Core area | 339,526 um² |
| Die area | 360,000 um² |
| Final instance utilization | 49.3698% |
| Worst-corner vectorless power | 10.211721 mW |
| Nominal-TT vectorless power | 8.693757 mW |
| Routed wire length | 577,559 um |
| Routing vias | 119,045 |
| Maximum slew violations | 55 |
| Maximum capacitance violations | 0 |
| Maximum fanout violations | 1,082 |
| Antenna violations | 4 nets / 4 pins |
| Routing/Magic/KLayout DRC | 0 / 0 / 0 |
| LVS errors | 0 |

OpenLane reports violation-only `timing__setup__wns` and
`timing__hold__wns` as zero when no path violates. The positive values above
come from the corresponding worst-slack (`timing__*__ws`) metrics and STA
reports.

## Provenance and conditions

| Item | Value |
|---|---|
| Top module | `markov_top_converge` |
| Architecture | N-lane, one signed MAC lane per output column |
| Default parameters | N=8, DW=8, ACC_W=32 |
| Process design kit | Sky130A |
| Standard-cell library | `sky130_fd_sc_hd` |
| OpenLane | 2.3.10, existing local offline flake |
| Selected configuration | `openlane/config_converge_exp09.json` |
| Run tag | `RUN_CODEX_CONV_FULL09_2026-07-29` |
| Clock | `clk`, 17 ns |
| Configured core utilization | 35% |
| Placement target density | 45% |
| Maximum fanout constraint | 6 |
| CTS maximum capacitance | 0.15 pF |
| Global/detailed placement padding | 1 / 1 site |
| Heuristic diode insertion | enabled |
| Antenna repair iterations | 2 |
| Antenna margin | 30% |

The run was executed from base commit `e8d7349` plus the documented
parallel-convergence working-tree changes. Those source, test, configuration,
and documentation changes were subsequently committed as `546fdb9`. The final
GDS artifacts were added in commit `4f96e01`.

Primary metric sources:

- `runs/RUN_CODEX_CONV_FULL09_2026-07-29/final/metrics.json`
- `runs/RUN_CODEX_CONV_FULL09_2026-07-29/06-yosys-synthesis/reports/stat.rpt`
- `runs/RUN_CODEX_CONV_FULL09_2026-07-29/55-openroad-stapostpnr/`
- `runs/RUN_CODEX_CONV_FULL09_2026-07-29/46-openroad-checkantennas-1/reports/`
- `runs/RUN_CODEX_CONV_FULL09_2026-07-29/75-misc-reportmanufacturability/manufacturability.rpt`

## Functional verification

The regression was rerun before publishing this report:

```sh
cd /home/pmoin/asic/markov-monkeys
scripts/run_regression.sh
```

| Test group | Tests/checks | Result |
|---|---:|---:|
| Signed pipelined MAC | 351 checks | PASS |
| Memory | 552 checks | PASS |
| N=4 serial/parallel/software equivalence | 46 tests, 923 checks | PASS |
| N=8 serial/parallel/software equivalence | 46 tests, 1,475 checks | PASS |
| N=1 signed directed result | serial = parallel = -35 | PASS |
| Three-iteration Markov protocol | 75 cycles | PASS |
| Normal controller/software model | 25 tests, 200 checks | PASS |
| N=8 convergence/software model | 32 tests, 352 checks | PASS |
| N=4 convergence/software model | 32 tests, 224 checks | PASS |
| Width-safe extrema comparator | 11 checks | PASS |

The run covers deterministic reset/read behavior, back-to-back operations,
busy-time start/load rejection, signed arithmetic, final-product capture,
one-cycle `done` and `chain_done`, convergence versus exhaustion, exact and
off-by-one tolerance, final-element-only decisions, repeated chains, signed
extrema, and deterministic random cases.

No official staff UVM environment is present, so no UVM result is claimed.

## Latency and throughput

The measured and architectural latency formulas are:

| Operation | Cycle formula | N=8 cycles | Time at 17 ns | Rate |
|---|---:|---:|---:|---:|
| Serial matrix-vector | `N*N + 2` | 66 | 1.122 us | 0.891 Mops/s |
| Parallel matrix-vector | `N + 3` | 11 | 187 ns | 5.348 Mops/s |
| First N=8 convergence iteration, including load | measured | 95 | 1.615 us | 0.619 Miter/s |
| Each additional N=8 convergence iteration | 32 | 32 | 544 ns | 1.838 Miter/s |

The N=8 parallel matrix-vector core is 6.0x faster than the serial reference
at the same clock. The measured N=8 chain formula is:

`chain_cycles(iterations) = 95 + 32 * (iterations - 1)`

| Iterations | Total cycles | Time at 17 ns | Average iteration rate |
|---:|---:|---:|---:|
| 1 | 95 | 1.615 us | 0.619 Miter/s |
| 2 | 127 | 2.159 us | 0.926 Miter/s |
| 3 | 159 | 2.703 us | 1.110 Miter/s |
| 4 | 191 | 3.247 us | 1.232 Miter/s |

The positive worst setup slack suggests a simple same-parasitic lower-period
estimate of 16.237906 ns, or 61.585 MHz. This is only an extrapolation; no
physical run below 17 ns was performed, so the supported reported operating
point remains 58.824 MHz.

## Synthesis

| Metric | Value |
|---|---:|
| Wires / wire bits | 10,707 / 11,360 |
| Public wires / bits | 1,703 / 2,356 |
| Ports / port bits | 11 / 664 |
| Memories / memory bits | 0 / 0 |
| Processes | 0 |
| Mapped cells | 10,730 |
| Sequential cells | 1,711 |
| Combinational cells | 9,019 |
| Total mapped area | 123,452.1504 um² |
| Sequential area | 37,099.3312 um² |
| Sequential area fraction | 30.05% |
| Inferred latches | 0 |
| Unmapped cells | 0 |
| Synthesis check errors | 0 |

The largest mapped cell categories are 1,570 `dfxtp`, 1,547 two-input muxes,
718 NAND2, 717 NOR2, 496 OR2, 429 A21O, 401 XNOR2, 303 A21OI, and 267 A22O
cells. The full cell histogram is retained in the Yosys `stat.rpt` source.

## Floorplan, placement, and area

| Metric | Value |
|---|---:|
| Die bounding box | (0, 0) to (600, 600) um |
| Die area | 360,000 um² |
| Core bounding box | (5.52, 10.88) to (594.32, 587.52) um |
| Core area | 339,526 um² |
| Post-route standard-cell count | 27,661 |
| Post-route instance area | 167,623 um² |
| Macro count / area | 0 / 0 um² |
| Final standard-cell utilization | 49.3698% |
| Final I/O metric | 666 |
| Critical disconnected pins | 0 |
| All disconnected pins | 0 |

OpenLane also records 1,359 hold buffers, zero setup buffers, 4,347
timing-repair buffers, 332 clock buffers, 148 clock inverters, 158 regular
inverters, seven regular buffers, 21,479 fill cells, and 4,815 tap/endcap
cells. These class counters are captured at different flow stages and are not
intended to be summed into the 27,661 standard-cell snapshot.

## Post-route timing

Every setup and hold corner has zero TNS and zero violating paths.

| Corner | Setup worst slack (ns) | Setup TNS (ns) | Hold worst slack (ns) | Hold TNS (ns) |
|---|---:|---:|---:|---:|
| max FF, -40 C, 1.95 V | +8.656363 | 0 | +0.110544 | 0 |
| max SS, 100 C, 1.60 V | +0.762094 | 0 | +0.618566 | 0 |
| max TT, 25 C, 1.80 V | +7.220031 | 0 | +0.320797 | 0 |
| min FF, -40 C, 1.95 V | +8.800603 | 0 | +0.107201 | 0 |
| min SS, 100 C, 1.60 V | +2.093492 | 0 | +0.856549 | 0 |
| min TT, 25 C, 1.80 V | +7.650808 | 0 | +0.313369 | 0 |
| nominal FF, -40 C, 1.95 V | +8.725625 | 0 | +0.108808 | 0 |
| nominal SS, 100 C, 1.60 V | +1.344459 | 0 | +0.741963 | 0 |
| nominal TT, 25 C, 1.80 V | +7.459079 | 0 | +0.316821 | 0 |

### Critical paths

Worst setup:

- corner: max SS, 100 C, 1.60 V
- startpoint: `_18264_`, the `load_count[1]` flip-flop
- endpoint: `_18708_`
- slack: +0.762094 ns
- dominant logic: loader-address fanout and decode network

Worst hold:

- corner: min FF, -40 C, 1.95 V
- startpoint: `_19403_`
- endpoint: `_19371_`
- data: parallel MAC lane 1 `product_ext[4]`
- slack: +0.107201 ns

The convergence comparator is not the final critical path. Registering its
operands and tolerance removed the former asynchronous read/comparator path.

### Clock skew

| Corner | Setup skew metric (ns) | Hold skew metric (ns) |
|---|---:|---:|
| max FF, -40 C, 1.95 V | +0.428933 | -0.415787 |
| max SS, 100 C, 1.60 V | +0.696788 | -0.660265 |
| max TT, 25 C, 1.80 V | +0.507364 | -0.487474 |
| min FF, -40 C, 1.95 V | +0.413279 | -0.400436 |
| min SS, 100 C, 1.60 V | +0.661648 | -0.632856 |
| min TT, 25 C, 1.80 V | +0.489047 | -0.470892 |
| nominal FF, -40 C, 1.95 V | +0.421482 | -0.406836 |
| nominal SS, 100 C, 1.60 V | +0.680381 | -0.646831 |
| nominal TT, 25 C, 1.80 V | +0.498748 | -0.477704 |

STA records 220 raw unannotated nets per corner, but all are filtered as
non-critical (`unannotated_net_filtered_count=0`). Floating timing nets and
pins are both zero.

## Power

Power is OpenROAD vectorless estimation, not measured silicon power. The
reported activity assumptions are suitable for comparing this run internally
but not for claiming workload-specific energy.

| Corner | Internal (mW) | Switching (mW) | Leakage (mW) | Total (mW) |
|---|---:|---:|---:|---:|
| max FF, -40 C, 1.95 V | 7.434654 | 2.776892 | 0.000175 | 10.211721 |
| max SS, 100 C, 1.60 V | 5.088844 | 1.818955 | 0.095703 | 7.003502 |
| max TT, 25 C, 1.80 V | 6.438844 | 2.347902 | 0.000098 | 8.786845 |
| min FF, -40 C, 1.95 V | 7.435382 | 2.554076 | 0.000175 | 9.989633 |
| min SS, 100 C, 1.60 V | 5.089164 | 1.668943 | 0.095703 | 6.853811 |
| min TT, 25 C, 1.80 V | 6.439181 | 2.158038 | 0.000098 | 8.597316 |
| nominal FF, -40 C, 1.95 V | 7.435233 | 2.667394 | 0.000175 | 10.102802 |
| nominal SS, 100 C, 1.60 V | 5.089100 | 1.745235 | 0.095703 | 6.930038 |
| nominal TT, 25 C, 1.80 V | 6.439061 | 2.254598 | 0.000098 | 8.693757 |

At nominal TT, the power groups are:

| Group | Total power | Share |
|---|---:|---:|
| Sequential | 4.012117 mW | 46.1% |
| Combinational | 0.361383 mW | 4.2% |
| Clock | 4.320253 mW | 49.7% |
| Macro/pad | 0 mW | 0% |

The clock network is the largest nominal-TT power component.

## Electrical constraints

| Corner | Max-slew violations | Max-cap violations | Max-fanout violations |
|---|---:|---:|---:|
| max FF, -40 C, 1.95 V | 0 | 0 | 1,082 |
| max SS, 100 C, 1.60 V | 55 | 0 | 1,082 |
| max TT, 25 C, 1.80 V | 0 | 0 | 1,082 |
| min FF, -40 C, 1.95 V | 0 | 0 | 1,082 |
| min SS, 100 C, 1.60 V | 9 | 0 | 1,082 |
| min TT, 25 C, 1.80 V | 0 | 0 | 1,082 |
| nominal FF, -40 C, 1.95 V | 0 | 0 | 1,082 |
| nominal SS, 100 C, 1.60 V | 16 | 0 | 1,082 |
| nominal TT, 25 C, 1.80 V | 0 | 0 | 1,082 |

The global count is the worst per-corner count, not the sum across corners.
The worst slew is 0.955049 ns against a 0.750000 ns limit, a 0.205049 ns
violation, at `_17169_/A2` and `max_cap743/A`. The violating set is dominated
by a small number of diode-loaded data nets. Maximum capacitance is clean at
all nine corners.

The 1,082 maximum-fanout count is also reported at every corner despite
`MAX_FANOUT_CONSTRAINT=6`; therefore the design does not meet a zero-fanout-
violation objective even though timing and capacitance close.

## Routing and interconnect

| Metric | Value |
|---|---:|
| Routed signal nets | 15,974 |
| Special nets | 2 |
| Routed wire length | 577,559 um |
| Estimated wire length | 529,752 um |
| Longest routed net | 989.19 um |
| Single-cut vias | 119,045 |
| Multi-cut vias | 0 |
| Final detailed-route DRC | 0 |

Detailed-routing DRC errors fell across iterations as follows:

`7,929 -> 4,164 -> 3,791 -> 534 -> 94 -> 0`

## Physical verification and manufacturability

| Check | Result |
|---|---:|
| TritonRoute/final routing DRC | 0 errors |
| Magic DRC | 0 errors |
| KLayout DRC | 0 errors |
| Magic illegal overlap | 0 |
| KLayout XOR differences | 0 |
| LVS errors | 0 |
| LVS device differences | 0 |
| LVS net differences | 0 |
| LVS property failures | 0 |
| LVS unmatched devices/nets/pins | 0 / 0 / 0 |
| Power-grid violations | 0 |
| Antenna | FAIL, 4 nets / 4 pins |

### Remaining antenna violations

| P/R | Partial | Required | Net | Pin | Layer |
|---:|---:|---:|---|---|---|
| 1.31 | 522.67 | 400.00 | `net1893` | `_10335_/C` | met1 |
| 1.26 | 503.34 | 400.00 | `net924` | `fanout923/A` | met1 |
| 1.22 | 487.25 | 400.00 | `net1267` | `fanout1266/A` | met1 |
| 1.20 | 480.22 | 400.00 | `convergence_cmp.tol_ext[7]` | `_12013_/A0` | met1 |

Twelve antenna-repair diodes were inserted. Four violations remain, so the
manufacturability report correctly marks antenna as failed.

## Power integrity

| Metric | Value |
|---|---:|
| Average IR drop | 0.0000743 V |
| Worst VPWR drop | 0.000668011 V |
| Worst VGND rise | 0.000677955 V |
| Worst VPWR voltage | 1.79933 V |
| Power-grid violation count | 0 |

These are nominal-TT static power-grid estimates from the implemented design.

## Final GDS artifacts

The published branch contains all three final stream-outs:

| Artifact | Size | SHA-256 |
|---|---:|---|
| `final/gds/markov_top_converge.gds` | 40,910,110 bytes | `043643eee7f28b768d9da2f27d392c7a9881e9627cd9d27da74e2533a833af5a` |
| `final/mag_gds/markov_top_converge.magic.gds` | 40,910,110 bytes | `043643eee7f28b768d9da2f27d392c7a9881e9627cd9d27da74e2533a833af5a` |
| `final/klayout_gds/markov_top_converge.klayout.gds` | 18,873,746 bytes | `444c4912bf06197407b2b2585e9a0c2fabb4c5f810287bbd555d30a56fb0ea3e` |

The generic final stream-out and the explicitly named Magic stream-out are
byte-identical. The KLayout stream-out is distinct. All three were validated
as GDSII stream files before publication.

## Final acceptance summary

| Requirement | Status |
|---|---|
| All RTL regressions pass | PASS |
| Serial/parallel/software equivalence | PASS |
| Convergence matches software model | PASS |
| Setup WNS >= 0 and TNS = 0 | PASS |
| Hold WNS >= 0 and TNS = 0 | PASS |
| Maximum capacitance = 0 | PASS |
| Routing, Magic, and KLayout DRC = 0 | PASS |
| LVS = 0 | PASS |
| Maximum slew = 0 | **FAIL: 55** |
| Maximum fanout = 0 | **FAIL: 1,082** |
| Antenna = 0 | **FAIL: 4 nets / 4 pins** |

The final candidate is functionally correct and timing/DRC/LVS clean at the
17 ns operating point, but it must not be described as signoff-clean while
slew, fanout, and antenna violations remain.

## Reproduction

RTL regression:

```sh
cd /home/pmoin/asic/markov-monkeys
scripts/run_regression.sh
```

Full OpenLane run:

```sh
cd /home/pmoin/asic/markov-monkeys
df -h /home/pmoin
du -sh runs
nix run --offline /home/pmoin/openlane2#openlane -- \
  openlane/config_converge_exp09.json \
  --design-dir /home/pmoin/asic/markov-monkeys \
  --run-tag RUN_CODEX_CONV_FULL09_2026-07-29 \
  --condensed --hide-progress-bar -j 8
```

Inspect the final metrics:

```sh
python3 -m json.tool \
  runs/RUN_CODEX_CONV_FULL09_2026-07-29/final/metrics.json

sed -n '1,220p' \
  runs/RUN_CODEX_CONV_FULL09_2026-07-29/06-yosys-synthesis/reports/stat.rpt

cat \
  runs/RUN_CODEX_CONV_FULL09_2026-07-29/46-openroad-checkantennas-1/reports/antenna_summary.rpt

cat \
  runs/RUN_CODEX_CONV_FULL09_2026-07-29/75-misc-reportmanufacturability/manufacturability.rpt
```

No package was installed, no prior run was deleted, and no metric in this
report is inferred from successful flow completion alone.
