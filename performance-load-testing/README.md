# Performance and Load Testing

`concurrent-load-probe.sh` is the presentation's cold open, run live as a
baseline-then-load pair: one request alone, then thirty at once. The rest
of this directory is supplementary research. All scripts here make paid
API calls when run.

- `latency-probe.sh`: sequential raw REST measurements.
- `concurrent-load-probe.sh`: bounded concurrent raw REST measurements.
  The presentation's cold open.
- `accelerator-probe.sh`: compares an image request with and without
  `acceleratorOptions` (TeaCache), N runs per condition, reports medians.
  Backs the Slide 4 claim: measured on FLUX.1 Dev at 50 steps, not on the
  demo's own FLUX.1 Schnell, which showed no delta at this precision.
- `mixed-batch-demo.sh`: verifies that a request array can contain distinct
  supported task types. Not part of the live demo.
- `results/`: historical measurements from prior runs. Reference only; the
  live talk reads numbers off the terminal, not these files, on camera.
- `METHODOLOGY.md`: definitions, boundaries, and reproduction steps.

`RUNWARE_API_KEY` loads automatically from `../.env` (see
`../.env.example`) if it isn't already exported.

Run these from this directory after verifying the parent demo's dependencies
and live contract:

```bash
cd performance-load-testing
CONCURRENCY=1 ./concurrent-load-probe.sh    # baseline
CONCURRENCY=30 ./concurrent-load-probe.sh   # the cold open

# the Slide 4 accelerator claim: no delta on the demo model itself
RUNS=20 ./accelerator-probe.sh

# the same comparison on a model with enough steps for it to matter
MODEL=runware:101@1 WIDTH=1024 HEIGHT=1024 STEPS=50 RUNS=15 ./accelerator-probe.sh
```

These measurements are specific to a run, date, machine, payload, and model.
They do not establish platform-wide latency, capacity, routing, scheduler, or
hardware claims.
