# All Experiment Metrics

## Experiment #00

**Tuned:** Serial one-MAC reference baseline; no optimization parameter changed.

- Run/config: `openlane/runs/RUN_2026-07-28_14-16-12` / pre-existing
- Clock: 17 ns; N=8 latency: 66 cycles; rate: 0.891 Mops/s
- Synthesis: 4,575 cells; 61,388.9 um²
- Timing: setup slack/TNS +0.4350/0 ns; hold slack/TNS +0.1015/0 ns
- PPA: 17,727 standard cells; 99,793.2 um² instance area; 339,526 um² core; 6.2910 mW; 344,879 um wire
- Repair cells: 2,891 timing buffers; 5 antenna diodes
- Violations: slew 80; cap 0; fanout 732; antenna 0/0; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reference

## Experiment #01

**Tuned:** Replaced the serial datapath with the initial N-lane parallel matrix-vector architecture.

- Run: `RUN_CODEX_PAR_SYNTH_2026-07-28`
- Clock target: 17 ns; N=8 latency: 11 cycles; rate: 5.348 Mops/s
- Synthesis: 9,493 cells; 110,164.4 um²
- Physical metrics: N/A; synthesis-only run
- Result: continue to pre-PnR

## Experiment #02

**Tuned:** Initial parallel pre-PnR baseline with shared feed-index/reset distribution.

- Run: `RUN_CODEX_PAR_PREPNR_2026-07-28`
- Synthesis: 9,493 cells; 110,164.4 um²
- Timing: setup slack/TNS -5.5409/-1,479.9575 ns; hold slack/TNS +0.0443/0 ns
- Pre-PnR power: 4.4127 mW
- Violations: slew 6,228; cap 27; fanout 325
- Result: reject

## Experiment #03

**Tuned:** Added local per-lane feed-index (`k`) distribution registers.

- Run: `RUN_CODEX_PAR_PREPNR_KDIST_2026-07-28`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +2.3633/0 ns; hold slack/TNS +0.0226/0 ns
- Pre-PnR power: 5.9111 mW
- Violations: slew 5,754; cap 15; fanout 492
- Result: keep architecture

## Experiment #04

**Tuned:** Isolated local synchronous reset distribution without the retained feed-index change.

- Run: `RUN_CODEX_PAR_PREPNR_RST_2026-07-28`
- Synthesis: 9,403 cells; 110,284.5 um²
- Timing: setup slack/TNS -3.3927/-68.8602 ns; hold slack/TNS +0.0407/0 ns
- Pre-PnR power: 4.4228 mW
- Violations: slew 6,165; cap 27; fanout 313
- Result: reject in isolation

## Experiment #05

**Tuned:** First full N-lane parallel flow; 10 antenna iterations and 30% antenna margin.

- Run/config: `RUN_CODEX_PAR_FULL01_2026-07-28` / `openlane/config.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +0.5093/0 ns; hold slack/TNS +0.1034/0 ns
- PPA: 25,748 standard cells; 156,920 um² instance area; 339,526 um² core; 13.0125 mW; 542,207 um wire
- Repair cells: 3,934 timing buffers; 33 antenna diodes
- Violations: slew 175; cap 4; fanout 925; antenna 2/2, worst P/R 1.11; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #06

**Tuned:** Enabled post-global-routing design repair.

- Run/config: `RUN_CODEX_PAR_FULL02_POSTGRT_2026-07-28` / `openlane/config_parallel_exp02.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +0.5381/0 ns; hold slack/TNS +0.1031/0 ns
- PPA: 25,749 standard cells; 156,933 um² instance area; 339,526 um² core; 13.0003 mW; 542,052 um wire
- Repair cells: 3,937 timing buffers; 31 antenna diodes
- Violations: slew 173; cap 3; fanout 923; antenna 5/5, worst P/R 1.47; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #07

**Tuned:** Tightened electrical repair to 50% cap/slew targets and increased antenna repair to 20 iterations with 60% margin.

- Run/config: `RUN_CODEX_PAR_FULL03_ELECANT_2026-07-28` / `openlane/config_parallel_exp03.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +0.3319/0 ns; hold slack/TNS +0.0868/0 ns
- PPA: 26,137 standard cells; 158,055 um² instance area; 339,526 um² core; 12.9964 mW; 543,182 um wire
- Repair cells: 4,243 timing buffers; 117 antenna diodes
- Violations: slew 34; cap 2; fanout 928; antenna 3/3, worst P/R 1.24; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #08

**Tuned:** Lowered heuristic antenna threshold to 50 and set diode padding to 2.

- Run/config: `RUN_CODEX_PAR_FULL04_ANTPAD_2026-07-28` / `openlane/config_parallel_exp04.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS -0.3928/-2.1908 ns; hold slack/TNS +0.0851/0 ns
- PPA: 32,984 standard cells; 175,189 um² instance area; 339,526 um² core; 13.8211 mW; 610,017 um wire
- Repair cells: 4,243 timing buffers; 26 antenna diodes
- Violations: slew 499; cap 3; fanout 1,742; antenna 3/3, worst P/R 2.49; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #09

**Tuned:** Disabled heuristic diode insertion.

- Run/config: `RUN_CODEX_PAR_FULL05_NOHEUR_2026-07-28` / `openlane/config_parallel_exp05.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +1.2576/0 ns; hold slack/TNS +0.1000/0 ns
- PPA: 19,827 standard cells; 142,265 um² instance area; 339,526 um² core; 12.7389 mW; 528,906 um wire
- Repair cells: 4,243 timing buffers; 380 antenna diodes
- Violations: slew 21; cap 0; fanout 210; antenna 30 nets/34 pins, worst P/R 3.20; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #10

**Tuned:** Reduced antenna repair from 10 iterations to 2.

- Run/config: `RUN_CODEX_PAR_FULL06_TWOITER_2026-07-28` / `openlane/config_parallel_exp06.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +0.5414/0 ns; hold slack/TNS +0.0859/0 ns
- PPA: 26,037 standard cells; 157,805 um² instance area; 339,526 um² core; 12.9898 mW; 542,415 um wire
- Repair cells: 4,243 timing buffers; 17 antenna diodes
- Violations: slew 22; cap 2; fanout 923; antenna 2/2, worst P/R 1.08; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: selected parallel candidate

## Experiment #11

**Tuned:** Increased the two-iteration antenna margin from 30% to 40%.

- Run/config: `RUN_CODEX_PAR_FULL07_MARGIN40_2026-07-28` / `openlane/config_parallel_exp07.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +0.4723/0 ns; hold slack/TNS +0.0880/0 ns
- PPA: 26,042 standard cells; 157,818 um² instance area; 339,526 um² core; 12.9889 mW; 542,842 um wire
- Repair cells: 4,243 timing buffers; 22 antenna diodes
- Violations: slew 24; cap 2; fanout 923; antenna 4/4, worst P/R 1.35; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #12

**Tuned:** Reduced antenna repair from 2 iterations to 1.

- Run/config: `RUN_CODEX_PAR_FULL08_ONEITER_2026-07-28` / `openlane/config_parallel_exp08.json`
- Synthesis: 9,965 cells; 116,435.4 um²
- Timing: setup slack/TNS +0.4842/0 ns; hold slack/TNS +0.0869/0 ns
- PPA: 26,034 standard cells; 157,798 um² instance area; 339,526 um² core; 12.9912 mW; 542,677 um wire
- Repair cells: 4,243 timing buffers; 14 antenna diodes
- Violations: slew 32; cap 3; fanout 923; antenna 2/2, worst P/R 1.17; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #13

**Tuned:** Corrected normal parallel-controller restart/load/commit behavior.

- Run: `RUN_CODEX_PAR_SYNTH10_2026-07-29`
- Synthesis: 10,025 cells; 116,819.5 um²
- Physical metrics: N/A; synthesis-only run
- Result: keep RTL

## Experiment #14

**Tuned:** Added the initial unregistered convergence subtract/absolute-value/compare datapath.

- Run: `RUN_CODEX_CONV_SYNTH09_2026-07-29`
- Synthesis: 10,479 cells; 118,688.8 um²
- Physical metrics: N/A; synthesis-only run
- Result: continue to pre-PnR

## Experiment #15

**Tuned:** Measured the unregistered subtract-absolute-compare convergence path.

- Run/config: `RUN_CODEX_CONV_PREPNR11_2026-07-29` / `openlane/config_converge_exp09.json`
- Synthesis: 10,479 cells; 118,688.8 um²
- Timing: setup slack/TNS -9.1549/-17.7356 ns; hold slack/TNS +0.0227/0 ns
- Pre-PnR power: 4.6906 mW
- Violations: slew 4,751; cap 21; fanout 504
- Result: reject

## Experiment #16

**Tuned:** Registered convergence comparison operands and replaced subtract/absolute-value with parallel bounds; tolerance remained unregistered.

- Run/config: `RUN_CODEX_CONV_PREPNR12_PIPE_2026-07-29` / `openlane/config_converge_exp09.json`
- Synthesis: 10,583 cells; 122,063.3 um²
- Timing: setup slack/TNS -0.2703/-0.2703 ns; hold slack/TNS +0.0227/0 ns
- Pre-PnR power: 4.8109 mW
- Violations: slew 4,760; cap 19; fanout 509
- Result: reject

## Experiment #17

**Tuned:** Registered tolerance in addition to comparison operands.

- Run/config: `RUN_CODEX_CONV_PREPNR13_TOLREG_2026-07-29` / `openlane/config_converge_exp09.json`
- Synthesis: 10,730 cells; 123,452.2 um²
- Timing: setup slack/TNS +1.8365/0 ns; hold slack/TNS +0.0227/0 ns
- Pre-PnR power: 4.8426 mW
- Violations: slew 5,133; cap 18; fanout 506
- Result: keep architecture

## Experiment #18

**Tuned:** Full pipelined convergence implementation with 50% electrical repair targets, 2 antenna iterations, and 30% antenna margin.

- Run/config: `RUN_CODEX_CONV_FULL09_2026-07-29` / `openlane/config_converge_exp09.json`
- Clock: 17 ns; first N=8 iteration: 95 cycles; additional iterations: 32 cycles
- Synthesis: 10,730 cells; 123,452.2 um²
- Timing: setup slack/TNS +0.7621/0 ns; hold slack/TNS +0.1072/0 ns
- PPA: 27,661 standard cells; 167,623 um² instance area; 339,526 um² core; 10.2117 mW; 577,559 um wire
- Repair cells: 1,359 hold-repair buffers; 12 antenna diodes
- Violations: slew 55; cap 0; fanout 1,082; antenna 4/4, worst P/R 1.31; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: selected convergence candidate

## Experiment #19

**Tuned:** Increased convergence antenna repair from 2 iterations to 3.

- Run/config: `RUN_CODEX_CONV_ANT10_2026-07-29` / `openlane/config_converge_exp10.json`
- Synthesis reused: 10,730 cells; 123,452.2 um²
- Timing: setup slack/TNS +0.8403/0 ns; hold slack/TNS +0.1070/0 ns
- PPA: 27,662 standard cells; 167,626 um² instance area; 339,526 um² core; 10.2086 mW; 577,401 um wire
- Repair cells: 1,359 hold-repair buffers; 13 antenna diodes
- Violations: slew 50; cap 0; fanout 1,082; antenna 6/6, worst P/R 1.75; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject

## Experiment #20

**Tuned:** Tightened `DESIGN_REPAIR_MAX_SLEW_PCT` from 50% to 30%.

- Run/config: `RUN_CODEX_CONV_FULL11_SLEW30_2026-07-29` / `openlane/config_converge_exp11.json`
- Synthesis: 10,730 cells; 123,452.2 um²
- Timing: setup slack/TNS +0.6142/0 ns; hold slack/TNS +0.1049/0 ns
- PPA: 27,398 standard cells; 166,893 um² instance area; 339,526 um² core; 10.2238 mW; 576,981 um wire
- Repair cells: 1,361 hold-repair buffers; 10 antenna diodes
- Violations: slew 180; cap 0; fanout 1,083; antenna 5/5, worst P/R 1.66; route/Magic/KLayout DRC 0/0/0; LVS 0
- Result: reject
