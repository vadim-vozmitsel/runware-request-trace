# Runware Demo: Two Sides, One Call

Supporting code for a short technical talk about the Runware API. The talk
argues that every call has two sides: what your code does, and what
happens once the task leaves your process. This repo proves the
infrastructure side live instead of asking anyone to take it on faith.

## What the production demo proves

1. Real concurrent image requests, run live, show how latency behaves
   under load: a narrow, reproducible, single-machine observation, not a
   platform-wide guarantee.
2. A synchronous image request, validated client side, returns a finished
   result, task UUID, and cost in one interaction.

It does not prove a specific GPU route, internal scheduler decision,
platform benchmark, or comparative performance advantage.

## Locked versions and models

- TypeScript: `@runware/sdk`, version pinned in `package.json`.
- Image, live on stage: `runware:100@1` (FLUX.1 Schnell).
- Image, measured only (not run live): `runware:101@1` (FLUX.1 Dev),
  used once to get a real `acceleratorOptions` delta. Schnell's four steps
  don't leave the cache room to do anything measurable; Dev's do. See
  `performance-load-testing/accelerator-probe.sh`.

Resolve the live schema again before recording: `./verify-live-contract.sh`.

## Setup

```bash
cp .env.example .env   # then edit .env and fill in your key
./check-deps.sh
./verify-live-contract.sh
```

Every script in this repo, including `performance-load-testing/`, loads
`RUNWARE_API_KEY` from `.env` automatically (checking its own directory,
then its parent). An already-exported `RUNWARE_API_KEY` always takes
precedence over `.env`. Never commit `.env`, paste the key into a script,
or say it on a recording.

```bash
npm install
npm run typecheck
```

## Production run

```bash
cd performance-load-testing
CONCURRENCY=1 ./concurrent-load-probe.sh    # baseline: one request, alone
CONCURRENCY=30 ./concurrent-load-probe.sh   # the cold open: thirty at once
cd ..
npm run typescript:run                      # the closing demo
```

`npm run typescript:run` executes `typescript-lifecycle.ts` directly. It is
the same code shown on screen during the talk, not a stand-in command.

## File map

- `typescript-lifecycle.ts`: the SDK call the talk is built around. Shown
  on screen and executed live.
- `verify-live-contract.sh`: read-only check confirming the pinned SDK
  version and the live request schema.
- `check-deps.sh`: confirms required tools and an available API key before
  anything else runs.
- [`performance-load-testing/`](performance-load-testing/README.md):
  the concurrent-load probe used as the cold open, the `acceleratorOptions`
  comparison behind the Slide 4 claim, plus supplementary measurement
  scripts and their methodology.

## Safety boundaries

- Aborting a client wait does not cancel server-side processing or
  billing.
- The SDK already handles qualifying transport retries. Do not treat blind
  resubmission as a generic error-recovery strategy.
- Treat `taskUUID` as application state for any work that has to survive
  past the original request.
- Measurements in this repo describe particular runs from one machine at a
  point in time. They are not platform-wide guarantees.
