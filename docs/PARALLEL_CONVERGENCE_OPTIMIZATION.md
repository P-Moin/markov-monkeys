# Parallel Matrix-Vector and Convergence Optimization

## Outcome

The existing N-lane column-parallel architecture was retained and optimized.
The final RTL passes the repository regression in serial, parallel, normal
controller, and convergence-controller configurations. The selected 17 ns
physical candidate is:

`runs/RUN_CODEX_CONV_FULL09_2026-07-29`

It passes setup and hold at all nine reported PVT corners, max capacitance,
routing/Magic/KLayout DRC, and LVS. It is **not signoff-clean** because 55
max-slew violations and four antenna nets remain.

## Original architecture

The parallel core has one signed MAC lane per output column. During FEED cycle
`k`, `X[k]` is broadcast and lane `j` reads row-major matrix address `k*N+j`.
Each lane computes:

`X_next[j] = sum(k=0..N-1) X[k] * P[k][j]`

The compute schedule remains `IDLE -> FEED(N) -> DRAIN -> CAPTURE -> IDLE`.
The wrapper parameter `USE_PARALLEL` still selects the parallel core or the
embedded one-MAC `serial_matvec_core` without changing the external protocol.

The convergence controller preserves the old vector in state memory while it
reads and commits each new result. Comparison and commit therefore share one
pass; no additional full-vector read pass is required.

## Correctness issues identified and fixed

| Issue | Effect | Resolution |
|---|---|---|
| `first_pass` only reset by global reset | A second independent chain reused the prior state and could skip a changed matrix | Every accepted chain start reloads P and the new initial X; only feedback iterations skip P |
| Raw `start` also drove the loader while a chain was active | A busy-time start could disturb loader state | Added an explicit LOAD controller state and gated new-chain starts to IDLE |
| Both controllers declared `module markov_top` | Duplicate-module errors when compiled together | Convergence top renamed `markov_top_converge`; both files now compile together |
| External state read address fed the wide convergence arithmetic | Pre-PnR slow-corner setup WNS was -9.1549 ns | Registered old/new comparison operands and the tolerance |
| Subtract, conditional negation, then compare formed a serial wide path | Long 33-bit arithmetic depth | Replaced it with parallel, width-safe extended lower/upper-bound checks |
| Result storage was unreadable deterministically after reset | Valid in-range reads could expose uninitialized storage | Added one `results_valid` bit per compute engine and return zero until completion |
| Regression trusted simulator exit status alone | A `$finish` after `RESULT: FAIL` could still return success | Every run must contain exactly `RESULT: PASS`, otherwise the script exits nonzero |
| Random tolerance generation produced negative integers | Negative display values became large unsigned tolerances | Added a deterministic seed and explicit 0..15 normalization |

The comparator uses `WIDTH+2` signed bounds, so `old ± tolerance` cannot
overflow for signed extrema and a full-width unsigned tolerance. Directed
tests cover `INT32_MIN`, `INT32_MAX`, exact tolerance, one above tolerance,
and both subtraction directions.

## Convergence behavior

The first computed vector is always committed but never declares convergence.
For every later vector element:

`abs(new-old) <= tolerance`

is implemented as an inclusive interval comparison. A registered operand pair
is compared while the next pair is captured. On the final element, the
EVALUATE edge consumes the final comparison and commits the final registered
state-memory write. `chain_done` is therefore exactly one cycle and is never
asserted before final state readback is valid.

`max_cycles=0` preserves the repository's documented/tested behavior: execute
one iteration and stop with `converged=0`. Exhaustion and convergence are
distinguished by `converged`; `chain_done` pulses for either termination
reason.

## Numeric policy

The repository is signed-integer, not fixed-point:

- state and probability inputs are signed INT8
- product width is 16 bits
- products are sign-extended into a 32-bit accumulator
- result readback is 32 bits
- feedback takes the low 8 bits, with two's-complement wraparound
- convergence tolerance and differences are in integer accumulator units

`FRAC_W` remains interface-compatible but inactive. No right shift, rounding,
or saturation policy was invented. Tests explicitly exercise signed extrema
and the existing feedback truncation behavior.

## Verification results

Final command:

```sh
cd /home/pmoin/asic/markov-monkeys
scripts/run_regression.sh
```

The script uses `iverilog -g2012` and `vvp`, stops at the first compile/run
failure, and rejects a test that does not emit an unambiguous pass marker.

| Test | Final result |
|---|---:|
| Signed pipelined MAC | 351 checks, PASS |
| Memory | 552 checks, PASS |
| N=4 serial/parallel/software equivalence | 46 tests, 923 checks, PASS |
| N=8 serial/parallel/software equivalence | 46 tests, 1,475 checks, PASS |
| N=1 signed result | serial = parallel = -35, PASS |
| Three-iteration normal protocol | 75 cycles, PASS |
| Normal controller model | 25 tests, 200 checks, PASS |
| N=8 convergence model | 32 tests, 352 checks, PASS |
| N=4 convergence model | 32 tests, 224 checks, PASS |
| Standalone extrema comparator | 11 checks, PASS |

Coverage includes identity, zero, deterministic and nonsymmetric matrices,
final-k dependence, signed maximum/minimum inputs, N=1/N=4/N=8, back-to-back
compute, start/load while busy, idle/active reset, invalid and disabled reads,
one-cycle `done`, one-cycle `chain_done`, first-iteration suppression, exact
tolerance, one above tolerance, final-element-only convergence/failure,
exhaustion, unchanged and oscillating vectors, signed zero crossing, large
tolerance, and repeated independent chain starts. Random seeds are fixed.

No official staff UVM environment exists in this repository, so no UVM score
is claimed.

## Latency and operation rate

| Engine | Cycle formula | N=8 cycles | At 17 ns | Completed operations/s |
|---|---:|---:|---:|---:|
| Serial one-MAC | `N*N+2` | 66 | 1,122 ns | 0.891 M |
| Parallel N-lane | `N+3` | 11 | 187 ns | 5.348 M |

The N=8 parallel compute core remains 6.0x faster. At the signed-off 17 ns
period, clock frequency is 58.824 MHz.
Using the positive worst setup slack as a simple estimate gives 61.58 MHz
(`1/(17 ns - 0.7621 ns)`), but no period below 17 ns was physically signed
off, so 58.824 MHz is the reported operating frequency.

The measured convergence chain formula for N=8 is:

`chain_cycles(iterations) = 95 + 32*(iterations-1)`

| Iterations | Total cycles | Time at 17 ns |
|---:|---:|---:|
| 1 | 95 | 1.615 us |
| 2 | 127 | 2.159 us |
| 3 | 159 | 2.703 us |
| 4 | 191 | 3.247 us |

After the initial matrix/vector load, each feedback iteration costs 32 cycles,
for a steady incremental rate of 1.838 million Markov iterations/s. The
comparison pipeline uses the already-required final commit slot, so it adds no
chain cycle. No frequency-versus-latency tradeoff was needed.

## Synthesis comparison

| Design point | Cells | Area (um2) | Slow pre-PnR setup |
|---|---:|---:|---:|
| Earlier selected parallel controller | 9,965 | 116,435.4 | pass after physical repair |
| Corrected normal parallel controller | 10,025 | 116,819.5 | not the final top |
| Unpipelined convergence comparator | 10,479 | 118,688.8 | WNS -9.1549 ns, TNS -17.7356 ns |
| Final pipelined convergence top | 10,730 | 123,452.2 | WNS +1.8365 ns, TNS 0 |

The 4.0% area increase from the unpipelined convergence point buys an 10.99 ns
pre-PnR WNS improvement without latency loss.

## Physical before/after comparison

The "before" column is the prior selected parallel non-convergence run
`RUN_CODEX_PAR_FULL06_TWOITER_2026-07-28`. The final column is the actual
convergence top.

| Metric | Prior parallel | Selected convergence | Result |
|---|---:|---:|---|
| Setup worst slack | +0.5414 ns | +0.7621 ns | pass, improved |
| Setup TNS | 0 | 0 | pass |
| Hold worst slack | +0.0859 ns | +0.1072 ns | pass, improved |
| Hold TNS | 0 | 0 | pass |
| Max slew | 22 | 55 | remaining, worse |
| Max capacitance | 2 | 0 | cleared |
| Antenna nets/pins | 2 / 2 | 4 / 4 | remaining, worse |
| Routing DRC | 0 | 0 | pass |
| Magic DRC | 0 | 0 | pass |
| KLayout DRC | 0 | 0 | pass |
| LVS | 0 | 0 | pass |
| Standard cells | 26,037 | 27,661 | +6.2% |
| Instance area | 157,805 um2 | 167,623 um2 | +6.2% |
| Core area | 339,526 um2 | 339,526 um2 | unchanged |
| Routed wire length | 542,415 um | 577,559 um | +6.5% |
| OpenLane reported power | 0.012990 W | 0.010212 W | -21.4%* |
| Nominal TT power report | not previously tabulated | 0.008694 W | estimate |
| Hold-repair buffers | 4,243 prior timing buffers | 1,359 | different top/flow point |
| Antenna-repair diodes | 17 | 12 | reduced |

`*` Power is vectorless OpenLane estimation; the design top and activity
assumptions differ, so this is directional rather than a measured workload
energy comparison.

## Critical path and fanout analysis

The selected worst setup path is at `max_ss_100C_1v60`, from flip-flop
`_18264_` (`load_count[1]`) to `_18708_`. It traverses the loader address
fanout/decode network and has +0.7621 ns slack. It is not the convergence
comparator or a multiplier path.

Before operand registration, the worst path started at external
`rd_vec_addr[0]`, crossed the asynchronous state-memory read mux and the wide
comparator, and ended at a controller flop with -9.1549 ns slack. Registering
comparison inputs removed that external-to-arithmetic path. Registering
`tolerance` then moved pre-PnR WNS from -0.2703 ns to +1.8365 ns.

The remaining max-slew report is dominated by a small number of diode-loaded
data drivers. The worst slew is 0.955049 ns versus a 0.750000 ns limit.
Several reported violations are multiple sink/diode pins on the same net.
The clock tree has no max-cap violation in the selected candidate.

## Physical experiments

| Experiment | Change | Setup / hold | Slew | Cap | Antenna | DRC/LVS | Decision |
|---|---|---:|---:|---:|---:|---|---|
| convergence pre-PnR | original subtract/abs/compare | -9.1549 / +0.0227 ns | 4,751 pre-PnR | 21 | n/a | n/a | reject RTL |
| pipelined pre-PnR | registered operands and tolerance; parallel bounds | +1.8365 / +0.0227 ns | 5,133 pre-PnR | 18 | n/a | n/a | keep RTL |
| `FULL09` | two antenna iterations, slew target 50% | +0.7621 / +0.1072 ns | 55 | 0 | 4, worst 1.31 | all zero | selected |
| `ANT10` | antenna ceiling 2 -> 3 only | +0.8403 / +0.1070 ns | 50 | 0 | 6, worst 1.75 | all zero | reject |
| `FULL11` | slew target 50% -> 30% only | +0.6142 / +0.1049 ns | 180 | 0 | 5, worst 1.66 | all zero | reject |

All new experiments use commit `e8d7349` plus the documented working-tree RTL.
Unless a row states otherwise, core utilization is 35%, placement density is
45%, CTS max capacitance is 0.15 pF, sink clustering uses the resolved defaults
of size 25 and 50 um maximum diameter, and the clock period is 17 ns.

The extra antenna allowance created two more violations. The tighter
pre-route slew target caused over-repair/routing interactions and more than
tripled final slew violations. Neither change was combined speculatively.

## Final violation summary

All nine setup and hold corners have nonnegative slack and zero TNS. Max
capacitance, routing DRC, Magic DRC, KLayout DRC, and LVS are zero.

Remaining antenna violations:

| P/R | Partial / required | Net | Pin | Layer |
|---:|---:|---|---|---|
| 1.31 | 522.67 / 400.00 | `net1893` | `_10335_/C` | met1 |
| 1.26 | 503.34 / 400.00 | `net924` | `fanout923/A` | met1 |
| 1.22 | 487.25 / 400.00 | `net1267` | `fanout1266/A` | met1 |
| 1.20 | 480.22 / 400.00 | `convergence_cmp.tol_ext[7]` | `_12013_/A0` | met1 |

Max-slew counts are 55 at max-SS, 16 at nominal-SS, and 9 at min-SS; all
other corners are zero. Because these violations remain, the result is
near-clean and must not be described as signoff-clean.

The most evidence-supported next change is a post-diode, localized electrical
repair of the small set of violating drivers, followed by localized antenna
jumper/diode repair on the four named pins. The stock Classic flow performs
design repair before diode insertion, so simply tightening the global
pre-route target did not solve the diode-loaded nets. A custom ordered flow or
standalone OpenROAD repair step should be tested on a copy of the selected
post-antenna state, not by increasing global antenna iterations again.

## Reproduction commands

Tool versions/availability:

```sh
command -v iverilog
command -v vvp
nix run --offline /home/pmoin/openlane2#openlane -- --version
```

Regression:

```sh
cd /home/pmoin/asic/markov-monkeys
scripts/run_regression.sh
```

Pre-PnR architecture evidence:

```sh
nix run --offline /home/pmoin/openlane2#openlane -- \
  openlane/config_converge_exp09.json \
  --design-dir /home/pmoin/asic/markov-monkeys \
  --run-tag RUN_CODEX_CONV_PREPNR13_TOLREG_2026-07-29 \
  --to OpenROAD.STAPrePNR --condensed --hide-progress-bar -j 8
```

Selected full run:

```sh
df -h /home/pmoin
du -sh runs
nix run --offline /home/pmoin/openlane2#openlane -- \
  openlane/config_converge_exp09.json \
  --design-dir /home/pmoin/asic/markov-monkeys \
  --run-tag RUN_CODEX_CONV_FULL09_2026-07-29 \
  --condensed --hide-progress-bar -j 8
```

Isolated antenna rerun:

```sh
nix run --offline /home/pmoin/openlane2#openlane -- \
  openlane/config_converge_exp10.json \
  --design-dir /home/pmoin/asic/markov-monkeys \
  --run-tag RUN_CODEX_CONV_ANT10_2026-07-29 \
  --from OpenROAD.RepairAntennas \
  --with-initial-state \
  runs/RUN_CODEX_CONV_FULL09_2026-07-29/41-odb-heuristicdiodeinsertion/state_out.json \
  --condensed --hide-progress-bar -j 8
```

Slew-target full run:

```sh
nix run --offline /home/pmoin/openlane2#openlane -- \
  openlane/config_converge_exp11.json \
  --design-dir /home/pmoin/asic/markov-monkeys \
  --run-tag RUN_CODEX_CONV_FULL11_SLEW30_2026-07-29 \
  --condensed --hide-progress-bar -j 8
```

All commands used the existing local OpenLane 2.3.10 flake and PDK without
network access or package installation. No prior run was deleted.
