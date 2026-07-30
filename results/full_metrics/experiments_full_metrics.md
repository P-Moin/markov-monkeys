# Experiments Full Metrics

| Exp | Tuned parameter / architecture | Setup WNS (ns) | Hold WNS (ns) | Cells | Area (um²) | Power (mW) | Slew | Cap | Antenna nets | DRC M/K/R | LVS |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|
| 00 | serial one-MAC reference baseline | 0.4350 | 0.1015 | 17727 | 99793.2000 | 6.2910 | 80 | 0 | 0 | 0/0/0 | 0 |
| 01 | initial N-lane parallel architecture | -0.7642 | 0.0939 | 25516 | 151488 | 9.1465 | 248 | 0 | 0 | 0/0/0 | 0 |
| 02 | initial parallel pre-PnR baseline with shared feed-index/reset distribution | -0.7642 | 0.0939 | 25516 | 151488 | 9.1465 | 248 | 0 | 0 | 0/0/0 | 0 |
| 03 | local per-lane feed-index distribution registers | 0.5093 | 0.1034 | 25748 | 156920 | 13.0125 | 175 | 4 | 2 | 0/0/0 | 0 |
| 04 | local synchronous reset distribution without retained feed-index change | 0.0739 | 0.0906 | 24923 | 149181 | 8.5888 | 156 | 1 | 1 | 0/0/0 | 0 |
| 05 | first full N-lane parallel flow | 0.5093 | 0.1034 | 25748 | 156920 | 13.0125 | 175 | 4 | 2 | 0/0/0 | 0 |
| 06 | post-global-routing design repair | 0.5381 | 0.1031 | 25749 | 156933 | 13.0003 | 173 | 3 | 5 | 0/0/0 | 0 |
| 07 | tighter electrical repair and increased antenna repair | 0.3319 | 0.0868 | 26137 | 158055 | 12.9964 | 34 | 2 | 3 | 0/0/0 | 0 |
| 08 | lower heuristic antenna threshold and diode padding | -0.3928 | 0.0851 | 32984 | 175189 | 13.8211 | 499 | 3 | 3 | 0/0/0 | 0 |
| 09 | heuristic diode insertion disabled | 1.2576 | 0.1000 | 19827 | 142265 | 12.7389 | 21 | 0 | 30 | 0/0/0 | 0 |
| 10 | two antenna-repair iterations | 0.5414 | 0.0859 | 26037 | 157805 | 12.9898 | 22 | 2 | 2 | 0/0/0 | 0 |
| 11 | two antenna iterations with 40 percent margin | 0.4723 | 0.0880 | 26042 | 157818 | 12.9889 | 24 | 2 | 4 | 0/0/0 | 0 |
| 12 | one antenna-repair iteration | 0.4842 | 0.0869 | 26034 | 157798 | 12.9912 | 32 | 3 | 2 | 0/0/0 | 0 |
| 13 | corrected parallel-controller restart/load/commit behavior | 1.2028 | 0.0861 | 26290 | 159050 | 9.5198 | 58 | 1 | 1 | 0/0/0 | 0 |
| 14 | unregistered convergence subtract/absolute-value/compare datapath | -3.0904 | 0.1094 | 26897 | 161213 | 9.5304 | 123 | 5 | 2 | 0/0/0 | 0 |
| 15 | measured unregistered convergence path | -3.0904 | 0.1094 | 26897 | 161213 | 9.5304 | 123 | 5 | 2 | 0/0/0 | 0 |
| 16 | registered operands and bounds comparison with tolerance unregistered | 1.2140 | 0.1002 | 27236 | 164440 | 9.8825 | 80 | 2 | 2 | 0/0/0 | 0 |
| 17 | registered convergence tolerance | 0.7621 | 0.1072 | 27661 | 167623 | 10.2117 | 55 | 0 | 4 | 0/0/0 | 0 |
| 18 | full pipelined convergence candidate | 0.7621 | 0.1072 | 27661 | 167623 | 10.2117 | 55 | 0 | 4 | 0/0/0 | 0 |
| 19 | three antenna-repair iterations | 0.8403 | 0.1070 | 27662 | 167626 | 10.2086 | 50 | 0 | 6 | 0/0/0 | 0 |
| 20 | 30 percent slew-repair target | 0.6142 | 0.1049 | 27398 | 166893 | 10.2238 | 180 | 0 | 5 | 0/0/0 | 0 |

## Experiment #00

- Change: serial one-MAC reference baseline
- Revision: `372a29d` on `agent/add-openlane-signoff-config`; config `openlane/config.json`
- Original: reference pass; reported setup/hold WNS 0.4350/0.1015 ns, power 6.2910 mW
- Rerun: complete; setup/hold WNS 0.4350/0.1015 ns, power 6.2910 mW, physical verification pass
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #01

- Change: initial N-lane parallel architecture
- Revision: `e8d7349` on `parallel-core`; config `project::results/full_metrics/reconstructed_parallel_initial_config.json`
- Original: synthesis-only; continued; reported setup/hold WNS N/A/N/A ns, power N/A mW
- Rerun: complete; setup/hold WNS -0.7642/0.0939 ns, power 9.1465 mW, physical verification pass
- Major differences: none above requested thresholds
- Compatibility/warnings: medium historical mapping confidence; resume preserved archived synthesis because exact pre-commit RTL was not committed

## Experiment #02

- Change: initial parallel pre-PnR baseline with shared feed-index/reset distribution
- Revision: `e8d7349` on `parallel-core`; config `project::results/full_metrics/reconstructed_parallel_initial_config.json`
- Original: rejected for setup; reported setup/hold WNS -5.5409/0.0443 ns, power 4.4127 mW
- Rerun: complete; setup/hold WNS -0.7642/0.0939 ns, power 9.1465 mW, physical verification pass
- Major differences: power_mw +107.3%, setup_wns_ns +4.777 ns
- Compatibility/warnings: low historical mapping confidence; resume preserved archived synthesis because exact RTL was not committed

## Experiment #03

- Change: local per-lane feed-index distribution registers
- Revision: `e8d7349` on `parallel-core`; config `project::results/full_metrics/reconstructed_parallel_initial_config.json`
- Original: kept architecture; reported setup/hold WNS 2.3633/0.0226 ns, power 5.9111 mW
- Rerun: complete; setup/hold WNS 0.5093/0.1034 ns, power 13.0125 mW, physical verification fail
- Major differences: power_mw +120.1%, setup_wns_ns -1.854 ns
- Compatibility/warnings: resume preserved archived synthesis state

## Experiment #04

- Change: local synchronous reset distribution without retained feed-index change
- Revision: `e8d7349` on `parallel-core`; config `project::results/full_metrics/reconstructed_parallel_initial_config.json`
- Original: rejected in isolation; reported setup/hold WNS -3.3927/0.0407 ns, power 4.4228 mW
- Rerun: complete; setup/hold WNS 0.0739/0.0906 ns, power 8.5888 mW, physical verification fail
- Major differences: power_mw +94.2%, setup_wns_ns +3.467 ns
- Compatibility/warnings: low historical mapping confidence; resume preserved archived synthesis because exact RTL was not committed

## Experiment #05

- Change: first full N-lane parallel flow
- Revision: `e8d7349` on `parallel-core`; config `project::results/full_metrics/reconstructed_parallel_initial_config.json`
- Original: rejected electrical and antenna; reported setup/hold WNS 0.5093/0.1034 ns, power 13.0125 mW
- Rerun: complete; setup/hold WNS 0.5093/0.1034 ns, power 13.0125 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: reconstructed original 10-iteration config because config.json was later updated

## Experiment #06

- Change: post-global-routing design repair
- Revision: `e8d7349` on `parallel-core`; config `openlane/config_parallel_exp02.json`
- Original: rejected; antenna worsened; reported setup/hold WNS 0.5381/0.1031 ns, power 13.0003 mW
- Rerun: complete; setup/hold WNS 0.5381/0.1031 ns, power 13.0003 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #07

- Change: tighter electrical repair and increased antenna repair
- Revision: `e8d7349` on `parallel-core`; config `openlane/config_parallel_exp03.json`
- Original: rejected antenna and capacitance; reported setup/hold WNS 0.3319/0.0868 ns, power 12.9964 mW
- Rerun: complete; setup/hold WNS 0.3319/0.0868 ns, power 12.9964 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #08

- Change: lower heuristic antenna threshold and diode padding
- Revision: `e8d7349` on `parallel-core`; config `openlane/config_parallel_exp04.json`
- Original: rejected setup/electrical/antenna; reported setup/hold WNS -0.3928/0.0851 ns, power 13.8211 mW
- Rerun: complete; setup/hold WNS -0.3928/0.0851 ns, power 13.8211 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #09

- Change: heuristic diode insertion disabled
- Revision: `e8d7349` on `parallel-core`; config `openlane/config_parallel_exp05.json`
- Original: rejected severe antenna; reported setup/hold WNS 1.2576/0.1000 ns, power 12.7389 mW
- Rerun: complete; setup/hold WNS 1.2576/0.1000 ns, power 12.7389 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #10

- Change: two antenna-repair iterations
- Revision: `e8d7349` on `parallel-core`; config `openlane/config_parallel_exp06.json`
- Original: selected parallel candidate; reported setup/hold WNS 0.5414/0.0859 ns, power 12.9898 mW
- Rerun: complete; setup/hold WNS 0.5414/0.0859 ns, power 12.9898 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #11

- Change: two antenna iterations with 40 percent margin
- Revision: `e8d7349` on `parallel-core`; config `openlane/config_parallel_exp07.json`
- Original: rejected antenna worsened; reported setup/hold WNS 0.4723/0.0880 ns, power 12.9889 mW
- Rerun: complete; setup/hold WNS 0.4723/0.0880 ns, power 12.9889 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #12

- Change: one antenna-repair iteration
- Revision: `e8d7349` on `parallel-core`; config `openlane/config_parallel_exp08.json`
- Original: rejected capacitance and antenna ratio; reported setup/hold WNS 0.4842/0.0869 ns, power 12.9912 mW
- Rerun: complete; setup/hold WNS 0.4842/0.0869 ns, power 12.9912 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #13

- Change: corrected parallel-controller restart/load/commit behavior
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_parallel_exp06.json`
- Original: synthesis-only; kept RTL; reported setup/hold WNS N/A/N/A ns, power N/A mW
- Rerun: complete; setup/hold WNS 1.2028/0.0861 ns, power 9.5198 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #14

- Change: unregistered convergence subtract/absolute-value/compare datapath
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_converge_exp09.json`
- Original: synthesis-only; continued; reported setup/hold WNS N/A/N/A ns, power N/A mW
- Rerun: complete; setup/hold WNS -3.0904/0.1094 ns, power 9.5304 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: low historical mapping confidence; resume preserved archived synthesis because exact RTL was not committed

## Experiment #15

- Change: measured unregistered convergence path
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_converge_exp09.json`
- Original: rejected architectural setup failure; reported setup/hold WNS -9.1549/0.0227 ns, power 4.6906 mW
- Rerun: complete; setup/hold WNS -3.0904/0.1094 ns, power 9.5304 mW, physical verification fail
- Major differences: power_mw +103.2%, setup_wns_ns +6.065 ns
- Compatibility/warnings: medium historical mapping confidence; resume preserved archived synthesis because exact RTL was not committed

## Experiment #16

- Change: registered operands and bounds comparison with tolerance unregistered
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_converge_exp09.json`
- Original: rejected remaining setup failure; reported setup/hold WNS -0.2703/0.0227 ns, power 4.8109 mW
- Rerun: complete; setup/hold WNS 1.2140/0.1002 ns, power 9.8825 mW, physical verification fail
- Major differences: power_mw +105.4%, setup_wns_ns +1.484 ns
- Compatibility/warnings: medium historical mapping confidence; resume preserved archived synthesis because exact RTL was not committed

## Experiment #17

- Change: registered convergence tolerance
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_converge_exp09.json`
- Original: kept architecture; reported setup/hold WNS 1.8365/0.0227 ns, power 4.8426 mW
- Rerun: complete; setup/hold WNS 0.7621/0.1072 ns, power 10.2117 mW, physical verification fail
- Major differences: power_mw +110.9%, setup_wns_ns -1.074 ns
- Compatibility/warnings: resume preserved archived synthesis state

## Experiment #18

- Change: full pipelined convergence candidate
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_converge_exp09.json`
- Original: selected near-clean convergence candidate; reported setup/hold WNS 0.7621/0.1072 ns, power 10.2117 mW
- Rerun: complete; setup/hold WNS 0.7621/0.1072 ns, power 10.2117 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #19

- Change: three antenna-repair iterations
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_converge_exp10.json`
- Original: rejected antenna worsened; reported setup/hold WNS 0.8403/0.1070 ns, power 10.2086 mW
- Rerun: complete; setup/hold WNS 0.8403/0.1070 ns, power 10.2086 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none

## Experiment #20

- Change: 30 percent slew-repair target
- Revision: `546fdb9` on `parallel-convergence-optimization`; config `openlane/config_converge_exp11.json`
- Original: rejected slew and antenna worsened; reported setup/hold WNS 0.6142/0.1049 ns, power 10.2238 mW
- Rerun: complete; setup/hold WNS 0.6142/0.1049 ns, power 10.2238 mW, physical verification fail
- Major differences: none above requested thresholds
- Compatibility/warnings: none
