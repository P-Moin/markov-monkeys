# Markov Monkeys ASIC

A parameterized signed matrix-vector accelerator for iterative Markov-chain
computation, implemented in synthesizable SystemVerilog and taken through the
OpenLane 2 / Sky130A physical-design flow.

The project keeps a serial one-MAC implementation as a reference and uses an
N-lane parallel core for the optimized design. The convergence controller
compares consecutive state vectors using width-safe signed arithmetic and ends
a chain on convergence or iteration-budget exhaustion.

## Highlights

- Parameterized and verified for `N=1`, `N=4`, and `N=8`
- One MAC lane per output column in the parallel matrix-vector core
- Serial/parallel/software-reference equivalence testing
- Pipelined convergence comparison without increasing matrix-vector latency
- Complete OpenLane reruns for Experiments 00-20
- Published GDSII layouts from OpenLane, KLayout, and Magic

## Final candidate

The selected convergence candidate uses a 17 ns target clock. Its full-flow
rerun reports:

| Metric | Result |
|---|---:|
| Setup WNS / TNS | +0.7621 ns / 0 ns |
| Hold WNS / TNS | +0.1072 ns / 0 ns |
| Synthesis cells / area | 10,730 / 123,452.2 um² |
| Standard cells / instance area | 27,661 / 167,623 um² |
| Core area | 339,526 um² |
| Vectorless power | 10.2117 mW |
| Routed wire length | 577,559 um |
| Routing / Magic / KLayout DRC | 0 / 0 / 0 |
| LVS errors | 0 |
| Maximum capacitance violations | 0 |
| Maximum slew violations | 55 |
| Antenna violations | 4 nets / 4 pins |

The layout is timing-, DRC-, and LVS-clean, but it is **not signoff-clean**
because maximum-slew and antenna violations remain.

## Repository layout

```text
artifacts/gds/parallel_convergence/  Final GDSII layouts
docs/                                Architecture and implementation reports
openlane/                            Baseline and experiment configurations
optimization/                        Experiment log and selected configuration
results/full_metrics/                Comparable metrics for Experiments 00-20
rtl/compute/                         Matrix-vector datapath and storage
rtl/controller/                      Markov and convergence controllers
scripts/                             Regression, rerun, and metrics utilities
tb/                                  Directed and equivalence testbenches
```

## RTL architecture

For an `N x N` transition matrix `P` and state vector `X`, lane `j` computes:

```text
X_next[j] = sum(k=0 to N-1) X[k] * P[k][j]
```

During each feed cycle, `X[k]` is broadcast to all lanes while lane `j` reads
matrix element `P[k][j]`. The parallel core follows:

```text
IDLE -> FEED (N cycles) -> DRAIN -> CAPTURE -> IDLE
```

The current arithmetic policy is signed integer arithmetic. `FRAC_W` remains
in the legacy interface, but a fixed-point scaling and rounding policy has not
been defined.

## Run the RTL regression

Requirements: Icarus Verilog (`iverilog` and `vvp`).

```bash
scripts/run_regression.sh
```

The script stops on the first failure and checks every test for an unambiguous
`RESULT: PASS` line.

## Run OpenLane

Requirements: OpenLane 2, the Sky130A PDK, and `sky130_fd_sc_hd`.

```bash
openlane openlane/config_converge_exp09.json
```

The historical campaign used OpenLane 2.3.10 and open_pdks commit
`0fe599b2afb6708d281543108caf8310912f54af`. Full run products are intentionally
ignored because they are large and machine-specific; the final layouts and
machine-readable metrics are retained in the repository.

## Results and documentation

- [Final physical metrics](docs/final_physical_metrics.md)
- [Parallel convergence optimization](docs/parallel_convergence_optimization.md)
- [Parallel matrix-vector results](docs/parallel_matvec_results.md)
- [All historical experiment metrics](docs/all_experiment_metrics.md)
- [Comparable full-flow metrics](results/full_metrics/experiments_full_metrics.md)
- [Final GDSII artifacts](artifacts/gds/parallel_convergence/README.md)

## Reproduce the full metrics dataset

The campaign utilities accept a standard `openlane` executable by default. Set
`OPENLANE_COMMAND` if the installation requires a wrapper or Nix invocation.

```bash
python3 scripts/run_full_metrics_campaign.py --experiments 0-20
python3 scripts/aggregate_full_metrics.py
```

Each experiment receives its own detached Git worktree and output directory.
Existing run directories are never overwritten.
