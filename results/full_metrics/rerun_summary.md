# Full Metrics Rerun Summary

- Full flows completed: 21/21 (00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20)
- Failed flows: 0
- Uncertain mappings: 01 (medium), 02 (low), 04 (low), 14 (low), 15 (medium), 16 (medium)
- Metric completeness: all requested full-flow implementation metrics were generated for all 21 experiments.
- Power comparability: yes; every rerun used OpenROAD post-route vectorless power at max_ff_n40C_1v95 with identical default activity assumptions.
- Reruns with differences above requested comparison thresholds: 02, 03, 04, 15, 16, 17.
- Thread count: 8 for every OpenLane run.
- Clock period: 17 ns for every experiment.

## Regeneration

```bash
python3 scripts/run_full_metrics_campaign.py --experiments 0-20
python3 scripts/aggregate_full_metrics.py
```
