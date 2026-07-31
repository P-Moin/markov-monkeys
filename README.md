# Markov Monkeys

BWSI ASIC capstone project implementing a signed Markov-chain
matrix-vector engine in SystemVerilog.

The integrated `matmul_top` selects an N-lane parallel implementation by
default and retains the one-MAC serial engine as a parameter-selectable
reference. Current arithmetic is integer; `FRAC_W` is present in the legacy
interface but fixed-point conversion has not yet been specified or implemented.

See [docs/PARALLEL_MATVEC_RESULTS.md](docs/PARALLEL_MATVEC_RESULTS.md) for the
architecture, verification, cycle-count, synthesis, OpenLane, and signoff
results.
