# Supporting Measurement Methodology

These measurements are retained as background evidence. The live cold-open
run on recording day is the evidence that matters on camera; this file
documents how to read and reproduce it.

## Curl timing fields are cumulative

`curl -w` reports each value from the beginning of the request. Derive phase
durations by subtraction:

| Cumulative field | Phase duration |
|---|---|
| `time_namelookup` | `time_namelookup` |
| `time_connect` | `time_connect - time_namelookup` |
| `time_appconnect` | `time_appconnect - time_connect` |
| `time_starttransfer` | `time_starttransfer - time_appconnect` |
| `time_total` | `time_total - time_starttransfer` |

The interval from TLS completion to first byte is
`time_starttransfer - time_appconnect`. It includes all time between the
completed connection and the first response byte. A client cannot divide that
interval into queueing, routing, inference, and response construction without
server-side telemetry.

## Why response download time is small

A synchronous image response contains JSON metadata and an `imageURL`, not the
image bytes themselves. The interval from first byte to total completion is
therefore normally small for this payload.

## Sequential and concurrent probes

`latency-probe.sh` sends one synchronous REST request at a time.
`concurrent-load-probe.sh` launches a bounded number of synchronous REST
requests together, then waits for all of them.

Concurrent measurements also include local network and client contention.
They can describe what happened in a specific run. They cannot prove the
platform's internal queue depth, hardware placement, or scheduler behavior.

## Historical dataset

The CSV files under `results/` were captured during development, before
recording. Preserve them as receipts. Any claim drawn from them must
identify its exact file, model, payload, concurrency, machine, date,
median, range, and failure count.

Do not blend historical measurements with a fresh recording-day run.

## Reproduction

```bash
cd ..
./check-deps.sh
./verify-live-contract.sh
cd performance-load-testing
CONCURRENCY=1 ./concurrent-load-probe.sh
CONCURRENCY=30 ./concurrent-load-probe.sh
```

These scripts make paid API calls. Run them deliberately.
