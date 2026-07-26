# Runware API + Infra Layer Demo

Supporting code for a short technical talk about the Runware API and the underlying infrastructure. This demo contains the shell scripts used to evaluate Runware performance as well as a Typescript lifecycle file that executes a Runware task.

## What the production demo shows:

1. Real concurrent image requests, run live, show how latency behaves under load: a narrow, reproducible, single-machine observation that compares a baseline against a load of 30 concurrent requests.
2. A synchronous image request, validated client side, returns a finished result, task UUID, and cost in one interaction.

## Locked versions and models

- TypeScript: `@runware/sdk`, version pinned in `package.json`.
- Single Image Request: `runware:100@1` (FLUX.1 Schnell).
- Image, measured only: `runware:101@1` (FLUX.1 Dev), used to get a real `acceleratorOptions` delta. Schnell's 4 steps
  don't leave the cache room to do anything measurable where as Dev's 50 steps do. See `performance-load-testing/accelerator-probe.sh`.

Resolve the live schema by running: `./verify-live-contract.sh`.

## Setup

```bash
cp .env.example .env   # then edit .env and fill in your key
./check-deps.sh
./verify-live-contract.sh
```

Every script in this repo, including `performance-load-testing/`, loads
`RUNWARE_API_KEY` from `.env` automatically. An already-exported `RUNWARE_API_KEY` always takes
precedence over `.env`. Never commit your `.env` or paste the key directly into a script.

```bash
npm install
npm run typecheck
```

## Production run

```bash
cd performance-load-testing
CONCURRENCY=1 ./concurrent-load-probe.sh    # Baseline: 1 request
CONCURRENCY=30 ./concurrent-load-probe.sh   # Batch of 30 concurrent requests at once
cd ..
npm run typescript:run                      # Single request run
```

`npm run typescript:run` executes `typescript-lifecycle.ts` directly.

## File map

- `typescript-lifecycle.ts`: the SDK call used in the demo. Shown on screen and executed live.
- `verify-live-contract.sh`: read-only check confirming the pinned SDK version and the live request schema.
- `check-deps.sh`: confirms required tools and an available API key before anything else runs.
- [`performance-load-testing/`](performance-load-testing/README.md): the concurrent-load probe + the `acceleratorOptions` comparison, plus supplementary measurement scripts and their methodology.

## Safety boundaries

- Aborting a client wait does not cancel server-side processing or billing.
- The SDK already handles qualifying transport retries. Do not treat blind resubmission as a generic error-recovery strategy.
- Treat `taskUUID` as application state for any work that has to survive past the original request.
- Measurements in this repo describe particular runs from one machine at a point in time. They are not platform-wide guarantees.
